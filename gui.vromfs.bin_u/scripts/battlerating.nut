let { addListenersWithoutEnv } = require("sqStdLibs/helpers/subscriptions.nut")

const MATCHING_REQUEST_LIFETIME = 30000
local lastRequestTimeMsec = 0
local isUpdating = false
local userData = null

let brInfoByGamemodeId = persist("brInfoByGamemodeId", @() ::Watched({}))
let recentBrGameModeId = persist("recentBrGameModeId", @() ::Watched(""))
let recentBrSourceGameModeId = persist("recentBrSourceGameModeId", @() ::Watched(null))
let recentBR = ::Computed(@() brInfoByGamemodeId.value?[recentBrSourceGameModeId.value].br ?? 0)
let recentBRData = ::Computed(@() brInfoByGamemodeId.value?[recentBrSourceGameModeId.value].brData)

recentBR.subscribe(@(_) ::broadcastEvent("BattleRatingChanged"))

let function calcSquadMrank(brData) {
  if (!brData)
    return -1

  local maxBR = -1
  foreach (name, idx in brData)
  {
    if (name != "error" && brData[name].len() > 0)
    {
      let val = brData[name][0].mrank
      maxBR = ::max(maxBR, val)
    }
  }
  return maxBR
}

let function calcSquadBattleRating(brData) {
  let mrank = calcSquadMrank(brData)
  // mrank < 0  means empty received data and no BR string needed in game mode header
  return mrank < 0 ? 0 : ::calc_battle_rating_from_rank(mrank)
}

let function getBRDataByMrankDiff(diff = 3) {
  let squadMrank = calcSquadMrank(recentBRData.value)
  if (squadMrank < 0)
    return []

  return recentBRData.value
    .filter(@(v, n) (v?[0].mrank ?? -1) >= 0 && (squadMrank - v[0].mrank >= diff))
    .map(@(v) ::calc_battle_rating_from_rank(v[0].mrank))
}

let function calcBattleRating(brData) {
  if (::g_squad_manager.isInSquad())
    return calcSquadBattleRating(brData)

  let name = ::my_user_name
  let myData = brData?[name]

  return myData?[0] == null ? 0 : ::calc_battle_rating_from_rank(myData[0].mrank)
}

let function getCrafts(data, country = null) {
  let crafts = []
  let craftData = data?.crewAirs?[country ?? data?.country ?? ""]
  if (craftData == null)
    return crafts

  let brokenAirs = data?.brokenAirs ?? []
  foreach (name in craftData)
  {
     let craft = ::getAircraftByName(name)
     if (craft == null || ::isInArray(name, brokenAirs))
       continue

     crafts.append({
       name = name
       type = craft.expClass.expClassName
       mrank = craft.getEconomicRank(::get_current_ediff())
       rank = craft?.rank ?? -1
     })
  }

  return crafts
}

let function isBRKnown(recentUserData) {
  let id = recentUserData?.gameModeId
  return id in brInfoByGamemodeId.value
    && ::u.isEqual(recentUserData.players, brInfoByGamemodeId.value[id].players)
}

let function setBattleRating(recentUserData, brData) {
  if (recentUserData == null)
    return

  let { gameModeId, players } = recentUserData
  if (brData) {
    let br = calcBattleRating(brData)
    brInfoByGamemodeId.mutate(@(v) v[gameModeId] <- { br, players, brData = clone brData })
  }
  else if (gameModeId in brInfoByGamemodeId.value)
    brInfoByGamemodeId.mutate(@(v) delete v[gameModeId])
}

let function getBestCountryData(event)
{
  if (!event)
    return null
  let teams = ::events.getAvailableTeams(event)
  let membersTeams = ::events.getMembersTeamsData(event, null, teams)
  if (!membersTeams)
    return null

  return ::events.getMembersInfo(teams, membersTeams.teamsData).data
}

let function getUserData() {
  let gameModeId = recentBrSourceGameModeId.value
  if (gameModeId == null)
    return null

  let players = []

  if (::g_squad_manager.isSquadLeader())
  {
    let countryData = getBestCountryData(::events.getEvent(recentBrGameModeId.value))
    foreach(member in ::g_squad_manager.getMembers())
    {
      if (!member.online || member.country == "")
        continue

      let country = countryData?[member.uid]?.country
      let crafts = getCrafts(member, country)
      players.append({
        name = member.name
        country = country ?? member.country
        slot = crafts.findindex(function(p) { return p.name == member.selAirs?[country ?? member.country]}) ?? -1
        crafts = crafts
      })
    }
  }
  else
  {
    let data = ::g_user_utils.getMyStateData()
    if(data.country == "")
      return null

    let crafts = getCrafts(data)
    players.append({
      name = data.name
      country = data.country
      slot = crafts.findindex(function(p) { return p.name == data.selAirs?[data.country]}) ?? -1
      crafts = crafts
    })
  }

  return gameModeId == "" || !players.len() ? null : {
    gameModeId = gameModeId
    players = players
  }
}

let function requestBattleRating(cb, recentUserData) {
  isUpdating = true
  lastRequestTimeMsec  = ::dagor.getCurTime()
  let errorCB = @(...) isUpdating = false
  ::request_matching("wtmm_static.calc_ranks", cb, errorCB, recentUserData, {
    showError = false
  })
}

local updateBattleRating
updateBattleRating = function(gameMode = null, brData = null) //!!FIX ME: why outside update request and internal callback the same function?
  //it make harder to read it, and can have a lot of errors.
{
  gameMode = gameMode ?? ::game_mode_manager.getCurrentGameMode()
  recentBrGameModeId(gameMode?.id ?? "")
  recentBrSourceGameModeId(gameMode?.source.gameModeId)
  let recentUserData = getUserData()
  if (recentBrSourceGameModeId.value == null || !recentUserData) {
    brInfoByGamemodeId.mutate(@(v) v.clear())
    return
  }

  if (isUpdating && !(::dagor.getCurTime() - lastRequestTimeMsec >= MATCHING_REQUEST_LIFETIME))
  {
    if(isBRKnown(recentUserData))
      setBattleRating(recentUserData, null)
    return
  }

  if(::u.isEqual(userData, recentUserData) && brData)
  {
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
let function updateBattleRatingDelayed() {
  if (isRequestDelayed || ::is_in_flight()) //do not recalc while in the battle
    return
  isRequestDelayed = true
  ::handlersManager.doDelayed(function() {
    isRequestDelayed = false
    updateBattleRating()
  })
}

let function updateLeaderRatingDelayed(p) {
  if (::g_squad_manager.isSquadLeader())
    updateBattleRatingDelayed()
}

addListenersWithoutEnv({
  ProfileUpdated             = @(p) updateBattleRatingDelayed()
  CrewChanged                = @(p) updateBattleRatingDelayed()
  CurrentGameModeIdChanged   = @(p) updateBattleRatingDelayed()
  EventsDataUpdated          = @(p) updateBattleRatingDelayed()
  LoadingStateChange         = @(p) updateBattleRatingDelayed()

  SquadStatusChanged         = updateLeaderRatingDelayed
  SquadOnlineChanged         = updateLeaderRatingDelayed
  SquadMemberVehiclesChanged = updateLeaderRatingDelayed
})

return {
  getCrafts
  recentBrGameModeId
  recentBR
  getBRDataByMrankDiff
}
