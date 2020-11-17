/*
  ::UnlockConditions API:

  loadConditionsFromBlk(blk, unlockBlk = ::DataBlock()) - return array of conditions, unlockBlk - main body of unlock
  hideConditionsFromBlk(blk, unlockBlk) - set param hidden, for not displaying some conditions
  getConditionsText(conditions, curValue, maxValue, params = null)
                                          - return descripton by array of conditions
                                          - curValue - current value to show in text (if null, not show)
                                          - maxvalue - overrride progress value from mode if maxValue != null
                                          - params:
                                            * if inlineText==true then condition will be generated in following way:
                                              "<main condition> (<other conditions>) <multipliers>"
                                            * locEnding - try to use it as ending for main condition localization key
                                              if not found, use usual locId
  getMainConditionText(conditions, curValue, maxValue)
                                          - get text only of the main condition
  addToText(text, name, valueText = "", separator = "\n")
                                          - add colorized "<text>: <valueText>" to text
                                          - used for generation conditions texts
                                          - custom separator can be specified
  isBitModeType(modeType)                 - (bool) is mode count by complete all values
  getMainProgressCondition(conditions)    - get main condition from list to show progress.
*/


local time = require("scripts/time.nut")
local stdMath = require("std/math.nut")
local { getRoleText } = require("scripts/unit/unitInfoTexts.nut")
local { processUnitTypeArray } = require("scripts/unit/unitClassType.nut")

local missionModesList = [
  "missionsWon",
  "missionsWonScore",
  "missionsPlayed",
  "missionsPlayedScore"
]

local typesForMissionModes = {
  playerUnit = {
    inSessionAnd = "crewsUnitRank",
    inSessionTrue = "usedInSessionUnit",
    inSessionFalse = "lastInSessionUnit"
  },
  playerType = {
    inSessionAnd = "crewsUnitRank",
    inSessionTrue = "usedInSessionType",
    inSessionFalse = "lastInSessionType"
  },
  playerUnitRank = {
    inSessionAnd = "crewsUnitRank",
    inSessionTrue = "usedInSessionUnit",
    inSessionFalse = "lastInSessionUnit"
  },
  playerUnitMRank = {
    inSessionAnd = "crewsUnitMRank",
    inSessionTrue = "usedInSessionUnit",
    inSessionFalse = "lastInSessionUnit"
  },
  playerUnitClass = {
    inSessionAnd = "crewsTag",
    inSessionTrue = "usedInSessionClass",
    inSessionFalse = "lastInSessionClass"
  },
  playerUnitFilter = {
    inSessionAnd = "crewsTag",
    inSessionTrue = "usedInSessionUnit",
    inSessionFalse = "lastInSessionUnit"
  },
  playerExpClass = {
    inSessionFalse = "lastInSessionClass"
  },
  playerTag = {
    inSessionFalse = "lastInSessionTag"
  }
}

local function getOverrideCondType(condBlk, unlockMode) {
  local overrideCondType

  if (::isInArray(unlockMode, missionModesList)) {
    local inSession = condBlk?.inSession ?? false
    local curTypes = typesForMissionModes?[condBlk?.type]
    if (inSession)
      overrideCondType = (condBlk?.inSessionAnd ?? true) ? curTypes?.inSessionAnd : curTypes?.inSessionTrue
    else
      overrideCondType = curTypes?.inSessionFalse
  }

  return overrideCondType
}

