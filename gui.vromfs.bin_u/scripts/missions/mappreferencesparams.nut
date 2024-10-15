from "%scripts/dagui_natives.nut" import get_level_texture, map_to_location
from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")

let { debug_dump_stack } = require("dagor.debug")
let { split_by_chars, format } = require("string")
let regexp2 = require("regexp2")
let mapPreferences = require("mapPreferences")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { getMissionLocName } = require("%scripts/missions/missionsUtilsModule.nut")
let { havePremium } = require("%scripts/user/premium.nut")
let { get_meta_mission_info_by_name } = require("guiMission")
let { getGameModesByEconomicName } = require("%scripts/matching/matchingGameModes.nut")
let { getMaxEconomicRank, calcBattleRatingFromRank } = require("%appGlobals/ranks_common_shared.nut")
let { getEventEconomicName } = require("%scripts/events/eventInfo.nut")

const MIN_AVAILABLE_VEHICLE_BR   = 1.0

let mapsListByEvent = {}

let sortIdxByMissionType = {
  ["Dom"]   = 0,
  ["Bttl"]  = 1,
  ["other"] = 2
}

function getPrefTypes() {
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

function hasPreferences(curEvent) {
  return (curEvent?.missionsBanMode ?? "none") != "none"
}

function sortByLevel(list) {
  list.sort(@(a, b) a.image <=> b.image)
  foreach (idx, map in list)
    map.mapId = idx
  return list
}

function getCurBattleTypeName(curEvent) {
  return !hasPreferences(curEvent)
    ? "" : (curEvent?.statistic_group && curEvent?.difficulty)
      ? $"{curEvent.statistic_group}_{curEvent.difficulty}" : curEvent.name
}

function getProfileBanData(curEvent) {
  let curBattleTypeName = getCurBattleTypeName(curEvent)
  return {
    disliked = mapPreferences.get(curBattleTypeName, mapPreferences.DISLIKE),
    banned = mapPreferences.get(curBattleTypeName, mapPreferences.BAN),
    liked = mapPreferences.get(curBattleTypeName, mapPreferences.LIKE),
  }
}

function getMissionLoc(missionId, config, isLevelBanMode, locNameKey = "locName") {
  local missionLocName = loc($"missions/{missionId}")
  let locNameValue = config?[locNameKey]
  if (locNameValue && locNameValue.len())
    missionLocName = isLevelBanMode ? loc(split_by_chars(locNameValue, "; ")?[1] ?? "") :
      getMissionLocName(config, locNameKey)

  return isLevelBanMode
    ? " ".join([missionLocName,
      loc("ui/parentheses/space", { text = loc("maps/preferences/all_missions") })], true)
    : missionLocName
}

function getMapState(map) {
  return map.liked ? "liked" : map.banned ? "banned" : map.disliked ? "disliked" : ""
}

function getInactiveMaps(curEvent, mapsList) {
  let res = {}
  let banData = getProfileBanData(curEvent)
  foreach (name, list in banData) {
    res[name] <- []
      foreach (map in list)
        if (!u.search(mapsList, @(inst) inst.map == map))
          res[name].append(map)
  }

  return res
}

function getBattleRatingsRangeText(minRank, maxRank) {
  let minVehicleBr = max(
    calcBattleRatingFromRank(minRank)
    MIN_AVAILABLE_VEHICLE_BR
  )
  let maxVehicleBr = calcBattleRatingFromRank(maxRank)
  let maxAvailableBr = calcBattleRatingFromRank(getMaxEconomicRank())
  return minVehicleBr == maxVehicleBr ? format("%.1f", minVehicleBr)
    : maxVehicleBr > maxAvailableBr ? $"{format("%.1f", minVehicleBr)}+"
    : $"{format("%.1f", minVehicleBr)} - {format("%.1f", maxVehicleBr)}"
}

function getBattleRatingsDescriptionText(minRank, maxRank) {
  return "".concat(
    loc("mainmenu/brText")
    $"{loc("ui/colon")}"
    getBattleRatingsRangeText(minRank, maxRank)
  )
}

function getMissionParams(name, missionInfo, ranksRange) {
  let mType = name.split("_").top().split("Conq").top()
  return {
    id = name,
    title = getMissionLoc(name, missionInfo, false),
    type = mType,
    sortIdx = sortIdxByMissionType?[mType] ?? sortIdxByMissionType.other
    ranksRange
  }
}

function getMapsListImpl(curEvent) {
  if (!hasPreferences(curEvent))
    return []

  let isLevelBanMode = curEvent.missionsBanMode == "level"
  let banData = getProfileBanData(curEvent)
  let banList = banData.banned
  let dislikeList = banData.disliked
  let likeList = banData.liked
  local list = []
  let hasTankOrShip =  (::events.getEventUnitTypesMask(curEvent)
    & (unitTypes.TANK.bit | unitTypes.SHIP.bit)) != 0
  let missionToLevelTable = {}
  if (isLevelBanMode)
    foreach (inst in curEvent?.missions_info ?? {})
      if (inst?.name && inst?.level)
        missionToLevelTable[inst.name] <- {
          level = inst.level
          origMisName  = inst?.origMisName
        }

  let missionList = {}
  foreach (gm in getGameModesByEconomicName(getEventEconomicName(curEvent)))
    missionList.__update(gm?.mission_decl.missions_list ?? {})

  let assertMisNames = []
  foreach (name, val in missionList) {
    if (isLevelBanMode && missionToLevelTable?[name].origMisName)
      continue

    let missionInfo = get_meta_mission_info_by_name(missionToLevelTable?[name].origMisName ?? name)
    if ((missionInfo?.level ?? "") == "") {
      assertMisNames.append(name)
      continue
    }
    let level = missionToLevelTable?[name].level ?? map_to_location(missionInfo.level)
    let map = isLevelBanMode ? level : name
    let unrestrictedRanksRange = { minMRank = 0, maxMRank = getMaxEconomicRank() + 1.0 }
    let ranksRange = val?.enableIf ?? unrestrictedRanksRange
    if (isLevelBanMode) {
      let levelMap = u.search(list, @(inst) inst.map == map)
      if (levelMap) {
        let minRank = min(levelMap.minMRank, ranksRange.minMRank)
        let maxRank = max(levelMap.maxMRank, ranksRange.maxMRank)

        levelMap.missions.append(getMissionParams(name, missionInfo, ranksRange))
        levelMap.minMRank = minRank
        levelMap.maxMRank = maxRank
        levelMap.brRangeText = getBattleRatingsRangeText(minRank, maxRank)
        continue
      }
    }

    let image = "{0}_thumb*".subst(
      get_level_texture(missionInfo.level, hasTankOrShip && regexp2(@"^av(n|g)").match(level))
        .slice(0, -1))

    let mapStateData = {
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
      missions = [getMissionParams(name, missionInfo, ranksRange)]
      disliked = mapStateData.disliked
      banned = mapStateData.banned
      liked = mapStateData.liked
      state = getMapState(mapStateData)
      minMRank = ranksRange.minMRank
      maxMRank = ranksRange.maxMRank
      brRangeText = getBattleRatingsRangeText(ranksRange.minMRank, ranksRange.maxMRank)
    })
  }

  if (assertMisNames.len() > 0) {
    let invalidMissions = assertMisNames.reduce(@(a, b) $"{a}, {b}") // warning disable: -declared-never-used
    debug_dump_stack()
    logerr("".concat("MapPreferencesParams: Some missions have no level to show map preferences.",
      "Ask designers to check missions from invalidMissions callstack variable in matching configs"))
  }

  if (!isLevelBanMode)
    list = sortByLevel(list)
  else
    foreach (inst in list)
      inst.missions.sort(@(a, b) a.sortIdx <=> b.sortIdx || a.type <=> b.type)

  return list
}

