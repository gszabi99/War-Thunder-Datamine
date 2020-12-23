local { addListenersWithoutEnv } = require("sqStdLibs/helpers/subscriptions.nut")

const MATCHING_REQUEST_LIFETIME = 30000
local lastRequestTimeMsec = 0
local isUpdating = false
local userData = null

local brInfoByGamemodeId = persist("brInfoByGamemodeId", @() ::Watched({}))
local recentBrGameModeId = persist("recentBrGameModeId", @() ::Watched(""))
local recentBrSourceGameModeId = persist("recentBrSourceGameModeId", @() ::Watched(null))
local recentBR = ::Computed(@() brInfoByGamemodeId.value?[recentBrSourceGameModeId.value].br ?? 0)

recentBR.subscribe(@(_) ::broadcastEvent("BattleRatingChanged"))

local function calcSquadBattleRating(brData) {
  if (!brData)
    return 0

  local maxBR = -1
  foreach (name, idx in brData)
  {
    if (name != "error" && brData[name].len() > 0)
    {
      local val = brData[name][0].mrank
      maxBR = ::max(maxBR, val)
    }
  }
  // maxBR < 0  means empty received data and no BR string needed in game mode header
  return maxBR < 0 ? 0 : ::calc_battle_rating_from_rank(maxBR)
}

local function calcBattleRating(brData) {
  if (::g_squad_manager.isInSquad())
    return calcSquadBattleRating(brData)

  local name = ::my_user_name
  local myData = brData?[name]

  return myData?[0] == null ? 0 : ::calc_battle_rating_from_rank(myData[0].mrank)
}

local function getCrafts(data, country = null) {
  local crafts = []
  local craftData = data?.crewAirs?[country ?? data?.country ?? ""]
  if (craftData == null)
    return crafts

  local brokenAirs = data?.brokenAirs ?? []
  foreach (name in craftData)
  {
     local craft = ::getAircraftByName(name)
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

local function isBRKnown(recentUserData) {
  local id = recentUserData?.gameModeId
  return id in brInfoByGamemodeId.value
    && ::u.isEqual(recentUserData.players, brInfoByGamemodeId.value[id].players)
}

local function setBattleRating(recentUserData, brData) {
  if (recentUserData == null)
    return

  local { gameModeId, players } = recentUserData
  if (brData) {
    local br = calcBattleRating(brData)
    brInfoByGamemodeId[gameModeId] <- { br, players }
  }
  else if (gameModeId in brInfoByGamemodeId.value)
    brInfoByGamemodeId(@(v) delete v[gameModeId])
}

local function getBestCountryData(event)
{
  if (!event)
    return null
  local teams = ::events.getAvailableTeams(event)
  local membersTeams = ::events.getMembersTeamsData(event, null, teams)
  if (!membersTeams)
    return null

  return ::events.getMembersInfo(teams, membersTeams.teamsData).data
}

local function getUserData() {
  local gameModeId = recentBrSourceGameModeId.value
  if (gameModeId == null)
    return null

  local players = []

  if (::g_squad_manager.isSquadLeader())
  {
    local countryData = getBestCountryData(::events.getEvent(recentBrGameModeId.value))
    foreach(member in ::g_squad_manager.getMembers())
    {
      if (!member.online || member.country == "")
        continue

      local country = countryData?[member.uid]?.country
      local crafts = getCrafts(member, country)
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
    local data = ::g_user_utils.getMyStateData()
    if(data.country == "")
      return null

    local crafts = getCrafts(data)
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

local function requestBattleRating(cb, recentUserData, onError=null) {
  isUpdating = true
  lastRequestTimeMsec  = ::dagor.getCurTime()

  ::request_matching("match.calc_ranks", cb, onError, recentUserData, {
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
  local recentUserData = getUserData()
  if (recentBrSourceGameModeId.value == null || !recentUserData) {
    brInfoByGamemodeId(@(v) v.clear())
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

  local callback = function(resp) {
    isUpdating = false //FIX ME: it a bad idea to change this flag in very different places. Also it not switch off on error
    updateBattleRating(gameMode, resp)
  }

  userData = clone recentUserData
  requestBattleRating(callback, userData)
}

local isRequestDelayed = false
local function updateBattleRatingDelayed() {
  if (isRequestDelayed || ::is_in_flight()) //do not recalc while in the battle
    return
  isRequestDelayed = true
  ::handlersManager.doDelayed(function() {
    isRequestDelayed = false
    updateBattleRating()
  })
}

local function updateLeaderRatingDelayed(p) {
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
}