::UnlockConditions <- {
  conditionsOrder = [
    "beginDate", "endDate",
    "missionsWon", "mission", "char_mission_completed",
    "missionPostfixAllowed", "missionPostfixProhibited", "missionType",
    "atLeastOneUnitsRankOnStartMission", "maxUnitsRankOnStartMission",
    "unitExists", "additional", "unitClass",
    "gameModeInfoString", "modes", "events", "tournamentMode",
    "location", "operationMap", "weaponType", "difficulty",
    "playerUnit", "playerType", "playerExpClass", "playerUnitRank", "playerUnitMRank", "playerTag",
    "targetUnit", "targetType", "targetExpClass", "targetUnitClass", "targetTag",
    "crewsUnit", "crewsUnitRank", "crewsUnitMRank", "crewsTag", "usedPlayerUnit", "lastPlayerUnit",
    "activity", "minStat", "statPlace", "statScore", "statAwardDamage",
    "statPlaceInSession", "statScoreInSession", "statAwardDamageInSession",
    "targetIsPlayer", "eliteUnitsOnly", "noPremiumVehicles", "era", "country", "playerCountry",
    "targets", "targetDistance"
  ]

  condWithValuesInside = [
    "atLeastOneUnitsRankOnStartMission", "eliteUnitsOnly"
  ]

  additionalTypes = ["critical", "lesserTeam", "teamLeader", "inTurret", "isBurning"]

  locGroupByType = {
    playerType             = "playerUnit"
    playerTag              = "playerUnit"
    playerUnitRank         = "playerUnit"
    playerUnitMRank        = "playerUnit"
    usedInSessionType      = "usedPlayerUnit"
    usedInSessionUnit      = "usedPlayerUnit"
    usedInSessionClass     = "usedPlayerUnit"
    usedInSessionTag       = "usedPlayerUnit"
    lastInSessionType      = "lastPlayerUnit"
    lastInSessionUnit      = "lastPlayerUnit"
    lastInSessionClass     = "lastPlayerUnit"
    lastInSessionTag       = "lastPlayerUnit"
    targetType             = "targetUnit"
    targetTag              = "targetUnit"
    crewsUnitRank          = "crewsUnit"
    crewsUnitMRank         = "crewsUnit"
    crewsTag               = "crewsUnit"
    offenderIsSupportGun   = "weaponType"
    targetUnitClass        = "targetExpClass"
  }

  mapConditionUnitType = {
    aircraft          = "unit_aircraft"
    tank              = "unit_tank"
    typeLightTank     = "type_light_tank"
    typeMediumTank    = "type_medium_tank"
    typeHeavyTank     = "type_heavy_tank"
    typeSPG           = "type_tank_destroyer"
    typeSPAA          = "type_spaa"
    typeTankDestroyer = "type_tank_destroyer"
    typeFighter       = "type_fighter"
    typeDiveBomber    = "type_dive_bomber"
    typeBomber        = "type_bomber"
    typeAssault       = "type_assault"
    typeStormovik     = "type_assault"
    typeTransport     = "type_transport"
    typeStrikeFighter = "type_strike_fighter"
  }

  minStatGroups = {
    place         = "statPlace"
    score         = "statScore"
    awardDamage   = "statAwardDamage"
    playerkills   = "statKillsPlayer"
    kills         = "statKillsAir"
    aikills       = "statKillsAirAi"
    groundkills   = "statKillsGround"
    aigroundkills = "statKillsGroundAi"
  }

  bitModesList = {
    char_unlocks               = "unlock"
    unlocks                    = "unlock"
    char_resources             = "resource"
    char_mission_list          = "name"
    char_mission_completed     = "name"
    char_buy_modification_list = "name"
    missionCompleted           = "mission"
    char_unit_exist            = "unit" //must be here but in old format was skipped
  }

  modeTypesWithoutProgress = [
    ""
    "char_always_progress" //char_always_progress do not have progress, only check conditions

    "char_crew_skill"
  ]

  singleAttachmentList = {
    unlockOpenCount = "unlock"
    unlockStageCount = "unlock"
  }

  customLocTypes = ["gameModeInfoString"]

  formatParamsDefault = {
    rangeStr = "%s"
    itemStr = "%s"
    valueStr = "%.1f"
    maxOnlyStr = "%s"
    minOnlyStr = "%s"
    bothStr = "%s"+ ::loc("ui/mdash") + "%s"
  }

  regExpNumericEnding = ::regexp2("\\d+$")

  function getRangeTextByPoint2(val, formatParams = {}, romanNumerals = false)
  {
    if (!(type(val) == "instance" && (val instanceof ::Point2)) && !(type(val) == "table"))
      return ""

    formatParams = formatParamsDefault.__merge(formatParams)
    local { rangeStr, itemStr, valueStr, maxOnlyStr, minOnlyStr, bothStr } = formatParams
    local a = val.x.tointeger() > 0 ? romanNumerals ? ::get_roman_numeral(val.x) : ::format(valueStr, val.x) : ""
    local b = val.y.tointeger() > 0 ? romanNumerals ? ::get_roman_numeral(val.y) : ::format(valueStr, val.y) : ""
    if (a == "" && b == "")
      return ""

    local range = ""
    if (a != "" && b != "")
      range = a == b
        ? ::format(itemStr, a)
        : ::format(bothStr,
          ::format(itemStr, a),
          ::format(itemStr, b))
    else if (a == "")
      range = ::format(maxOnlyStr, ::format(itemStr, b))
    else
      range = ::format(minOnlyStr, ::format(itemStr, a))

    return ::format(rangeStr, range)
  }

  function getRangeString(val1, val2, formatStr = "%s")
  {
    val1 = val1.tostring()
    val2 = val2.tostring()
    return (val1 == val2) ? ::format(formatStr, val1) : ::format(formatStr, val1) + ::loc("ui/mdash") + ::format(formatStr, val2)
  }

  function hideConditionsFromBlk(blk, unlockBlk)
  {
    local conditionsArray = blk % "condition"
    for (local i = conditionsArray.len() - 1; i >= 0 ; i--)
    {
      local condBlk = conditionsArray[i]
      if (condBlk?.type == "playerCountry")
      {
        if (condBlk.country == (unlockBlk?.country ?? ""))
        {
          local b = blk.getBlock(i)
          b.setBool("hidden", true)
        }
      }
    }
  }
}


//condition format:
//{
//  type = string
//  values = null || array of values
//  locGroup  - group values in one loc string instead of different string for each value.
//
//  specific params for main progresscondition (type == "mode")
//  modeType - mode type of conditions with progress
//             such condition can be only one in list, and always first.
//  modeTypeLocID  - locId for mode type
//}
UnlockConditions.loadConditionsFromBlk <- function loadConditionsFromBlk(blk, unlockBlk = ::DataBlock())
{
  local res = []
  local mainCond = loadMainProgressCondition(blk) //main condition by modeType
  if (mainCond)
    res.append(mainCond)

  res.extend(loadParamsConditions(blk)) //conditions by mode params - elite, country etc

  hideConditionsFromBlk(blk, unlockBlk) //don't show conditions by rule

  local unlockMode = unlockBlk?.mode.type

  foreach(condBlk in blk % "condition") //conditions determined by blocks "condition"
  {
    local condition = loadCondition(condBlk, unlockMode)
    if (condition)
      _mergeConditionToList(condition, res)
  }
  return res
}

