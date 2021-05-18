local mapPreferences = ::require_native("mapPreferences")
local unitTypes = require("scripts/unit/unitTypesList.nut")
local { addListenersWithoutEnv } = require("sqStdLibs/helpers/subscriptions.nut")

local mapsListByEvent = {}

local sortIdxByMissionType = {
  ["Dom"]   = 0,
  ["Bttl"]  = 1,
  ["other"] = 2
}

local function getPrefTypes()
{
  return {
    banned = {
      id = "ban"
      sType  = mapPreferences.BAN
      msg_id = "maxBannedCount"
      tooltip_remove_id = "removeBan"
    }
    disliked = {
      id = "dislike"
      sType  = mapPreferences.DISLIKE
      msg_id = "maxDislikedCount"
      tooltip_remove_id = "removeDislike"
    }
    liked = {
      id = "like"
      sType  = mapPreferences.LIKE
      msg_id = "maxLikedCount"
      tooltip_remove_id = "removeLike"
    }
  }
}

local function hasPreferences(curEvent)
{
  return (curEvent?.missionsBanMode ?? "none") != "none"
}

local function sortByLevel(list)
{
  list.sort(@(a,b) a.image <=> b.image)
  foreach(idx, map in list)
    map.mapId = idx
  return list
}

local function getCurBattleTypeName(curEvent)
{
  return !hasPreferences(curEvent)
    ? "" : (curEvent?.statistic_group && curEvent?.difficulty)
      ? curEvent.statistic_group + "_" + curEvent.difficulty : curEvent.name
}

local function getProfileBanData(curEvent)
{
  local curBattleTypeName = getCurBattleTypeName(curEvent)
  return {
    disliked = mapPreferences.get(curBattleTypeName, mapPreferences.DISLIKE),
    banned = mapPreferences.get(curBattleTypeName, mapPreferences.BAN),
    liked = mapPreferences.get(curBattleTypeName, mapPreferences.LIKE),
  }
}

local function getMissionLoc(missionId, config, isLevelBanMode, locNameKey = "locName")
{
  local missionLocName = ::loc("missions/" + missionId)
  local locNameValue = config?[locNameKey]
  if (locNameValue && locNameValue.len())
    missionLocName = isLevelBanMode ? ::loc(::split(locNameValue, "; ")?[1] ?? "") :
                                    ::get_locId_name(config, locNameKey)

  return isLevelBanMode
    ? ::g_string.implode([missionLocName,
      ::loc("ui/parentheses/space", { text = ::loc("maps/preferences/all_missions") })], " ")
    : missionLocName
}

local function getMapState(map)
{
  return map.liked ? "liked" : map.banned ? "banned" : map.disliked ? "disliked" : ""
}

local function getInactiveMaps(curEvent, mapsList)
{
  local res = {}
  local banData = getProfileBanData(curEvent)
  foreach(name, list in banData)
  {
    res[name] <- []
      foreach(map in list)
        if(!::u.search(mapsList, @(inst) inst.map == map))
          res[name].append(map)
  }

  return res
}

local function getMissionParams(name, missionInfo)
{
  local mType = name.split("_").top().split("Conq").top()
  return {
    id = name,
    title = getMissionLoc(name, missionInfo, false),
    type = mType,
    sortIdx = sortIdxByMissionType?[mType] ?? sortIdxByMissionType.other
  }
}

