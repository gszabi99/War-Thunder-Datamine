//-file:plus-string
from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")


let DataBlock = require("DataBlock")
let { format } = require("string")
let regexp2 = require("regexp2")
let time = require("%scripts/time.nut")
let { number_of_set_bits } = require("%sqstd/math.nut")
let { copyParamsToTable } = require("%sqstd/datablock.nut")
let { isIPoint3 } = u
let { Point2 } = require("dagor.math")
let { getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")

let missionModesList = [
  "missionsWon",
  "missionsWonScore",
  "missionsPlayed",
  "missionsPlayedScore",
  "totalMissionScore"
]

let typesForMissionModes = {
  playerUnit = {
    inSessionAnd   = "crewsUnitRank",
    inSessionTrue  = "usedInSessionUnit",
    inSessionFalse = "lastInSessionUnit"
  },
  playerType = {
    inSessionTrue  = "usedInSessionType",
    inSessionFalse = "lastInSessionType"
  },
  playerUnitRank = {
    inSessionAnd   = "crewsUnitRank",
    inSessionTrue  = "usedInSessionUnit",
    inSessionFalse = "lastInSessionUnit"
  },
  playerUnitMRank = {
    inSessionAnd   = "crewsUnitMRank",
    inSessionTrue  = "usedInSessionUnit",
    inSessionFalse = "lastInSessionUnit"
  },
  playerExpClass = {
    inSessionFalse = "lastInSessionClass"
  },
  playerTag = {
    inSessionFalse = "lastInSessionTag"
  }
}

let detailedMultiplierModesList = [
  "totalMissionScore"
]

let additionalTypes = [
  "critical", "lesserTeam", "inTurret", "isBurning", "targetInCaptureZone", "offenderIsPlayerControlled"
]

let locGroupByType = {
  offenderUnit         = "playerUnit"
  playerType           = "playerUnit"
  offenderType         = "playerUnit"
  playerTag            = "playerUnit"
  offenderTag          = "playerUnit"
  playerUnitRank       = "playerUnit"
  offenderUnitRank     = "playerUnit"
  playerUnitMRank      = "playerUnit"
  offenderUnitMRank    = "playerUnit"
  playerCountry        = "playerUnit"
  usedInSessionType    = "usedPlayerUnit"
  usedInSessionUnit    = "usedPlayerUnit"
  usedInSessionClass   = "usedPlayerUnit"
  usedInSessionTag     = "usedPlayerUnit"
  lastInSessionType    = "lastPlayerUnit"
  lastInSessionUnit    = "lastPlayerUnit"
  lastInSessionClass   = "lastPlayerUnit"
  lastInSessionTag     = "lastPlayerUnit"
  targetType           = "targetUnit"
  targetTag            = "targetUnit"
  crewsUnitRank        = "crewsUnit"
  crewsUnitMRank       = "crewsUnit"
  crewsTag             = "crewsUnit"
  offenderIsSupportGun = "weaponType"
  bulletModName        = "weaponType"
}

let minStatGroups = {
  place          = "statPlace"
  score          = "statScore"
  awardDamage    = "statAwardDamage"
  playerkills    = "statKillsPlayer"
  kills          = "statKillsAir"
  aikills        = "statKillsAirAi"
  groundkills    = "statKillsGround"
  aigroundkills  = "statKillsGroundAi"
  navalkills     = "statKillsNaval"
  ainavalkills   = "statKillsNavalAi"
  surfacekills   = "statKillsSurface"
  aisurfacekills = "statKillsSurfaceAi"
}

let bitModesList = {
  char_unlocks               = "unlock"
  unlocks                    = "unlock"
  char_resources             = "resource"
  char_mission_list          = "name"
  char_mission_completed     = "name"
  char_buy_modification_list = "name"
  missionCompleted           = "mission"
  char_unit_exist            = "unit" // must be here but in old format was skipped
}

let modeTypesWithoutProgress = [
  ""
  "char_always_progress" // char_always_progress do not have progress, only check conditions
  "char_crew_skill"
]

let formatParamsDefault = {
  rangeStr   = "%s"
  itemStr    = "%s"
  valueStr   = "%.1f"
  maxOnlyStr = "%s"
  minOnlyStr = "%s"
  bothStr    = "".concat("%s", loc("ui/mdash"), "%s")
}

let timeRangeConditions = ["timeRange", "char_time_range"]
let isTimeRangeCondition = @(c) timeRangeConditions.contains(c)

let regExpNumericEnding = regexp2("\\d+$")

let nestedUnlockModes = ["unlockOpenCount", "unlockStageCount", "unlocks", "char_unlocks"]
let isNestedUnlockMode = @(m) nestedUnlockModes.contains(m)

local mapIntDiffToName = null

let function getDiffNameByInt(modeInt) {
  if (mapIntDiffToName == null) {
    let blk = ::get_game_settings_blk()
    if (!blk?.mapIntDiffToName)
      return ""

    mapIntDiffToName = copyParamsToTable(blk.mapIntDiffToName)
  }

  return mapIntDiffToName?[modeInt.tostring()] ?? ""
}

let function getOverrideCondType(condBlk, unlockMode) {
  if (!isInArray(unlockMode, missionModesList))
    return null

  let curTypes = typesForMissionModes?[condBlk?.type]
  let inSession = condBlk?.inSession ?? false
  if (inSession)
    return (condBlk?.inSessionAnd ?? true) && curTypes?.inSessionAnd
      ? curTypes.inSessionAnd
      : curTypes?.inSessionTrue

  return curTypes?.inSessionFalse
}

let function getRankMultipliersTable(blk) {
  let mulTable = {}
  local hasAnyMulRank = false
  if (detailedMultiplierModesList.indexof(blk?.type ?? "") != null) {
    for (local rank = 1; rank <= ::max_country_rank; rank++) {
      let curMul = blk?[$"mulRank{rank}"]
      mulTable[rank] <- curMul
      if (!hasAnyMulRank && curMul != 1.0)
        hasAnyMulRank = true
    }
  }
  return hasAnyMulRank ? mulTable : {}
}

let function getRangeTextByPoint2(val, formatParams = {}, romanNumerals = false) {
  if (!(type(val) == "instance" && (val instanceof Point2)) && !(type(val) == "table"))
    return ""

  formatParams = formatParamsDefault.__merge(formatParams)
  let { rangeStr, itemStr, valueStr, maxOnlyStr, minOnlyStr, bothStr } = formatParams
  let a = val.x.tointeger() > 0
    ? romanNumerals ? ::get_roman_numeral(val.x) : format(valueStr, val.x)
    : ""
  let b = val.y.tointeger() > 0
    ? romanNumerals ? ::get_roman_numeral(val.y) : format(valueStr, val.y)
    : ""
  if (a == "" && b == "")
    return ""

  local range = ""
  if (a != "" && b != "")
    range = (a == b)
      ? format(itemStr, a)
      : format(bothStr, format(itemStr, a), format(itemStr, b))
  else if (a == "")
    range = format(maxOnlyStr, format(itemStr, b))
  else
    range = format(minOnlyStr, format(itemStr, a))

  return format(rangeStr, range)
}

let getRankRangeText = @(range) getRangeTextByPoint2(range, {
  rangeStr   = loc("events/rank")
  maxOnlyStr = loc("conditions/unitRank/format_max")
  minOnlyStr = loc("conditions/unitRank/format_min")
}, true)

let getMRankRangeText = @(range) getRangeTextByPoint2(range, {
  rangeStr   = loc("events/br")
  maxOnlyStr = loc("conditions/unitRank/format_max")
  minOnlyStr = loc("conditions/unitRank/format_min")
}, false)

let function getUnlockConditions(modeBlk) {
  return modeBlk
    ? (modeBlk % "condition").extend(modeBlk % "hostCondition").extend(modeBlk % "visualCondition")
    : []
}

// sets hidden param for hiding some conditions
let function hideConditionsFromBlk(blk, unlockBlk) {
  let conditionsArray = getUnlockConditions(blk)
  for (local i = conditionsArray.len() - 1; i >= 0; --i) {
    let condBlk = conditionsArray[i]
    if (condBlk?.type == "playerCountry" && condBlk.country == (unlockBlk?.country ?? "")) {
      let b = blk.getBlock(i)
      b.setBool("hidden", true)
    }
  }
}

let function getSubunlockCfg(conditions) {
  if (conditions.len() != 1)
    return null

  let cond = conditions[0]
  if (cond?.modeType != "char_unlocks" || cond?.values.len() != 1)
    return null

  let blk = getUnlockById(cond.values[0])
  if (blk?.hidden ?? false)
    return null

  return ::build_conditions_config(blk)
}

let createCondition = @(condType, values = null) {
  type = condType
  values = values
  needToShowInHeader = false
}

let isBitModeType = @(modeType) modeType in bitModesList

let function getMultipliersTable(blk) {
  let diffTable = {
    mulArcade = "ArcadeBattle"
    mulRealistic = "HistoricalBattle"
    mulHardcore = "FullRealBattles"
    mulWWBattleForOwnClan = "WWBattleForOwnClan"
  }

  let mulTable = {}
  if (detailedMultiplierModesList.indexof(blk?.type ?? "") != null) {
    let NUM_MISSION_TYPES = 9
    let forceShowMulModes = blk % "forceShowMulMode"
    for (local i = 0; i < NUM_MISSION_TYPES; i++) {
      let mulMode = blk?[$"mulMode{i}"] ?? 1.0
      if (mulMode != 1.0 || forceShowMulModes.contains(i)) {
        mulTable[i] <- mulMode
      }
    }
  }
  else
    foreach (paramName, diff in diffTable)
      mulTable[diff] <- blk?[paramName] ?? 1

  return mulTable
}

let function loadMainProgressCondition(blk) {
  let modeType = blk?.type
  if (!modeType || isInArray(modeType, modeTypesWithoutProgress)
      || blk?.dontShowProgress || modeType == "maxUnitsRankOnStartMission")
    return null

  let res = createCondition("mode")
  res.modeType <- modeType
  res.num <- blk?.rewardNum ?? blk?.num

  if ("customUnlockableList" in blk)
    res.values = blk.customUnlockableList % "unlock"

  res.hasCustomUnlockableList <- (res.values != null && res.values.len() > 0)

  if (blk?.typeLocID != null)
    res.modeTypeLocID <- blk.typeLocID

  if (isBitModeType(modeType)) {
    res.compareOR <- blk?.compareOR ?? false
    if (!res.hasCustomUnlockableList)
      res.values = blk % bitModesList[modeType]
    if (blk?.num == null)
      res.num = res.values.len()
  }

  foreach (p in ["country", "reason", "isShip", "typeLocIDWithoutValue"])
    if (blk?[p])
      res[p] <- blk[p]

  // uniq modeType params
  if (modeType == "unlockCount")
    res.unlockType <- blk?.unlockType ?? ""
  else if (modeType == "unlockOpenCount" || modeType == "unlockStageCount") {
    res.values = res.values ?? []
    let isUnlockStageCount = modeType == "unlockStageCount"
    if (!res.hasCustomUnlockableList)
      foreach (unlockId in (blk % "unlock")) {
        let unlock = getUnlockById(unlockId)
        if (unlock == null) {
          let debugUnlockData = blk?.unlock ?? toString(blk) // warning disable: -declared-never-used
          assert(false, "ERROR: Unlock does not exist")
          continue
        }

        if (isUnlockStageCount) {
          res.values.append(unlock.id)
          continue
        }

        let values = ("mode" in unlock) ? unlock.mode % "unlock" : []
        if (values.len() == 0)
          res.values.append(unlock.id)
        else
          res.values.extend(values)
      }
  }
  else if (modeType == "landings")
    res.carrierOnly <- blk?.carrierOnly ?? false
  else if (modeType == "char_static_progress")
    res.level <- blk?.level ?? 0
  else if (modeType == "char_resources_count")
    res.resourceType <- blk?.resourceType

  res.multiplier <- getMultipliersTable(blk)
  res.rankMultiplier <- getRankMultipliersTable(blk)
  return res
}

let function loadParamsConditions(blk) {
  let res = []
  if (blk?.hidden)
    return res

  if (blk?.elite != null && (type(blk?.elite) != "integer" || blk.elite > 1))
    res.append(createCondition("eliteUnitsOnly"))

  if (blk?.premium == false)
    res.append(createCondition("noPremiumVehicles"))

  if (blk?.era != null)
    res.append(createCondition("era", blk.era))

  if ((blk?.country ?? "") != "")
    res.append(createCondition("country", blk.country))

  if (blk?.unitClass != null) {
    let cond = blk % "unitClass"
    if (blk?.type == "char_crew_level_float" || blk?.type == "char_crew_level_count_float") {
      let shipCondIdx = cond.indexof("ship")
      if (shipCondIdx != null) {
        cond.remove(shipCondIdx)
        cond.append("ship_and_boat")
      }
    }

    res.append(createCondition("unitClass", cond))
  }

  if (blk?.type == "maxUnitsRankOnStartMission") { // 2 params conditions instead of 1 base
    let minRank = blk?.minRank ?? 0
    let maxRank = blk?.maxRank ?? minRank
    if (minRank) {
      let values = [minRank]
      if (maxRank > minRank)
        values.append(maxRank)
      res.append(createCondition("atLeastOneUnitsRankOnStartMission", values))
    }

    if (blk?.maxRank)
      res.append(createCondition("maxUnitsRankOnStartMission", maxRank))
  }

  return res
}

let function findCondition(list, cType, locGroup) {
  local cLocGroup = null
  foreach (cond in list) {
    cLocGroup = getTblValue("locGroup", cond, null)
    if (cond.type == cType && locGroup == cLocGroup)
      return cond
  }
  return null
}

let function mergeConditionToList(newCond, list) {
  let cType = newCond.type
  let cond = findCondition(list, cType, getTblValue("locGroup", newCond, null))
  if (!cond)
    return list.append(newCond) // warning disable: -unwanted-modification

  if (!newCond.values)
    return

  if (!cond.values)
    cond.values = newCond.values
  else {
    if (type(cond.values) != "array")
      cond.values = [cond.values]
    cond.values.extend((type(newCond.values) == "array") ? newCond.values : [newCond.values])
  }

  // merge specific by type
  if (cType == "modes") {
    let idx = u.find_in_array(cond.values, "online") // remove mode online if there is ther modes (clan, event, etc)
    if (idx >= 0 && cond.values.len() > 1)
      cond.values.remove(idx)
  }
}

let function getRangeString(val1, val2, formatStr = "%s") {
  val1 = val1.tostring()
  val2 = val2.tostring()
  return (val1 == val2)
    ? format(formatStr, val1)
    : format(formatStr, val1) + loc("ui/mdash") + format(formatStr, val2)
}

let function getDiffValueText(value, formatStr = "%s", lessIsBetter = false) {
  return lessIsBetter ? getRangeString(1, value, formatStr) : format(formatStr, value.tostring())
}

let function getDiffTextArrayByPoint3(val, formatStr = "%s", lessIsBetter = false) {
  let res = []

  if (!isIPoint3(val)) {
    res.append(getDiffValueText(val, formatStr, lessIsBetter))
    return res
  }

  if (val.x == val.y && val.x == val.z)
    res.append(getDiffValueText(val.x, formatStr, lessIsBetter))
  else
    foreach (idx, key in [ "x", "y", "z" ]) {
      let value = val[key]
      let valueStr = getDiffValueText(value, formatStr, lessIsBetter)
      res.append(valueStr + loc("ui/parentheses/space", {
        text = loc(getTblValue("abbreviation", ::g_difficulty.getDifficultyByDiffCode(idx), ""))
      }))
    }

  return res
}

let function loadCondition(blk, unlockBlk) {
  if (blk?.hidden)
    return null

  let t = blk?.type
  let res = createCondition(t)

  if (t == "weaponType") {
    let weaponArray = (blk % "weapon")
    if (weaponArray.contains("unguided_bomb") && weaponArray.contains("guided_bomb")) {
      weaponArray.remove(weaponArray.indexof("unguided_bomb"))
      weaponArray.remove(weaponArray.indexof("guided_bomb"))
      weaponArray.append("bomb")
    }
    res.values = weaponArray
  }
  else if (t == "location")
    res.values = (blk % "location")
  else if (t == "operationMap")
    res.values = (blk % "operationMap")
  else if (t == "activity")
    res.values = getDiffTextArrayByPoint3(blk?.percent, "%s%%")
  else if (t == "online" || t == "worldWar") {
    res.type = "modes"
    res.values = t
  }
  else if (t == "gameModeInfoString") {
    res.name <- blk?.name
    res.values = (blk % "value").filter(@(v) (blk % "hideValue").indexof(v) == null)

    if (blk?.locParamName)
      res.locParamName <- blk.locParamName
    if (blk?.locValuePrefix)
      res.locValuePrefix <- blk.locValuePrefix
  }
  else if (t == "battlepassProgress") {
    res.values = blk.progress
    res.season <- unlockBlk?.battlePassSeason ?? -1
  }
  else if (t == "eventMode") {
    res.values = (blk % "event_name")
    if (res.values.len())
      res.type = "events"
    else {
      res.type = "modes"

      let group = blk?.for_clans_only == true ? "clans_only"
                : blk?.is_event == false      ? "random_battles"
                : "events_only"
      res.values.append(group)
    }
  }
  else if (t == "playerUnit" || t == "offenderUnit" || t == "targetUnit")
    res.values = (blk % "class")
  else if (t == "playerType" || t == "targetType" || t == "offenderType") {
    res.values = (blk % "unitType")
    res.values.extend(blk % "unitClass")
  }
  else if (t == "playerExpClass")
    res.values = (blk % "class")
  else if (t == "playerTag" || t == "offenderTag" || t == "targetTag")
    res.values = (blk % "tag")
  else if (t == "playerCountry")
    res.values = (blk % "country")
  else if (t == "playerUnitRank" || t == "offenderUnitRank") {
    let range = Point2(blk?.minRank ?? 0, blk?.maxRank ?? 0)
    let rangeForEvent = Point2(blk?.minRankForEvent ?? range.x, blk?.maxRankForEvent ?? range.y)
    local v = getRankRangeText(range)
    if (!u.isEqual(range, rangeForEvent)) {
      let valForEvent = getRankRangeText(rangeForEvent)
      v = "".concat(v, loc("ui/parentheses/space", {
        text = loc("conditions/forEventUnit", { condition = valForEvent })
      }))
    }
    res.values = v != "" ? v : null
    res.needToShowInHeader = true
  }
  else if (t == "playerUnitMRank" || t == "offenderUnitMRank") {
    local range = Point2(blk?.minMRank ?? 0, blk?.maxMRank ?? 0)
    local rangeForEvent = Point2(blk?.minMRankForEvent ?? range.x, blk?.maxMRankForEvent ?? range.y)
    let hasForEventCond = !u.isEqual(range, rangeForEvent)
    range = Point2(::calc_battle_rating_from_rank(range.x),
      range.y.tointeger() > 0 ? ::calc_battle_rating_from_rank(range.y) : 0)
    local v = getMRankRangeText(range)
    if (hasForEventCond) {
      rangeForEvent = Point2(::calc_battle_rating_from_rank(rangeForEvent.x),
        rangeForEvent.y.tointeger() > 0 ? ::calc_battle_rating_from_rank(rangeForEvent.y) : 0)
      let valForEvent = getMRankRangeText(rangeForEvent)
      v = "".concat(v, loc("ui/parentheses/space", {
        text = loc("conditions/forEventUnit", { condition = valForEvent })
      }))
    }
    res.values = v != "" ? v : null
    res.needToShowInHeader = true
  }
  else if (t == "char_mission_completed")
    res.values = blk?.name ?? ""
  else if (t == "difficulty") {
    res.values = blk % "difficulty"
    res.exact <- blk?.exact ?? false
  }
  else if (t == "minStat") {
    let stat = blk?.stat ?? ""

    let lessIsBetter = stat == "place"
    res.values = getDiffTextArrayByPoint3(blk?.value, "%s", lessIsBetter)
    if (!res.values.len())
      return null

    res.locGroup <- $"{(minStatGroups?[stat] ?? "")}InSession"
  }
  else if (isTimeRangeCondition(t)) {
    let beginTime = blk?.beginDate != null ? time.getTimestampFromStringUtc(blk.beginDate) : -1
    if (beginTime != -1) {
      res.beginTime <- beginTime
      res.beginDate <- time.buildDateTimeStr(beginTime)
    }

    let endTime = blk?.endDate != null ? time.getTimestampFromStringUtc(blk.endDate) : -1
    if (endTime != -1) {
      res.endTime <- endTime
      res.endDate <- time.buildDateTimeStr(endTime)
    }
  }
  else if (t == "missionPostfix") {
    res.values = []
    let values = blk % "postfix"
    foreach (val in values)
      u.appendOnce(regExpNumericEnding.replace("", val), res.values)
    res.locGroup <- getTblValue("allowed", blk, true) ? "missionPostfixAllowed" : "missionPostfixProhibited"
    if (blk?.locValuePrefix)
      res.locValuePrefix <- blk.locValuePrefix
  }
  else if (t == "mission")
    res.values = (blk % "mission")
  else if (t == "tournamentMode")
    res.values = (blk % "mode")
  else if (t == "missionType") {
    res.values = []
    let values = blk % "missionType"
    foreach (modeInt in values)
      res.values.append(getDiffNameByInt(modeInt))
  }
  else if (t == "char_personal_unlock")
    res.values = blk % "personalUnlocksType"
  else if (t == "offenderIsSupportGun")
    res.values = ["actionBarItem/artillery_target"]
  else if (t == "targetIsPlayer") {
    res.values = []
    foreach (key in ["includePlayers", "includeBots", "includeAI"])
      if (blk?[key])
        res.values.append(key)

    if (blk?.includePlayers == null)
      res.values.append("includePlayers")

    if (res.values.len() > 1 || (res.values.len() == 1 && res.values[0] != "includePlayers"))
      res.locGroup <- "targets"
    else
      res.values = null
  }
  else if (t == "targetDistance") {
    res.values = getDiffTextArrayByPoint3(blk?.distance ?? -1, "%s" + loc("measureUnits/meters_alt"))
    res.gt <- blk?.gt ?? true
  }
  else if (isInArray(t, additionalTypes)) {
    res.type = "additional"
    res.values = t
  }
  else if (t == "higherBR") {
    let range = Point2(blk?.diffBR ?? 0, blk?.diffBRMax ?? 0)
    let v = getRangeTextByPoint2(range, {
      maxOnlyStr = loc("conditions/unitRank/format_max")
      minOnlyStr = loc("conditions/unitRank/format_min")
    })
    res.values = v != "" ? v : null
  }
  else if (t == "ammoMass") {
    res.values = {
      value = format("%d %s", (blk?.mass ?? 1), loc("measureUnits/kg"))
      notLess = blk?.notLess ?? true
    }
  }
  else if (t == "bulletCaliber") {
    res.values = {
      value = format("%d %s", (blk?.caliber ?? 1) * 1000, loc("measureUnits/mm"))
      notLess = blk?.notLess ?? true
    }
  }
  else if (t == "bulletModName")
    res.values = (blk % "name")
  else if (t == "inCapturedZone") {
    res.type = "additional"
    let zoneType = (blk?.any ?? false) ? "any"
      : (blk?.enemy ?? false) ? "enemy" : "allied"
    res.values = $"{t}/{zoneType}Zone"
  }
  else if (t == "offenderSpeed") {
    res.values = {
      value = format("%d %s", (blk?.speed ?? 0), loc("measureUnits/kmh"))
      notLess = blk?.notLess ?? true
    }
  }

  let overrideCondType = getOverrideCondType(blk, unlockBlk?.mode.type)
  if (overrideCondType)
    res.type = overrideCondType

  if (res.type in locGroupByType)
    res.locGroup <- locGroupByType[res.type]
  return res
}

// returns array of conditions, unlockBlk - main body of unlock
//
// condition format:
// type = string
// values = null || array of values
// needToShowInHeader - shows values in header of unlock (used in battletasks and battlepass challenges)
// locGroup - group values in one loc string instead of different string for each value.
//
// specific params for main progresscondition (type == "mode"):
// modeType - mode type of conditions with progress
//   such condition can be only one in list, and always first.
// modeTypeLocID  - locId for mode type
let function loadConditionsFromBlk(blk, unlockBlk = DataBlock()) {
  let res = []
  let mainCond = loadMainProgressCondition(blk) // main condition by modeType
  if (mainCond)
    res.append(mainCond)

  res.extend(loadParamsConditions(blk)) // conditions by mode params - elite, country etc

  hideConditionsFromBlk(blk, unlockBlk) // don't show conditions by rule

  let conditionsArray = getUnlockConditions(blk)
  foreach (condBlk in conditionsArray) {
    let condition = loadCondition(condBlk, unlockBlk)
    if (condition)
      mergeConditionToList(condition, res)
  }
  return res
}

// generates conditions texts, adds colorized "<text>: <valueText>" to text
let function addToText(text, name, valueText = "", color = "unlockActiveColor", separator = "\n") {
  text += (text.len() ? separator : "") + name
  if (valueText != "")
    text += (name.len() ? loc("ui/colon") : "") + "<color=@" + color + ">" + valueText + "</color>"
  return text
}

let function getHeaderCondition(conditions) {
  foreach (c in conditions)
    if (c.needToShowInHeader)
      return c.values
  return null
}

let function getMainProgressCondition(conditions) {
  foreach (c in conditions)
    if (getTblValue("modeType", c))
      return c
  return null
}

let function getTimeRangeCondition(unlockBlk) {
  let conds = getUnlockConditions(unlockBlk?.mode)
  return conds.findvalue(@(c) isTimeRangeCondition(c.type))
}

let function getMainConditionListPrefix(conditions) {
  let mainCondition = getMainProgressCondition(conditions)
  if (mainCondition == null)
    return ""
  if (!mainCondition.values)
    return ""

  let modeType = mainCondition.modeType

  if (mainCondition.hasCustomUnlockableList ||
      (isNestedUnlockMode(modeType) && mainCondition.values.len() > 1))
    return loc("ui/awards") + loc("ui/colon")

  return ""
}

let function getProgressBarData(modeType, curVal, maxVal) {
  let res = {
    show = !isInArray(modeType, modeTypesWithoutProgress)
    value = 0
  }

  if (isBitModeType(modeType)) {
    curVal = number_of_set_bits(curVal)
    maxVal = number_of_set_bits(maxVal)
  }

  res.show = res.show && maxVal > 1 && curVal < maxVal
  res.value = clamp(1000 * curVal / (maxVal || 1), 0, 1000)
  return res
}

return {
  getSubunlockCfg
  getMultipliersTable
  getMainProgressCondition
  getTimeRangeCondition
  getMainConditionListPrefix
  getUnlockConditions
  getHeaderCondition
  getProgressBarData
  getRangeTextByPoint2
  getRangeString
  loadMainProgressCondition
  loadConditionsFromBlk
  loadCondition
  isNestedUnlockMode
  isTimeRangeCondition
  isBitModeType
  addToText
  getDiffNameByInt
}