UnlockConditions._createCondition <- function _createCondition(condType, values = null)
{
  return {
    type = condType
    values = values
  }
}

UnlockConditions._mergeConditionToList <- function _mergeConditionToList(newCond, list)
{
  local cType = newCond.type
  local cond = _findCondition(list, cType, ::getTblValue("locGroup", newCond, null))
  if (!cond)
    return list.append(newCond)

  if (!newCond.values)
    return

  if (!cond.values)
    cond.values = newCond.values
  else
  {
    if (typeof(cond.values) != "array")
      cond.values = [cond.values]
    cond.values.extend(newCond.values)
  }

  //merge specific by type
  if (cType == "modes")
  {
    local idx = ::find_in_array(cond.values, "online") //remove mode online if there is ther modes (clan, event, etc)
    if (idx >= 0 && cond.values.len() > 1)
      cond.values.remove(idx)
  }
}

UnlockConditions._findCondition <- function _findCondition(list, cType, locGroup)
{
  local cLocGroup = null
  foreach(cond in list)
  {
    cLocGroup = ::getTblValue("locGroup", cond, null)
    if (cond.type == cType && locGroup == cLocGroup)
      return cond
  }
  return null
}

UnlockConditions.isBitModeType <- function isBitModeType(modeType)
{
  return modeType in bitModesList
}

UnlockConditions.isMainConditionBitType <- function isMainConditionBitType(mainCond)
{
  return mainCond != null && isBitModeType(mainCond.modeType)
}

UnlockConditions.isCheckedBySingleAttachment <- function isCheckedBySingleAttachment(modeType)
{
  return modeType in singleAttachmentList || isBitModeType(modeType)
}

UnlockConditions.loadMainProgressCondition <- function loadMainProgressCondition(blk)
{
  local modeType = blk?.type
  if (!modeType || ::isInArray(modeType, modeTypesWithoutProgress)
      || blk?.dontShowProgress || modeType == "maxUnitsRankOnStartMission")
    return null

  local res = _createCondition("mode")
  res.modeType <- modeType
  res.num <- blk?.rewardNum ?? blk?.num

  if ("customUnlockableList" in blk)
    res.values = blk.customUnlockableList % "unlock"

  res.hasCustomUnlockableList <- (res.values != null && res.values.len() > 0)

  if (blk?.typeLocID != null)
    res.modeTypeLocID <- blk.typeLocID
  if (isBitModeType(modeType))
  {
    if (!res.hasCustomUnlockableList)
      res.values = blk % bitModesList[modeType]
    res.compareOR <- blk?.compareOR ?? false
    if (blk?.num == null)
      res.num = res.values.len()
  }

  foreach(p in ["country", "reason", "isShip", "typeLocIDWithoutValue"])
    if (blk?[p])
      res[p] <- blk[p]

  //uniq modeType params
  if (modeType == "unlockCount")
    res.unlockType <- blk?.unlockType ?? ""
  else if (modeType == "unlockOpenCount" || modeType == "unlockStageCount")
  {
    res.values = res.values ?? []
    if (!res.hasCustomUnlockableList)
      foreach (unlockId in (blk % "unlock")) {
        local unlock = ::g_unlocks.getUnlockById(unlockId)
        if (unlock == null) {
          local debugUnlockData = blk?.unlock ?? ::toString(blk) // warning disable: -declared-never-used
          ::dagor.assertf(false, "ERROR: Unlock does not exist")
          continue
        }
        res.values.append(unlock.id)
      }
  }
  else if (modeType == "landings")
    res.carrierOnly <- blk?.carrierOnly ?? false
  else if (modeType == "char_static_progress")
    res.level <- blk?.level ?? 0
  else if (modeType == "char_resources_count")
    res.resourceType <- blk?.resourceType

  res.multiplier <- getMultipliersTable(blk)
  return res
}

UnlockConditions.loadParamsConditions <- function loadParamsConditions(blk)
{
  local res = []
  if (blk?.hidden)
    return res

  if (blk?.elite != null && (typeof(blk?.elite) != "integer" || blk.elite > 1))
    res.append(_createCondition("eliteUnitsOnly"))

  if (blk?.premium == false)
    res.append(_createCondition("noPremiumVehicles"))

  if (blk?.era != null)
    res.append(_createCondition("era", blk.era))

  if ((blk?.country ?? "") != "")
    res.append(_createCondition("country", blk.country))

  if (blk?.unitClass != null) {
    local cond = blk % "unitClass"
    if (blk?.type == "char_crew_level_float" || blk?.type == "char_crew_level_count_float") {
      local shipCondIdx = cond.indexof("ship")
      if (shipCondIdx != null) {
        cond.remove(shipCondIdx)
        cond.append("ship_and_boat")
      }
    }

    res.append(_createCondition("unitClass", cond))
  }

  if (blk?.type == "maxUnitsRankOnStartMission") //2 params conditions instead of 1 base
  {
    local minRank = blk?.minRank ?? 0
    local maxRank = blk?.maxRank ?? minRank
    if (minRank)
    {
      local values = [minRank]
      if (maxRank > minRank)
        values.append(maxRank)
      res.append(_createCondition("atLeastOneUnitsRankOnStartMission", values))
    }

    if (blk?.maxRank)
      res.append(_createCondition("maxUnitsRankOnStartMission", maxRank))
  }

  return res
}