local function getMapsListImpl(curEvent)
{
  if(!hasPreferences(curEvent))
    return []

  local isLevelBanMode = curEvent.missionsBanMode == "level"
  local banData = getProfileBanData(curEvent)
  local banList = banData.banned
  local dislikeList = banData.disliked
  local likeList = banData.liked
  local list = []
  local hasTankOrShip =  (::events.getEventUnitTypesMask(curEvent)
    & (unitTypes.TANK.bit | unitTypes.SHIP.bit)) != 0
  local missionToLevelTable = {}
  if (isLevelBanMode)
    foreach(inst in curEvent?.missions_info ?? {})
      if (inst?.name && inst?.level)
        missionToLevelTable[inst.name] <- {
          level = inst.level
          origMisName  = inst?.origMisName
        }

  local missionList = {}
  foreach(gm in ::g_matching_game_modes.getGameModesByEconomicName(::events.getEventEconomicName(curEvent)))
    missionList.__update(gm?.mission_decl.missions_list ?? {})

  local assertMisNames = []
  foreach(name, val in missionList)
  {
    if (isLevelBanMode && missionToLevelTable?[name].origMisName)
      continue

    local missionInfo = ::get_mission_meta_info(missionToLevelTable?[name].origMisName ?? name)
    if((missionInfo?.level ?? "") == "")
    {
      assertMisNames.append(name)
      continue
    }
    local level = missionToLevelTable?[name].level ?? ::map_to_location(missionInfo.level)
    local map = isLevelBanMode ? level : name
    if (isLevelBanMode)
    {
      local levelMap = ::u.search(list, @(inst) inst.map == map)
      if (levelMap)
      {
        levelMap.missions.append(getMissionParams(name, missionInfo))
        continue
      }
    }

    local image = "{0}_thumb*".subst(
      ::get_level_texture(missionInfo.level, hasTankOrShip && ::regexp2(@"^av(n|g)").match(level))
        .slice(0,-1))

    local mapStateData = {
      disliked = dislikeList.indexof(map) != null,
      banned = banList.indexof(map) != null,
      liked = likeList.indexof(map) != null
    }

    list.append({
      mapId = list.len()
      map   = map
      title = getMissionLoc(name, missionInfo, isLevelBanMode)
      level = level
      image = image
      missions = [getMissionParams(name, missionInfo)]
      disliked = mapStateData.disliked
      banned = mapStateData.banned
      liked = mapStateData.liked
      state = getMapState(mapStateData)
    })
  }

  if(assertMisNames.len() > 0)
  {
    local invalidMissions = assertMisNames.reduce(@(a, b) a + ", " + b) // warning disable: -declared-never-used
    ::script_net_assert_once("MapPreferencesParams:", "Missions have no level")
  }

  if(!isLevelBanMode)
    list = sortByLevel(list)
  else
    foreach(inst in list)
      inst.missions.sort(@(a,b) a.sortIdx <=> b.sortIdx || a.type <=> b.type)

  return list
}

local function getMapsList(curEvent)
{
  if (curEvent not in mapsListByEvent)
    mapsListByEvent[curEvent] <- getMapsListImpl(curEvent)
  return mapsListByEvent[curEvent]
}

local function getParams(curEvent)
{
  local params = {bannedMissions = [], dislikedMissions = [], likedMissions = []}
  if(hasPreferences(curEvent))
    foreach(inst in getMapsList(curEvent))
    {
      if(inst.banned)
       params.bannedMissions.append(inst.map)
      if(inst.disliked)
        params.dislikedMissions.append(inst.map)
      if(inst.liked)
        params.likedMissions.append(inst.map)
    }

  return params
}

local function getCounters(curEvent)
{
  if(!hasPreferences(curEvent))
    return {}

  local banData = getProfileBanData(curEvent)
  local hasPremium  = ::havePremium()
  return {
    banned = {
      maxCounter = hasPremium
        ? curEvent?.maxBannedMissions ?? 0
        : 0,
      maxCounterWithPremium = curEvent?.maxBannedMissions ?? 0
      curCounter = banData.banned.len()
    },
    disliked = {
      maxCounter = hasPremium
        ? curEvent?.maxPremDislikedMissions ?? 0
        : curEvent?.maxDislikedMissions ?? 0,
      maxCounterWithPremium = curEvent?.maxPremDislikedMissions ?? 0
      curCounter = banData.disliked.len()
    },
    liked = {
      maxCounter = hasPremium
        ? curEvent?.maxPremLikedMissions ?? 0
        : curEvent?.maxLikedMissions ?? 0,
      maxCounterWithPremium = curEvent?.maxPremLikedMissions ?? 0
      curCounter = banData.liked.len()
    }
  }
}

local function resetProfilePreferences(curEvent, pref)
{
  local curBattleTypeName = getCurBattleTypeName(curEvent)
  local params = getProfileBanData(curEvent)
  foreach(item in params[pref])
  {
    mapPreferences.remove(curBattleTypeName, getPrefTypes()[pref].sType, item)
    mapsListByEvent?[curEvent].findvalue(@(map) map.map == item).__update({ state = "", [pref] = false })
  }
}

local function getPrefTitle(curEvent)
{
  return ! hasPreferences(curEvent) ? ""
    : curEvent.missionsBanMode == "level" ? ::loc("mainmenu/mapPreferences")
    : ::loc("mainmenu/missionPreferences")
}

addListenersWithoutEnv({
  EventsDataUpdated = @(_) mapsListByEvent.clear()
})

return {
  getParams = getParams
  getMapsList = getMapsList
  getCounters = getCounters
  getCurBattleTypeName = getCurBattleTypeName
  hasPreferences = hasPreferences
  resetProfilePreferences = resetProfilePreferences
  getPrefTitle = getPrefTitle
  getMapState = getMapState
  getInactiveMaps = getInactiveMaps
  getPrefTypes = getPrefTypes
}