function getMapsList(curEvent) {
  if (curEvent not in mapsListByEvent)
    mapsListByEvent[curEvent] <- getMapsListImpl(curEvent)
  return mapsListByEvent[curEvent]
}

function getParams(curEvent) {
  let params = { bannedMissions = [], dislikedMissions = [], likedMissions = [] }
  if (hasPreferences(curEvent))
    foreach (inst in getMapsList(curEvent)) {
      if (inst.banned)
       params.bannedMissions.append(inst.map)
      if (inst.disliked)
        params.dislikedMissions.append(inst.map)
      if (inst.liked)
        params.likedMissions.append(inst.map)
    }

  return params
}

function getCounters(curEvent) {
  if (!hasPreferences(curEvent))
    return {}

  let banData = getProfileBanData(curEvent)
  return {
    banned = {
      maxCounter = havePremium.value
        ? curEvent?.maxBannedMissions ?? 0
        : 0,
      maxCounterWithPremium = curEvent?.maxBannedMissions ?? 0
      curCounter = banData.banned.len()
    },
    disliked = {
      maxCounter = havePremium.value
        ? curEvent?.maxPremDislikedMissions ?? 0
        : curEvent?.maxDislikedMissions ?? 0,
      maxCounterWithPremium = curEvent?.maxPremDislikedMissions ?? 0
      curCounter = banData.disliked.len()
    },
    liked = {
      maxCounter = havePremium.value
        ? curEvent?.maxPremLikedMissions ?? 0
        : curEvent?.maxLikedMissions ?? 0,
      maxCounterWithPremium = curEvent?.maxPremLikedMissions ?? 0
      curCounter = banData.liked.len()
    }
  }
}

function resetProfilePreferences(curEvent, pref) {
  let curBattleTypeName = getCurBattleTypeName(curEvent)
  let params = getProfileBanData(curEvent)
  foreach (item in params[pref]) {
    mapPreferences.remove(curBattleTypeName, getPrefTypes()[pref].sType, item)
    mapsListByEvent?[curEvent].findvalue(@(map) map.map == item).__update({ state = "", [pref] = false })
  }
}

function getPrefTitle(curEvent) {
  return ! hasPreferences(curEvent) ? ""
    : curEvent.missionsBanMode == "level" ? loc("mainmenu/mapPreferences")
    : loc("mainmenu/missionPreferences")
}

addListenersWithoutEnv({
  EventsDataUpdated = @(_) mapsListByEvent.clear()
  GameLocalizationChanged = @(_) mapsListByEvent.clear()
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
  getBattleRatingsDescriptionText = getBattleRatingsDescriptionText
}