UnlockConditions.loadCondition <- function loadCondition(blk, unlockMode)
{
  if (blk?.hidden)
    return null

  local t = blk?.type
  local res = _createCondition(t)

  if (t == "weaponType")
    res.values = (blk % "weapon")
  else if (t == "location")
    res.values = (blk % "location")
  else if (t == "operationMap")
    res.values = (blk % "operationMap")
  else if (t == "activity")
    res.values = getDiffTextArrayByPoint3(blk?.percent, "%s%%")
  else if (t == "online" || t == "worldWar")
  {
    res.type = "modes"
    res.values = t
  }
  else if (t == "gameModeInfoString")
  {
    res.name <- blk?.name
    res.values = (blk % "value")

    if (blk?.locParamName)
      res.locParamName <- blk.locParamName
    if (blk?.locValuePrefix)
      res.locValuePrefix <- blk.locValuePrefix
  }
  else if (t == "eventMode")
  {
    res.values = (blk % "event_name")
    if (res.values.len())
      res.type = "events"
    else
    {
      res.type = "modes"
      local group = "events_only"
      if (blk?.for_clans_only == true)
        group = "clans_only"
      else if (blk?.is_event == false) //true by default
        group = "random_battles"
      res.values.append(group)
    }
  }
  else if (t == "playerUnit" || t == "targetUnit")
    res.values = (blk % "class")
  else if (t == "playerType" || t == "targetType")
  {
    res.values = (blk % "unitType")
    res.values.extend(blk % "unitClass")
  }
  else if (t == "playerExpClass" || t == "targetExpClass")
    res.values = (blk % "class")
  else if (t == "targetUnitClass")
    res.values = (blk % "unitClass")
  else if (t == "playerTag" || t == "targetTag")
    res.values = (blk % "tag")
  else if (t == "playerCountry")
    res.values = (blk % "country")
  else if (t == "playerUnitRank")
  {
    local range = blk?.minRank || blk?.maxRank ? ::Point2(blk?.minRank ?? 0, blk?.maxRank ?? 0) : blk?.range
    local v = getRangeTextByPoint2(range, {
      rangeStr = ::loc("events/rank")
      maxOnlyStr = ::loc("conditions/unitRank/format_max")
      minOnlyStr = ::loc("conditions/unitRank/format_min")
    }, true)
    res.values = v != "" ? v : null
  }
  else if (t == "playerUnitMRank")
  {
    local range = blk?.minMRank || blk?.maxMRank
      ? ::Point2(blk?.minMRank ?? 0, blk?.maxMRank ?? 0)
      : blk?.range ?? ::Point2(0,0)
    range = ::Point2(
      range.x.tointeger() > 0 ? ::calc_battle_rating_from_rank(range.x) : 0,
      range.y.tointeger() > 0 ? ::calc_battle_rating_from_rank(range.y) : 0
    )
    local v = getRangeTextByPoint2(range, {
      rangeStr = ::loc("events/br")
      maxOnlyStr = ::loc("conditions/unitRank/format_max")
      minOnlyStr = ::loc("conditions/unitRank/format_min")
    })
    res.values = v != "" ? v : null
  }
  else if (t == "playerUnitClass")
  {
    local unitClassList = (blk % "unitClass")
    foreach (i, v in unitClassList)
      if (v.len() > 4 && v.slice(0,4) == "exp_")
        unitClassList[i] = "type_" + v.slice(4)

    res.values = unitClassList
  }
  else if (t == "playerUnitFilter")
  {
    switch (blk?.paramName)
    {
      case "country":
        res.values = blk % "value"
        break
      default:
        return null
    }
  }
  else if (t == "char_mission_completed")
    res.values = blk?.name ?? ""
  else if (t == "difficulty")
  {
    res.values = blk % "difficulty"
    res.exact <- blk?.exact ?? false
  }
  else if (t == "minStat")
  {
    local stat = blk?.stat ?? ""

    local lessIsBetter = stat == "place"
    res.values = getDiffTextArrayByPoint3(blk?.value, "%s", lessIsBetter)
    if (!res.values.len())
      return null

    res.locGroup <- ::getTblValue(stat, minStatGroups, stat)

    if (blk?.inSession == true)
      res.locGroup +=  "InSession"
  }
  else if (::isInArray(t, unlock_time_range_conditions))
  {
    foreach(key in ["beginDate", "endDate"])
    {
      local unlockTime = blk?[key] ?
        (time.getTimestampFromStringUtc(blk[key])) : -1
      if (unlockTime >= 0)
        res[key] <- time.buildDateTimeStr(unlockTime)
    }
  }
  else if (t == "missionPostfix")
  {
    res.values = []
    local values = blk % "postfix"
    foreach(val in values)
      ::u.appendOnce(regExpNumericEnding.replace("", val), res.values)
    res.locGroup <- ::getTblValue("allowed", blk, true) ? "missionPostfixAllowed" : "missionPostfixProhibited"
  }
  else if (t == "mission")
    res.values = (blk % "mission")
  else if (t == "tournamentMode")
    res.values = (blk % "mode")
  else if (t == "missionType")
  {
    res.values = []
    local values = blk % "missionType"
    foreach(modeInt in values)
      res.values.append(::get_mode_localization_text(modeInt))
  }
  else if (t == "char_personal_unlock")
    res.values = blk % "personalUnlocksType"
  else if (t == "offenderIsSupportGun")
    res.values = ["actionBarItem/artillery_target"]
  else if (t == "targetIsPlayer")
  {
    res.values = []
    foreach(key in ["includePlayers", "includeBots", "includeAI"])
      if (blk?[key])
        res.values.append(key)

    if (blk?.includePlayers == null)
      res.values.append("includePlayers")

    if (res.values.len() > 1 || (res.values.len() == 1 && res.values[0] != "includePlayers"))
      res.locGroup <- "targets"
    else
      res.values = null
  }
  else if (t == "targetDistance")
  {
    res.values = getDiffTextArrayByPoint3(blk?.distance ?? -1, "%s" + ::loc("measureUnits/meters_alt"))
    res.gt <- blk?.gt ?? true
  }
  else if (::isInArray(t, additionalTypes))
  {
    res.type = "additional"
    res.values = t
  }

  local overrideCondType = getOverrideCondType(blk, unlockMode)
  if (overrideCondType)
    res.type = overrideCondType

  if (res.type in locGroupByType)
    res.locGroup <- locGroupByType[res.type]
  return res
}

