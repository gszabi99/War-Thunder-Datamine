const MATCHING_REQUEST_LIFETIME = 30000
local lastRequestTimeMsec = 0
local recentBR = 0
local recentGameMode = null
local isUpdating = false
local isNeedRewrite = false
local userData = null
local cache = {}

local calcSquadBattleRating = function(brData)
{
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

local calcBattleRating = function (brData)
{
  if (::g_squad_manager.isInSquad())
    return calcSquadBattleRating(brData)

  local name = ::my_user_name
  local myData = brData?[name]

  return myData?[0] == null ? 0 : ::calc_battle_rating_from_rank(myData[0].mrank)
}

local getCrafts = function (data, country = null)
{
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
       rank = getUnitRank(craft)
     })
  }

  return crafts
}

local isBRKnown = function(recentUserData)
{
  local id = recentUserData?.gameModeId
  if(id in cache && ::u.isEqual(recentUserData.players, cache[id].players))
    return true

  return false
}

local setBattleRating = function(recentUserData, brData)
{
  if (brData)
  {
    local br = calcBattleRating(brData)
    recentBR = isNeedRewrite ? br : recentBR
    cache[recentUserData.gameModeId] <- {br = br, players = recentUserData.players}
  }
  else
    recentBR = cache[recentUserData.gameModeId].br

  if (isNeedRewrite)
    ::broadcastEvent("BattleRatingChanged")
}

local resetBattleRating = function()
{
  recentBR = 0
  ::broadcastEvent("BattleRatingChanged")
}

local getBestCountryData = function(event)
{
  local teams = ::events.getAvailableTeams(event)
  local membersTeams = ::events.getMembersTeamsData(event, null, teams)
  if (!membersTeams)
    return null

  return ::events.getMembersInfo(teams, membersTeams.teamsData).data
}

local getUserData = function()
{
  local gameModeId = recentGameMode?.source?.gameModeId
  if (gameModeId == null)
    return null

  local players = []

  if (::g_squad_manager.isSquadLeader())
  {
    local countryData = getBestCountryData(::events.getEvent(recentGameMode?.id))
    foreach(member in ::g_squad_manager.getMembers())
    {
      if (!member.online || member.country == "")
        continue

      local country = countryData?[member.uid]?.country
      local crafts = getCrafts(member, country)
      players.append({
        name = member.name
        country = country ?? member.country
        slot = crafts.findindex(function(p) { return p.name == member.selAirs[country ?? member.country]}) ?? -1
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
      slot = crafts.findindex(function(p) { return p.name == data.selAirs[data.country]}) ?? -1
      crafts = crafts
    })
  }

  return gameModeId == "" || !players.len() ? null : {
    gameModeId = gameModeId
    players = players
  }
}

local requestBattleRating = function (cb, recentUserData, onError=null)
{
  isUpdating = true
  isNeedRewrite = false
  lastRequestTimeMsec  = ::dagor.getCurTime()

  ::request_matching("match.calc_ranks", cb, onError, recentUserData, {
    showError = false
  })
}

local updateBattleRating
updateBattleRating = function (gameMode = null, brData = null)
{
  recentGameMode = gameMode ?? ::game_mode_manager.getCurrentGameMode()
  local recentUserData = getUserData()
  if(!recentGameMode || !recentUserData)
  {
    isNeedRewrite = true
    resetBattleRating()
    return
  }

  if (isUpdating && !(::dagor.getCurTime() - lastRequestTimeMsec >= MATCHING_REQUEST_LIFETIME))
  {
    if(isBRKnown(recentUserData))
    {
      isNeedRewrite = true
      setBattleRating(recentUserData, null)
    }

    return
  }

  if(::u.isEqual(userData, recentUserData) && brData)
  {
    setBattleRating(recentUserData, brData)
    return
  }

  if (isBRKnown(recentUserData))
  {
    setBattleRating(recentUserData, null)
    return
  }

  local callback = function (resp){
    // isNeedRewrite becomes to false when request sent and will be true again as response have been received
    // except the cases when BR can be found without request.
    // If it's false that mean current BR does not changed but new data should be added to cache
    isNeedRewrite = !isNeedRewrite
    isUpdating = false
    updateBattleRating(recentGameMode, resp)
  }

  userData = clone recentUserData
  requestBattleRating(callback, userData)
}

return {
  updateBattleRating = updateBattleRating
  getCrafts = getCrafts
  getRecentGameModeId = function (){return recentGameMode?.id ?? ""}
  getBR = function (){return recentBR}
}
