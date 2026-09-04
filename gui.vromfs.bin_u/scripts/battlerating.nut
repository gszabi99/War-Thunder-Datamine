import "%sqStdLibs/helpers/u.nut" as u
from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv
from "%appGlobals/ranks_common_shared.nut" import calcBattleRatingFromRank
from "dagor.time" import get_time_msec
from "gameplayBinding" import isInFlight
from "%scripts/dagui_library.nut" import *

let { request_matching } = require("%scripts/matching/api.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getMyStateData } = require("%scripts/user/userUtils.nut")
let { reqFirstUnitTypeChoice } = require("%scripts/firstChoice/firstChoice.nut")
let { userName } = require("%scripts/user/profileStates.nut")
let { getMembers, isInSquad, isSquadLeader } = require("%scripts/squads/squadState.nut")
let { getEvent } = require("%scripts/events/eventsState.nut")
let { getAvailableTeams, getMembersInfo, getMembersTeamsData } = require("%scripts/events/eventUnitsAvail.nut")
let { brInfoByGamemodeId, recentBrGameModeId, recentBrSourceGameModeId, recentBR, recentBRData } = require("%scripts/battleRatingState.nut")
let { getCurrentGameMode, getCurrentGameModeEdiff } = require("%scripts/gameModes/gameModeManagerState.nut")
let { hasOptionsInitialized } = require("%scripts/options/initOptionsState.nut")

const MATCHING_REQUEST_LIFETIME = 30000
local lastRequestTimeMsec = 0
local isUpdating = false
local userData = null

function calcSquadMrank(brData) {
  if (!brData)
    return -1

  local maxBR = -1
  foreach (name, _idx in brData) {
    if (name != "error" && brData[name].len() > 0) {
      let val = brData[name][0].mrank
      maxBR = max(maxBR, val)
    }
  }
  return maxBR
}

let getRecentSquadMrank = @() calcSquadMrank(recentBRData.get())

function calcSquadBattleRating(brData) {
  let mrank = calcSquadMrank(brData)
  
  return mrank < 0 ? 0 : calcBattleRatingFromRank(mrank)
}

function getBRDataByMrankDiff(diff = 3) {
  let squadMrank = calcSquadMrank(recentBRData.get())
  if (squadMrank < 0)
    return []

  return recentBRData.get()
    .filter(@(v, _n) (v?[0].mrank ?? -1) >= 0 && (squadMrank - v[0].mrank >= diff))
    .map(@(v) calcBattleRatingFromRank(v[0].mrank))
}

function calcBattleRating(brData) {
  if (isInSquad())
    return calcSquadBattleRating(brData)

  let name = userName.get()
  let myData = brData?[name]

  return myData?[0] == null ? 0 : calcBattleRatingFromRank(myData[0].mrank)
}

function getCrafts(data, country = null, ediff = null) {
  let crafts = []
  let craftData = data?.crewAirs?[country ?? data?.country ?? ""]
  if (craftData == null)
    return crafts

  let brokenAirs = data?.brokenAirs ?? []
  foreach (name in craftData) {
    let craft = getAircraftByName(name)
    if (craft == null || isInArray(name, brokenAirs))
      continue

    crafts.append({
      name = name
      craftType = craft.expClass.expClassName
      unitTypeCode = craft.expClass.unitTypeCode
      mrank = craft.getEconomicRank(ediff ?? getCurrentGameModeEdiff())
      rank = craft?.rank ?? -1
    })
  }

  return crafts
}

function isBRKnown(recentUserData) {
  let id = recentUserData?.gameModeId
  return id in brInfoByGamemodeId.get()
    && u.isEqual(recentUserData.players, brInfoByGamemodeId.get()[id].players)
}

function setBattleRating(recentUserData, brData) {
  if (recentUserData == null)
    return

  let { gameModeId, players } = recentUserData
  if (brData) {
    let br = calcBattleRating(brData)
    brInfoByGamemodeId.mutate(@(v) v[gameModeId] <- { br, players, brData = clone brData })
  }
  else
    brInfoByGamemodeId.mutate(@(v) v?.$rawdelete(gameModeId))
}

function getBestCountryData(event) {
  if (!event)
    return null
  let teams = getAvailableTeams(event)
  let membersTeams = getMembersTeamsData(event, null, teams)
  if (!membersTeams)
    return null

  return getMembersInfo(membersTeams)
}

function getUserData() {
  let gameModeId = recentBrSourceGameModeId.get()
  if (gameModeId == null)
    return null

  let players = []

  if (isSquadLeader()) {
    let countryData = getBestCountryData(getEvent(recentBrGameModeId.get()))
    foreach (member in getMembers()) {
      if (!member.online || member.country == "")
        continue

      let country = countryData?[member.uid]?.country
      let crafts = getCrafts(member, country)
      players.append({
        name = member.name
        country = country ?? member.country
        slot = crafts.findindex(function(p) { return p.name == member.selAirs?[country ?? member.country] }) ?? -1
        crafts = crafts
      })
    }
  }
  else {
    let data = getMyStateData()
    if (data.country == "")
      return null

    let crafts = getCrafts(data)
    players.append({
      name = data.name
      country = data.country
      slot = crafts.findindex(function(p) { return p.name == data.selAirs?[data.country] }) ?? -1
      crafts = crafts
    })
  }

  return gameModeId == "" || !players.len() ? null : {
    gameModeId = gameModeId
    players = players
  }
}

function requestBattleRating(cb, recentUserData) {
  isUpdating = true
  lastRequestTimeMsec  = get_time_msec()
  let errorCB = @(...) isUpdating = false
  request_matching("wtmm_static.calc_ranks", cb, errorCB, recentUserData, {
    showError = false
  })
}

local updateBattleRating
updateBattleRating = function(gameMode = null, brData = null) { 
  
  gameMode = gameMode ?? getCurrentGameMode()
  recentBrGameModeId.set(gameMode?.id ?? "")
  recentBrSourceGameModeId.set(gameMode?.source.gameModeId)
  let recentUserData = getUserData()
  if (recentBrSourceGameModeId.get() == null || !recentUserData) {
    brInfoByGamemodeId.mutate(@(v) v.clear())
    return
  }

  if (isUpdating && !(get_time_msec() - lastRequestTimeMsec >= MATCHING_REQUEST_LIFETIME)) {
    if (isBRKnown(recentUserData))
      setBattleRating(recentUserData, null)
    return
  }

  if (u.isEqual(userData, recentUserData) && brData) {
    setBattleRating(recentUserData, brData)
    return
  }

  if (isBRKnown(recentUserData)) 
    return

  let callback = function(resp) {
    isUpdating = false 
    updateBattleRating(gameMode, resp)
  }

  userData = clone recentUserData
  requestBattleRating(callback, userData)
}

local isRequestDelayed = false
function updateBattleRatingDelayed() {
  if (isRequestDelayed || isInFlight() || reqFirstUnitTypeChoice() || !hasOptionsInitialized()) 
    return
  isRequestDelayed = true
  handlersManager.doDelayed(function() {
    isRequestDelayed = false
    updateBattleRating()
  })
}

function updateLeaderRatingDelayed(_p) {
  if (isSquadLeader())
    updateBattleRatingDelayed()
}

addListenersWithoutEnv({
  ProfileUpdated             = @(_p) updateBattleRatingDelayed()
  CrewChanged                = @(_p) updateBattleRatingDelayed()
  CurrentGameModeIdChanged   = @(_p) updateBattleRatingDelayed()
  EventsDataUpdated          = @(_p) updateBattleRatingDelayed()
  LoadingStateChange         = @(_p) updateBattleRatingDelayed()
  InitConfigs                = @(_p) updateBattleRatingDelayed()

  SquadStatusChanged         = updateLeaderRatingDelayed
  SquadOnlineChanged         = updateLeaderRatingDelayed
  SquadMemberVehiclesChanged = updateLeaderRatingDelayed
})

return {
  getCrafts
  recentBrGameModeId
  recentBR
  getBRDataByMrankDiff
  getRecentSquadMrank
}