UnlockConditions.getDiffTextArrayByPoint3 <- function getDiffTextArrayByPoint3(val, formatStr = "%s", lessIsBetter = false)
{
  local res = []

  if (type(val) != "instance" || !(val instanceof ::Point3))
  {
    res.append(_getDiffValueText(val, formatStr, lessIsBetter))
    return res
  }

  if (val.x == val.y && val.x == val.z)
    res.append(_getDiffValueText(val.x, formatStr, lessIsBetter))
  else
    foreach (idx, key in [ "x", "y", "z" ])
    {
      local value = val[key]
      local valueStr = _getDiffValueText(value, formatStr, lessIsBetter)
      res.append(valueStr + ::loc("ui/parentheses/space", {
                                    text = ::loc(::getTblValue("abbreviation", ::g_difficulty.getDifficultyByDiffCode(idx), ""))
                                  }))
    }

  return res
}

UnlockConditions._getDiffValueText <- function _getDiffValueText(value, formatStr = "%s", lessIsBetter = false)
{
  return lessIsBetter? getRangeString(1, value, formatStr) : ::format(formatStr, value.tostring())
}

UnlockConditions.getMainProgressCondition <- function getMainProgressCondition(conditions)
{
  foreach(c in conditions)
    if (::getTblValue("modeType", c))
      return c
  return null
}

UnlockConditions.getConditionsText <- function getConditionsText(conditions, curValue = null, maxValue = null, params = null)
{
  local inlineText = ::getTblValue("inlineText", params, false)
  local separator = inlineText ? ", " : "\n"

  //add main conditions
  local mainConditionText = ""
  if (::getTblValue("withMainCondition", params, true))
    mainConditionText = getMainConditionText(conditions, curValue, maxValue, params)

  //local add not main conditions
  local descByLocGroups = {}
  local customDataByLocGroups = {}
  foreach(condition in conditions)
    if (!::isInArray(condition.type, customLocTypes))
    {
      if (!_addUniqConditionsText(descByLocGroups, condition))
        _addUsualConditionsText(descByLocGroups, condition)
    }
    else
    {
      _addCustomConditionsTextData(customDataByLocGroups, condition)
    }

  local condTextsList = []
  foreach(group in conditionsOrder)
  {
    local data = null

    if (!::isInArray(group, customLocTypes))
    {
      data = ::getTblValue(group, descByLocGroups)
      if (data == null || data.len() == 0)
        continue

      addTextToCondTextList(condTextsList, group, data)
    }
    else
    {
      local customData = ::getTblValue(group, customDataByLocGroups)
      if (customData == null || customData.len() == 0)
        continue

      foreach (condCustomData in customData)
        foreach (descText in condCustomData.descText)
          addTextToCondTextList(condTextsList, group, descText, condCustomData.groupText)
    }
  }

  local conditionsText = ::g_string.implode(condTextsList, separator)
  if (inlineText && conditionsText != "")
    conditionsText = ::format("(%s)", conditionsText)

  //add multipliers text
  local mainCond = getMainProgressCondition(conditions)
  local mulText = ::UnlockConditions.getMultipliersText(mainCond || {})

  local pieces = [mainConditionText, conditionsText, mulText]
  return ::g_string.implode(pieces, separator)
}

