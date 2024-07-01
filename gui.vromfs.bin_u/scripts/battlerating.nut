from "%scripts/dagui_library.nut" import *

let u = require("%sqStdLibs/helpers/u.nut")
let { request_matching } = require("%scripts/matching/api.nut")
let { broadcastEvent, addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getMyStateData } = require("%scripts/user/userUtils.nut")
let { isNeedFirstCountryChoice } = require("%scripts/firstChoice/firstChoice.nut")
let { get_time_msec } = require("dagor.time")
let { isInFlight } = require("gameplayBinding")
let { userName } = require("%scripts/user/profileStates.nut")
let { calcBattleRatingFromRank } = require("%appGlobals/ranks_common_shared.nut")
let { getGlobalModule } = require("%scripts/global_modules.nut")
let g_squad_manager = getGlobalModule("g_squad_manager")
let { getCurrentGameMode, getCurrentGameModeEdiff } = require("%scripts/gameModes/gameModeManagerState.nut")

const MATCHING_REQUEST_LIFETIME = 30000
local lastRequestTimeMsec = 0
local isUpdating = false
local userData = null

let brInfoByGamemodeId = mkWatched(persist, "brInfoByGamemodeId", {})
let recentBrGameModeId = mkWatched(persist, "recentBrGameModeId", "")
let recentBrSourceGameModeId = mkWatched(persist, "recentBrSourceGameModeId", null)
let recentBR = Computed(@() brInfoByGamemodeId.value?[recentBrSourceGameModeId.value].br ?? 0)
let recentBRData = Computed(@() brInfoByGamemodeId.value?[recentBrSourceGameModeId.value].brData)

recentBR.subscribe(@(_) broadcastEvent("BattleRatingChanged"))

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

let getRecentSquadMrank = @() calcSquadMrank(recentBRData.value)

function calcSquadBattleRating(brData) {
  let mrank = calcSquadMrank(brData)
  // mrank < 0  means empty received data and no BR string needed in game mode header
  return mrank < 0 ? 0 : calcBattleRatingFromRank(mrank)
}

function getBRDataByMrankDiff(diff = 3) {
  let squadMrank = calcSquadMrank(recentBRData.value)
  if (squadMrank < 0)
    return []

  return recentBRData.value
    .filter(@(v, _n) (v?[0].mrank ?? -1) >= 0 && (squadMrank - v[0].mrank >= diff))
    .map(@(v) calcBattleRatingFromRank(v[0].mrank))
}

function calcBattleRating(brData) {
  if (g_squad_manager.isInSquad())
    return calcSquadBattleRating(brData)

  let name = userName.value
  let myData = brData?[name]

  return myData?[0] == null ? 0 : calcBattleRatingFromRank(myData[0].mrank)
}

function getCrafts(data, country = null) {
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
       mrank = craft.getEconomicRank(getCurrentGameModeEdiff())
       rank = craft?.rank ?? -1
     })
  }

  return crafts
}

function isBRKnown(recentUserData) {
  let id = recentUserData?.gameModeId
  return id in brInfoByGamemodeId.value
    && u.isEqual(recentUserData.players, brInfoByGamemodeId.value[id].players)
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
  let teams = ::events.getAvailableTeams(event)
  let membersTeams = ::events.getMembersTeamsData(event, null, teams)
  if (!membersTeams)
    return null

  return ::events.getMembersInfo(membersTeams.teamsData)
}

function getUserData() {
  let gameModeId = recentBrSourceGameModeId.value
  if (gameModeId == null)
    return null

  let players = []

  if (g_squad_manager.isSquadLeader()) {
    let countryData = getBestCountryData(::events.getEvent(recentBrGameModeId.value))
    foreach (member in g_squad_manager.getMembers()) {
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
updateBattleRating = function(gameMode = null, brData = null) { //!!FIX ME: why outside update request and internal callback the same function?
  //it make harder to read it, and can have a lot of errors.
  gameMode = gameMode ?? getCurrentGameMode()
  recentBrGameModeId(gameMode?.id ?? "")
  recentBrSourceGameModeId(gameMode?.source.gameModeId)
  let recentUserData = getUserData()
  if (recentBrSourceGameModeId.value == null || !recentUserData) {
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

  if (isBRKnown(recentUserData)) //!!FIX ME: this cache does not work, it always request again when switch between 2 units by single mouse click
    return

  let callback = function(resp) {
    isUpdating = false //FIX ME: it a bad idea to change this flag in very different places. Also it not switch off on error
    updateBattleRating(gameMode, resp)
  }

  userData = clone recentUserData
  requestBattleRating(callback, userData)
}

local isRequestDelayed = false
function updateBattleRatingDelayed() {
  if (isRequestDelayed || isInFlight() || isNeedFirstCountryChoice()) //do not recalc while in the battle
    return
  isRequestDelayed = true
  handlersManager.doDelayed(function() {
    isRequestDelayed = false
    updateBattleRating()
  })
}

function updateLeaderRatingDelayed(_p) {
  if (g_squad_manager.isSquadLeader())
    updateBattleRatingDelayed()
}

addListenersWithoutEnv({
  ProfileUpdated             = @(_p) updateBattleRatingDelayed()
  CrewChanged                = @(_p) updateBattleRatingDelayed()
  CurrentGameModeIdChanged   = @(_p) updateBattleRatingDelayed()
  EventsDataUpdated          = @(_p) updateBattleRatingDelayed()
  LoadingStateChange         = @(_p) updateBattleRatingDelayed()

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