UnlockConditions.addTextToCondTextList <- function addTextToCondTextList(condTextsList, group, valuesData, customLocGroupText = "")
{
  local valuesText = ""
  local text = ""

  valuesText = ::g_string.implode(valuesData, ::loc("ui/comma"))
  if (valuesText != "")
    valuesText = ::colorize("unlockActiveColor", valuesText)

  text = !::isInArray(group, customLocTypes) ? ::loc("conditions/" + group, { value = valuesText }) : customLocGroupText
  if (!::isInArray(group, condWithValuesInside))
    if (valuesText != "")
      text += (text.len() ? ::loc("ui/colon") : "") + valuesText
    else
      text = ""

  condTextsList.append(text)
}

UnlockConditions.getMainConditionText <- function getMainConditionText(conditions, curValue = null, maxValue = null, params = null)
{
  local mainCond = getMainProgressCondition(conditions)
  return _genMainConditionText(mainCond, curValue, maxValue, params)
}

UnlockConditions._genMainConditionText <- function _genMainConditionText(condition, curValue = null, maxValue = null, params = null)
{
  local res = ""
  local modeType = ::getTblValue("modeType", condition)
  if (!modeType)
    return res

  local typeLocIDWithoutValue = ::getTblValue("typeLocIDWithoutValue", condition)
  if (typeLocIDWithoutValue)
    return ::loc(typeLocIDWithoutValue)

  local bitMode = isBitModeType(modeType)

  if (maxValue == null)
    maxValue = ::getTblValue("rewardNum", condition) || ::getTblValue("num", condition)
  if (::is_numeric(curValue))
  {
    if (bitMode)
      curValue = stdMath.number_of_set_bits(curValue)
    else if (::is_numeric(maxValue) && curValue > maxValue) //validate values if numeric
      curValue = maxValue
  }
  if (bitMode && ::is_numeric(maxValue))
    maxValue = stdMath.number_of_set_bits(maxValue)

  if (isCheckedBySingleAttachment(modeType) && condition.values && condition.values.len() == 1)
    return _getSingleAttachmentConditionText(condition, curValue, maxValue)

  local textId = "conditions/" + modeType
  local textParams = {}

  local progressText = ""
  local showValueForBitList = params?.showValueForBitList
  if (bitMode && (params?.bitListInValue || showValueForBitList))
  {
    if (curValue == null || params?.showValueForBitList)
      progressText = ::g_string.implode(getLocForBitValues(modeType, condition.values), ", ")
    if (::is_numeric(maxValue) && maxValue != condition.values.len())
    {
      textId += "/withValue"
      textParams.value <- ::colorize("unlockActiveColor", maxValue)
    }
  } else if (modeType == "maxUnitsRankOnStartMission")
  {
    local valuesText = ::u.map(condition.values, ::get_roman_numeral)
    progressText = ::g_string.implode(valuesText, "-")
  } else if (modeType == "amountDamagesZone")
  {
    if (::is_numeric(curValue) && ::is_numeric(maxValue))
      progressText = stdMath.round_by_value(curValue * 0.001, 0.001) + "/" + stdMath.round_by_value(maxValue * 0.001,  0.001)
  } else //usual progress text
  {
    progressText = (curValue != null) ? curValue : ""
    if (maxValue != null && maxValue != "")
      progressText += ((progressText != "") ? "/" : "") + maxValue
  }

  if ("modeTypeLocID" in condition)
    textId = condition.modeTypeLocID
  else if (modeType == "rank" || modeType == "char_country_rank")
  {
    local country = ::getTblValue("country", condition)
    textId = country ? "mainmenu/rank/" + country : "mainmenu/rank"
  }
  else if (modeType == "unlockCount")
    textId = "conditions/" + ::getTblValue("unlockType", condition, "")
  else if (modeType == "char_static_progress")
    textParams.level <- ::loc("crew/qualification/" + ::getTblValue("level", condition, 0))
  else if (modeType == "landings" && ::getTblValue("carrierOnly", condition))
    textId = "conditions/carrierOnly"
  else if (::getTblValue("isShip", condition)) //really strange exclude, becoase of this flag used with various modeTypes.
    textId = "conditions/isShip"
  else if (modeType == "killedAirScore")
    textId = "conditions/statKillsAir"
  else if (modeType == "sessionsStarted")
    textId = "conditions/missionsPlayed"
  else if (modeType == "char_resources_count")
    textId = "conditions/char_resources_count/" + ::getTblValue("resourceType", condition, "")
  else if (modeType == "amountDamagesZone")
    textId = "debriefing/Damage"

  if ("locEnding" in params)
    res = ::loc(textId + params.locEnding, textParams)
  if (res == "")
    res = ::loc(textId, textParams)

  if ("reason" in condition)
    res += " " + ::loc(textId + "/" + condition.reason)

  //if condition lang is empty and max value == 1 no need to show progress text
  if (progressText != "" && (res != "" || maxValue != 1))
    res += ::loc("ui/colon") + ::colorize("unlockActiveColor", progressText)
  return res
}

UnlockConditions.getMainConditionListPrefix <- function getMainConditionListPrefix(conditions)
{
  local mainCondition = getMainProgressCondition(conditions)
  if (mainCondition == null)
    return ""
  if (!mainCondition.values)
    return ""

  local modeType = mainCondition.modeType

  if (mainCondition.hasCustomUnlockableList || (::isInArray(modeType, ["unlockOpenCount", "unlocks"]) && mainCondition.values.len() > 1))
  {
    return ::loc("ui/awards") + ::loc("ui/colon")
  }

  return ""
}

UnlockConditions._getSingleAttachmentConditionText <- function _getSingleAttachmentConditionText(condition, curValue, maxValue)
{
  local modeType = ::getTblValue("modeType", condition)
  local locNames = getLocForBitValues(modeType, condition.values)
  local valueText = ::colorize("unlockActiveColor", "\"" +  ::g_string.implode(locNames, ::loc("ui/comma")) + "\"")
  local progress = ::colorize("unlockActiveColor", (curValue != null? (curValue + "/") : "") + maxValue)
  return ::loc("conditions/" + modeType + "/single", { value = valueText, progress = progress})
}

UnlockConditions._addUniqConditionsText <- function _addUniqConditionsText(groupsList, condition)
{
  local cType = condition.type
  if (::isInArray(cType, unlock_time_range_conditions)) //2 loc groups by one condition
  {
    foreach(key in ["beginDate", "endDate"])
      if (key in condition)
        _addValueToGroup(groupsList, key, condition[key])
    return true
  }
  else if (cType == "atLeastOneUnitsRankOnStartMission")
  {
    local valuesTexts = ::u.map(condition.values, ::get_roman_numeral)
    _addValueToGroup(groupsList, cType, ::g_string.implode(valuesTexts, "-"))
    return true
  }
  else if (cType == "eliteUnitsOnly")
  {
    _addValueToGroup(groupsList, cType, "")
    return true
  }
  return false //not found, do as usual conditions.
}

UnlockConditions._addUsualConditionsText <- function _addUsualConditionsText(groupsList, condition)
{
  local cType = condition.type
  local group = ::getTblValue("locGroup", condition, cType)
  local values = condition.values
  local text = ""

  if (values == null)
    return _addValueToGroup(groupsList, group, text)

  if (typeof values != "array")
    values = [values]

  values = processUnitTypeArray(values)

  foreach (v in values)
  {
    if (cType == "playerUnit" || cType=="targetUnit" || cType == "crewsUnit" || cType=="unitExists" ||
        cType == "usedInSessionUnit" || cType == "lastInSessionUnit")
      text = ::getUnitName(v)
    else if (cType == "playerType" || cType == "targetType" || cType == "usedInSessionType" || cType == "lastInSessionType")
      text = ::loc("unlockTag/" + ::getTblValue(v, mapConditionUnitType, v))
    else if (cType == "playerExpClass" || cType == "targetExpClass" || cType == "unitClass" || cType == "targetUnitClass" ||
             cType == "usedInSessionClass" || cType == "lastInSessionClass")
      text = getRoleText(::g_string.cutPrefix(v, "exp_", v))
    else if (cType == "playerTag" || cType == "crewsTag" || cType == "targetTag" || cType == "country" ||
             cType == "playerCountry" || cType == "usedInSessionTag" || cType == "lastInSessionTag")
      text = ::loc("unlockTag/" + v)
    else if (::isInArray(cType, [ "activity", "playerUnitRank", "playerUnitMRank",
      "crewsUnitRank", "crewsUnitMRank", "minStat", "targetDistance"]))
      text = condition?.gt != null
        ? ::format( ::loc("conditions/" + (condition.gt ? "min" : "max") + "_limit"), v.tostring())
        : v.tostring()
    else if (cType == "difficulty")
    {
      text = ::getDifficultyLocalizationText(v)
      if (!::getTblValue("exact", condition, false) && v != "hardcore")
        text += " " + ::loc("conditions/moreComplex")
    }
    else if (cType == "mission" || cType == "char_mission_completed" || cType == "missionType")
      text = ::loc("missions/" + v)
    else if (::isInArray(cType, ["era", "maxUnitsRankOnStartMission"]))
      text = ::get_roman_numeral(v)
    else if (cType == "events")
      text = ::events.getNameByEconomicName(v)
    else if (cType == "missionPostfix")
      text = ::loc("options/" + v)
    else if (cType == "offenderIsSupportGun")
      text = ::loc(v)
    else if (cType == "operationMap")
      text = ::loc("worldWar/map/" + v)
    else
      text = ::loc(cType+"/" + v)

    _addValueToGroup(groupsList, group, text)
  }
}

UnlockConditions._addCustomConditionsTextData <- function _addCustomConditionsTextData(groupsList, condition)
{
  local cType = condition.type
  local group = ""
  local desc = []

  local res = {
    groupText = ""
    descText = []
  }

  local values = condition.values

  if (values == null)
    return

  if (typeof values != "array")
    values = [values]

  foreach (v in values) {
    if (cType == "gameModeInfoString") {
      group = condition?.locParamName ? ::loc(condition.locParamName)
                                      : ::loc($"conditions/gameModeInfoString/{condition.name}")

      local locValuePrefix = condition?.locValuePrefix ?? "conditions/gameModeInfoString/"
      desc.append(::loc($"{locValuePrefix}{v}"))
    }
  }

  res.groupText <- group
  res.descText.append(desc)

  _addDataToCustomGroup(groupsList, cType, res)
}

UnlockConditions._addDataToCustomGroup <- function _addDataToCustomGroup(groupsList, cType, data)
{
  if (!(cType in groupsList))
    groupsList[cType] <- []

  local customData = groupsList[cType]
  foreach (conditionData in customData)
  {
    if (data.groupText == ::getTblValue("groupText", conditionData))
    {
      conditionData.descText.append(::getTblValue("descText", data)[0])
      return
    }
  }

  groupsList[cType].append(data)
}

UnlockConditions._addValueToGroup <- function _addValueToGroup(groupsList, group, value)
{
  if (!(group in groupsList))
    groupsList[group] <- []
  groupsList[group].append(value)
}

UnlockConditions.addToText <- function addToText(text, name, valueText = "", color = "unlockActiveColor", separator = "\n")
{
  text += (text.len() ? separator : "") + name
  if (valueText != "")
    text += (name.len() ? ::loc("ui/colon") : "") + "<color=@" + color + ">" + valueText + "</color>"
  return text
}

UnlockConditions.getMultipliersTable <- function getMultipliersTable(blk)
{
  local modeTable = {
    mulArcade = "ArcadeBattle"
    mulRealistic = "HistoricalBattle"
    mulHardcore = "FullRealBattles"
    mulWWBattleForOwnClan = "WWBattleForOwnClan"
  }

  local mulTable = {}
  foreach(paramName, mode in modeTable)
    mulTable[mode] <- blk?[paramName] ?? 1

  return mulTable
}

UnlockConditions.getMultipliersText <- function getMultipliersText(condition)
{
  local multiplierTable = ::getTblValue("multiplier", condition, {})
  if (multiplierTable.len() == 0)
    return ""

  local mulText = ""

  if (multiplierTable.WWBattleForOwnClan > 1)
    return "{0}{1}{2}".subst(::loc("conditions/mulWWBattleForOwnClan"),
                             ::loc("ui/colon"),
                             ::colorize("unlockActiveColor", ::format("x%d", multiplierTable.WWBattleForOwnClan)))

  foreach(difficulty, num in multiplierTable)
  {
    if (num == 1)
      continue

    mulText += mulText.len() > 0? ", " : ""
    mulText += ::format("%s (x%d)", ::loc("clan/short" + difficulty), num)
  }

  if (mulText == "")
    return ""

  return ::format("<color=@fadedTextColor>%s</color>", ::loc("conditions/multiplier") + ::loc("ui/colon") + mulText)
}

UnlockConditions.getLocForBitValues <- function getLocForBitValues(modeType, values, hasCustomUnlockableList = false)
{
  local valuesLoc = []
  if (hasCustomUnlockableList || modeType == "unlocks" || modeType == "char_unlocks"
    || modeType == "unlockOpenCount" || modeType == "unlockStageCount")
    foreach(name in values)
      valuesLoc.append(::get_unlock_name_text(-1, name))
  else if (modeType == "char_unit_exist")
    foreach(name in values)
      valuesLoc.append(::getUnitName(name))
  else if (modeType == "char_resources")
    foreach(id in values)
    {
      local decorator = ::g_decorator.getDecoratorById(id)
      valuesLoc.append(decorator?.getName?() ?? id)
    }
  else
  {
    local nameLocPrefix = ""
    if (modeType == "char_mission_list" ||
        modeType == "char_mission_completed"
       )
      nameLocPrefix = "missions/"
    else if (modeType == "char_buy_modification_list")
      nameLocPrefix = "modification/"
    foreach(name in values)
      valuesLoc.append(::loc(nameLocPrefix + name))
  }
  return valuesLoc
}

UnlockConditions.getTooltipIdByModeType <- function getTooltipIdByModeType(modeType, id, hasCustomUnlockableList = false)
{
  if (hasCustomUnlockableList || modeType == "unlocks" || modeType == "char_unlocks" || modeType == "unlockOpenCount")
    return ::g_tooltip.getIdUnlock(id)

  if (modeType == "char_unit_exist")
    return ::g_tooltip.getIdUnit(id)

  return id
}

UnlockConditions.getProgressBarData <- function getProgressBarData(modeType, curVal, maxVal)
{
  local res = {
    show = !::isInArray(modeType, modeTypesWithoutProgress)
    value = 0
  }

  if (::UnlockConditions.isBitModeType(modeType))
  {
    curVal = stdMath.number_of_set_bits(curVal)
    maxVal = stdMath.number_of_set_bits(maxVal)
  }

  res.show = res.show && maxVal > 1 && curVal < maxVal
  res.value = ::clamp(1000 * curVal / (maxVal || 1), 0, 1000)
  return res
}

UnlockConditions.getRankValue <- function getRankValue(conditions)
{
  foreach(c in conditions)
    if (c.type == "playerUnitRank")
      return c.values
  return null
}

UnlockConditions.getBRValue <- function getBRValue(conditions)
{
  foreach(c in conditions)
    if (c.type == "playerUnitMRank")
      return c.values
  return null
}
