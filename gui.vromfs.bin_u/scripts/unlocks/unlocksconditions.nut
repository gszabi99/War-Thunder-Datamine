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


let time = require("%scripts/time.nut")
let stdMath = require("%sqstd/math.nut")
let { getRoleText } = require("%scripts/unit/unitInfoTexts.nut")
let { processUnitTypeArray } = require("%scripts/unit/unitClassType.nut")
let { getShopDiffCode } = require("%scripts/shop/shopDifficulty.nut")

let missionModesList = [
  "missionsWon",
  "missionsWonScore",
  "missionsPlayed",
  "missionsPlayedScore",
  "totalMissionScore"
]

let typesForMissionModes = {
  playerUnit = {
    inSessionAnd = "crewsUnitRank",
    inSessionTrue = "usedInSessionUnit",
    inSessionFalse = "lastInSessionUnit"
  },
  playerType = {
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

let function getOverrideCondType(condBlk, unlockMode) {
  local overrideCondType

  if (::isInArray(unlockMode, missionModesList)) {
    let inSession = condBlk?.inSession ?? false
    let curTypes = typesForMissionModes?[condBlk?.type]
    if (inSession)
      if ((condBlk?.inSessionAnd ?? true) && curTypes?.inSessionAnd)
        overrideCondType = curTypes.inSessionAnd
      else
        overrideCondType = curTypes?.inSessionTrue
    else
      overrideCondType = curTypes?.inSessionFalse
  }

  return overrideCondType
}

let function getRankMultipliersTable(blk) {
  let mulTable = {}
  local hasAnyMulRank = false
  if (detailedMultiplierModesList.indexof(blk?.type ?? "") != null) {
    for (local rank = 1; rank <= ::max_country_rank; rank++) {
      let curMul = blk?[$"mulRank{rank}"] ?? 1.0
      mulTable[rank] <- curMul
      if (!hasAnyMulRank && curMul != 1.0)
        hasAnyMulRank = true
    }
  }
  return hasAnyMulRank ? mulTable : {}
}

::UnlockConditions <- {
  conditionsOrder = [
    "beginDate", "endDate",
    "missionsWon", "mission", "char_mission_completed",
    "missionType", "atLeastOneUnitsRankOnStartMission", "maxUnitsRankOnStartMission",
    "unitExists", "additional", "unitClass",
    "gameModeInfoString", "missionPostfix", "modes", "events", "tournamentMode",
    "location", "operationMap", "weaponType", "ammoMass", "bulletCaliber", "difficulty",
    "playerUnit", "playerType", "playerExpClass", "playerUnitRank", "playerUnitMRank", "playerTag", "playerCountry",
    "offenderUnit", "offenderType", "offenderUnitRank", "offenderUnitMRank", "offenderTag",
    "targetUnit", "targetType", "targetTag",
    "crewsUnit", "crewsUnitRank", "crewsUnitMRank", "crewsTag", "usedPlayerUnit", "lastPlayerUnit",
    "activity", "minStat", "statPlaceInSession", "statScoreInSession", "statAwardDamageInSession",
    "statKillsPlayerInSession", "statKillsAirInSession", "statKillsAirAiInSession",
    "statKillsGroundInSession", "statKillsGroundAiInSession",
    "statKillsNavalInSession", "statKillsNavalAiInSession",
    "statKillsSurfaceInSession", "statKillsSurfaceAiInSession",
    "targetIsPlayer", "eliteUnitsOnly", "noPremiumVehicles", "era", "country",
    "targets", "targetDistance", "higherBR"
  ]

  condWithValuesInside = [
    "atLeastOneUnitsRankOnStartMission", "eliteUnitsOnly"
  ]

  additionalTypes = [
    "critical", "lesserTeam", "inTurret", "isBurning", "targetInCaptureZone", "offenderIsPlayerControlled"
  ]

  locGroupByType = {
    offenderUnit           = "playerUnit"
    playerType             = "playerUnit"
    offenderType           = "playerUnit"
    playerTag              = "playerUnit"
    offenderTag            = "playerUnit"
    playerUnitRank         = "playerUnit"
    offenderUnitRank       = "playerUnit"
    playerUnitMRank        = "playerUnit"
    offenderUnitMRank      = "playerUnit"
    playerCountry          = "playerUnit"
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
    bulletModName          = "weaponType"
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
    typeAssault       = "type_strike_aircraft"
    typeStormovik     = "type_strike_aircraft"
    typeTransport     = "type_transport"
    typeStrikeFighter = "type_strike_fighter"
    typeDestroyer     = "type_destroyer"
    typeTorpedoBoat   = "type_torpedo_boat"
  }

  minStatGroups = {
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

  customLocTypes = ["gameModeInfoString", "missionPostfix"]

  formatParamsDefault = {
    rangeStr = "%s"
    itemStr = "%s"
    valueStr = "%.1f"
    maxOnlyStr = "%s"
    minOnlyStr = "%s"
    bothStr = "%s"+ ::loc("ui/mdash") + "%s"
  }

  regExpNumericEnding = ::regexp2("\\d+$")

  nestedUnlockModes = ["unlockOpenCount", "unlockStageCount", "unlocks", "char_unlocks"]

  getRankRangeText = @(range) getRangeTextByPoint2(range, {
      rangeStr = ::loc("events/rank")
      maxOnlyStr = ::loc("conditions/unitRank/format_max")
      minOnlyStr = ::loc("conditions/unitRank/format_min")
    }, true)

  getMRankRangeText = @(range) getRangeTextByPoint2(range, {
      rangeStr = ::loc("events/br")
      maxOnlyStr = ::loc("conditions/unitRank/format_max")
      minOnlyStr = ::loc("conditions/unitRank/format_min")
    }, false)

  function getRangeTextByPoint2(val, formatParams = {}, romanNumerals = false)
  {
    if (!(type(val) == "instance" && (val instanceof ::Point2)) && !(type(val) == "table"))
      return ""

    formatParams = formatParamsDefault.__merge(formatParams)
    let { rangeStr, itemStr, valueStr, maxOnlyStr, minOnlyStr, bothStr } = formatParams
    let a = val.x.tointeger() > 0 ? romanNumerals ? ::get_roman_numeral(val.x) : ::format(valueStr, val.x) : ""
    let b = val.y.tointeger() > 0 ? romanNumerals ? ::get_roman_numeral(val.y) : ::format(valueStr, val.y) : ""
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
    let conditionsArray = (blk % "condition").extend(blk % "visualCondition")
    for (local i = conditionsArray.len() - 1; i >= 0 ; i--)
    {
      let condBlk = conditionsArray[i]
      if (condBlk?.type == "playerCountry")
      {
        if (condBlk.country == (unlockBlk?.country ?? ""))
        {
          let b = blk.getBlock(i)
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
//  needToShowInHeader - show values in header of unlock (used in battletasks and battlepass challenges)
//  locGroup  - group values in one loc string instead of different string for each value.
//
//  specific params for main progresscondition (type == "mode")
//  modeType - mode type of conditions with progress
//             such condition can be only one in list, and always first.
//  modeTypeLocID  - locId for mode type
//}
UnlockConditions.loadConditionsFromBlk <- function loadConditionsFromBlk(blk, unlockBlk = ::DataBlock())
{
  let res = []
  let mainCond = loadMainProgressCondition(blk) //main condition by modeType
  if (mainCond)
    res.append(mainCond)

  res.extend(loadParamsConditions(blk)) //conditions by mode params - elite, country etc

  hideConditionsFromBlk(blk, unlockBlk) //don't show conditions by rule

  let unlockMode = unlockBlk?.mode.type

  //conditions determined by blocks "condition"; "visualCondition" is similar one, but for use in UI only
  let conditionsArray = (blk % "condition").extend(blk % "visualCondition")
  foreach(condBlk in conditionsArray)
  {
    let condition = loadCondition(condBlk, unlockMode)
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
    needToShowInHeader = false
  }
}

UnlockConditions._mergeConditionToList <- function _mergeConditionToList(newCond, list)
{
  let cType = newCond.type
  let cond = _findCondition(list, cType, ::getTblValue("locGroup", newCond, null))
  if (!cond)
    return list.append(newCond) // warning disable: -unwanted-modification

  if (!newCond.values)
    return

  if (!cond.values)
    cond.values = newCond.values
  else
  {
    if (typeof(cond.values) != "array")
      cond.values = [cond.values]
    cond.values.extend((typeof(newCond.values) == "array") ? newCond.values : [newCond.values])
  }

  //merge specific by type
  if (cType == "modes")
  {
    let idx = ::find_in_array(cond.values, "online") //remove mode online if there is ther modes (clan, event, etc)
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
  let modeType = blk?.type
  if (!modeType || ::isInArray(modeType, modeTypesWithoutProgress)
      || blk?.dontShowProgress || modeType == "maxUnitsRankOnStartMission")
    return null

  let res = _createCondition("mode")
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
    let isUnlockStageCount = modeType == "unlockStageCount"
    if (!res.hasCustomUnlockableList)
      foreach (unlockId in (blk % "unlock")) {
        let unlock = ::g_unlocks.getUnlockById(unlockId)
        if (unlock == null) {
          let debugUnlockData = blk?.unlock ?? ::toString(blk) // warning disable: -declared-never-used
          ::dagor.assertf(false, "ERROR: Unlock does not exist")
          continue
        }
        if (isUnlockStageCount) {
          res.values.append(unlock.id)
          continue
        }

        let values = ("mode" in unlock) ? unlock.mode % "unlock" : []
        if(values.len() == 0)
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

UnlockConditions.loadParamsConditions <- function loadParamsConditions(blk)
{
  let res = []
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
    let cond = blk % "unitClass"
    if (blk?.type == "char_crew_level_float" || blk?.type == "char_crew_level_count_float") {
      let shipCondIdx = cond.indexof("ship")
      if (shipCondIdx != null) {
        cond.remove(shipCondIdx)
        cond.append("ship_and_boat")
      }
    }

    res.append(_createCondition("unitClass", cond))
  }

  if (blk?.type == "maxUnitsRankOnStartMission") //2 params conditions instead of 1 base
  {
    let minRank = blk?.minRank ?? 0
    let maxRank = blk?.maxRank ?? minRank
    if (minRank)
    {
      let values = [minRank]
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

  let t = blk?.type
  let res = _createCondition(t)

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
  else if (t == "playerUnit" || t == "offenderUnit" || t == "targetUnit")
    res.values = (blk % "class")
  else if (t == "playerType" || t == "targetType" || t == "offenderType")
  {
    res.values = (blk % "unitType")
    res.values.extend(blk % "unitClass")
  }
  else if (t == "playerExpClass")
    res.values = (blk % "class")
  else if (t == "playerTag" || t == "offenderTag" || t == "targetTag")
    res.values = (blk % "tag")
  else if (t == "playerCountry")
    res.values = (blk % "country")
  else if (t == "playerUnitRank" || t == "offenderUnitRank")
  {
    let range = ::Point2(blk?.minRank ?? 0, blk?.maxRank ?? 0)
    let rangeForEvent = ::Point2(blk?.minRankForEvent ?? range.x, blk?.maxRankForEvent ?? range.y)
    local v = getRankRangeText(range)
    if (!::u.isEqual(range, rangeForEvent)) {
      let valForEvent = getRankRangeText(rangeForEvent)
      v = "".concat(v, ::loc("ui/parentheses/space", { text = ::loc("conditions/forEventUnit", { condition = valForEvent }) }))
    }
    res.values = v != "" ? v : null
    res.needToShowInHeader = true
  }
  else if (t == "playerUnitMRank" || t == "offenderUnitMRank")
  {
    local range = ::Point2(blk?.minMRank ?? 0, blk?.maxMRank ?? 0)
    local rangeForEvent = ::Point2(blk?.minMRankForEvent ?? range.x, blk?.maxMRankForEvent ?? range.y)
    let hasForEventCond = !::u.isEqual(range, rangeForEvent)
    range = ::Point2(
      ::calc_battle_rating_from_rank(range.x),
      range.y.tointeger() > 0 ? ::calc_battle_rating_from_rank(range.y) : 0
    )
    local v = getMRankRangeText(range)
    if (hasForEventCond) {
      rangeForEvent = ::Point2(
        ::calc_battle_rating_from_rank(rangeForEvent.x),
        rangeForEvent.y.tointeger() > 0 ? ::calc_battle_rating_from_rank(rangeForEvent.y) : 0
      )
      let valForEvent = getMRankRangeText(rangeForEvent)
      v = "".concat(v, ::loc("ui/parentheses/space", { text = ::loc("conditions/forEventUnit", { condition = valForEvent }) }))
    }
    res.values = v != "" ? v : null
    res.needToShowInHeader = true
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
    let stat = blk?.stat ?? ""

    let lessIsBetter = stat == "place"
    res.values = getDiffTextArrayByPoint3(blk?.value, "%s", lessIsBetter)
    if (!res.values.len())
      return null

    res.locGroup <- $"{(minStatGroups?[stat] ?? "")}InSession"
  }
  else if (::isInArray(t, unlock_time_range_conditions))
  {
    foreach(key in ["beginDate", "endDate"])
    {
      let unlockTime = blk?[key] ?
        (time.getTimestampFromStringUtc(blk[key])) : -1
      if (unlockTime >= 0)
      {
        res[key] <- time.buildDateTimeStr(unlockTime)
        if (key == "endDate")
          res.endTime <- unlockTime
      }
    }
  }
  else if (t == "missionPostfix")
  {
    res.values = []
    let values = blk % "postfix"
    foreach(val in values)
      ::u.appendOnce(regExpNumericEnding.replace("", val), res.values)
    res.locGroup <- ::getTblValue("allowed", blk, true) ? "missionPostfixAllowed" : "missionPostfixProhibited"
    if (blk?.locValuePrefix)
      res.locValuePrefix <- blk.locValuePrefix
  }
  else if (t == "mission")
    res.values = (blk % "mission")
  else if (t == "tournamentMode")
    res.values = (blk % "mode")
  else if (t == "missionType")
  {
    res.values = []
    let values = blk % "missionType"
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
  else if (t == "higherBR")
  {
    let range = ::Point2(blk?.diffBR ?? 0, blk?.diffBRMax ?? 0)
    let v = getRangeTextByPoint2(range, {
      maxOnlyStr = ::loc("conditions/unitRank/format_max")
      minOnlyStr = ::loc("conditions/unitRank/format_min")
    })
    res.values = v != "" ? v : null
  }
  else if (t == "ammoMass") {
    res.values = format("%d %s", (blk?.mass ?? 1), ::loc("measureUnits/kg"))
    res.notLess <- blk?.notLess ?? true
  }
  else if (t == "bulletCaliber") {
    res.values = format("%d %s", (blk?.caliber ?? 1) * 1000, ::loc("measureUnits/mm"))
    res.notLess <- blk?.notLess ?? true
  }
  else if (t == "bulletModName")
    res.values = (blk % "name")
  else if (t == "inCapturedZone") {
    res.type = "additional"
    let zoneType = (blk?.any ?? false) ? "any"
      : (blk?.enemy ?? false) ? "enemy" : "allied"
    res.values = $"{t}/{zoneType}Zone"
  }

  let overrideCondType = getOverrideCondType(blk, unlockMode)
  if (overrideCondType)
    res.type = overrideCondType

  if (res.type in locGroupByType)
    res.locGroup <- locGroupByType[res.type]
  return res
}

UnlockConditions.getDiffTextArrayByPoint3 <- function getDiffTextArrayByPoint3(val, formatStr = "%s", lessIsBetter = false)
{
  let res = []

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
      let value = val[key]
      let valueStr = _getDiffValueText(value, formatStr, lessIsBetter)
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
  let inlineText = ::getTblValue("inlineText", params, false)
  let separator = inlineText ? ", " : "\n"

  //add main conditions
  local mainConditionText = ""
  if (::getTblValue("withMainCondition", params, true))
    mainConditionText = getMainConditionText(conditions, curValue, maxValue, params)

  //local add not main conditions
  let descByLocGroups = {}
  let customDataByLocGroups = {}
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

  let condTextsList = []
  foreach(group in conditionsOrder)
  {
    local data = null

    if (!::isInArray(group, customLocTypes))
    {
      data = ::getTblValue(group, descByLocGroups)
      if (data == null || data.len() == 0)
        continue

      addTextToCondTextList(condTextsList, group, data, params)
    }
    else
    {
      let customData = ::getTblValue(group, customDataByLocGroups)
      if (customData == null || customData.len() == 0)
        continue

      foreach (condCustomData in customData)
        foreach (descText in condCustomData.descText)
          addTextToCondTextList(condTextsList, group, descText, { customLocGroupText = condCustomData.groupText })
    }
  }

  local conditionsText = ::g_string.implode(condTextsList, separator)
  if (inlineText && conditionsText != "")
    conditionsText = ::format("(%s)", conditionsText)

  let pieces = [mainConditionText, conditionsText]

  if (params?.showMult ?? true) {
    //add multipliers text
    let mainCond = getMainProgressCondition(conditions)
    let mulText = ::UnlockConditions.getMultipliersText(mainCond ?? {})
    pieces.append(mulText)
  }

  return ::g_string.implode(pieces, separator)
}

UnlockConditions.addTextToCondTextList <- function addTextToCondTextList(condTextsList, group, valuesData, params = null)
{
  local valuesText = ""
  local text = ""
  let isExpired = group == "endDate" && params?.isExpired

  valuesText = ::g_string.implode(valuesData, ::loc("ui/comma"))
  if (valuesText != "")
    valuesText = ::colorize(isExpired ? "red" : "unlockActiveColor", valuesText)

  text = !::isInArray(group, customLocTypes)
    ? ::loc("conditions/" + group, { value = valuesText })
    : params?.customLocGroupText ?? ""

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
  let modeType = condition?.modeType
  if (!modeType)
    return res

  let typeLocIDWithoutValue = ::getTblValue("typeLocIDWithoutValue", condition)
  if (typeLocIDWithoutValue)
    return ::loc(typeLocIDWithoutValue)

  let bitMode = isBitModeType(modeType)
  let haveModeTypeLocID = "modeTypeLocID" in condition

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

  if (isCheckedBySingleAttachment(modeType) && !haveModeTypeLocID
    && condition.values && condition.values.len() == 1)
      return _getSingleAttachmentConditionText(condition, curValue, maxValue)

  local textId = "conditions/" + modeType
  let textParams = {}

  local progressText = ""
  let showValueForBitList = params?.showValueForBitList
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
    let valuesText = ::u.map(condition.values, ::get_roman_numeral)
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

  if(params?.isProgressTextOnly)
    return progressText

  if (haveModeTypeLocID)
    textId = condition.modeTypeLocID
  else if (modeType == "rank" || modeType == "char_country_rank")
  {
    let country = ::getTblValue("country", condition)
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
  else if (modeType == "totalMissionScore")
    textId = "conditions/statScore"

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
  let mainCondition = getMainProgressCondition(conditions)
  if (mainCondition == null)
    return ""
  if (!mainCondition.values)
    return ""

  let modeType = mainCondition.modeType

  if (mainCondition.hasCustomUnlockableList ||
      (::isInArray(modeType, nestedUnlockModes) && mainCondition.values.len() > 1))
    return ::loc("ui/awards") + ::loc("ui/colon")

  return ""
}

UnlockConditions._getSingleAttachmentConditionText <- function _getSingleAttachmentConditionText(condition, curValue, maxValue)
{
  let modeType = ::getTblValue("modeType", condition)
  let locNames = getLocForBitValues(modeType, condition.values)
  let valueText = ::colorize("unlockActiveColor", "\"" +  ::g_string.implode(locNames, ::loc("ui/comma")) + "\"")
  let progress = ::colorize("unlockActiveColor", (curValue != null? (curValue + "/") : "") + maxValue)
  return ::loc("conditions/" + modeType + "/single", { value = valueText, progress = progress})
}

UnlockConditions._addUniqConditionsText <- function _addUniqConditionsText(groupsList, condition)
{
  let cType = condition.type
  if (::isInArray(cType, unlock_time_range_conditions)) //2 loc groups by one condition
  {
    foreach(key in ["beginDate", "endDate"])
      if (key in condition)
        _addValueToGroup(groupsList, key, condition[key])
    return true
  }
  else if (cType == "atLeastOneUnitsRankOnStartMission")
  {
    let valuesTexts = ::u.map(condition.values, ::get_roman_numeral)
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
  let cType = condition.type
  let group = ::getTblValue("locGroup", condition, cType)
  local values = condition.values
  local text = ""

  if (values == null)
    return _addValueToGroup(groupsList, group, text)

  if (typeof values != "array")
    values = [values]

  values = processUnitTypeArray(values)

  foreach (v in values)
  {
    if (cType == "playerUnit" || cType == "offenderUnit" || cType == "targetUnit" || cType == "crewsUnit" || cType == "unitExists" ||
        cType == "usedInSessionUnit" || cType == "lastInSessionUnit")
      text = ::getUnitName(v)
    else if (cType == "playerType" || cType == "targetType" || cType == "usedInSessionType" || cType == "lastInSessionType" ||
             cType == "offenderType")
      text = ::loc("unlockTag/" + ::getTblValue(v, mapConditionUnitType, v))
    else if (cType == "playerExpClass" || cType == "unitClass" ||
             cType == "usedInSessionClass" || cType == "lastInSessionClass")
      text = getRoleText(::g_string.cutPrefix(v, "exp_", v))
    else if (cType == "playerTag" || cType == "offenderTag" || cType == "crewsTag" || cType == "targetTag" ||
             cType == "country" || cType == "playerCountry" || cType == "usedInSessionTag" || cType == "lastInSessionTag")
      text = ::loc("unlockTag/" + v)
    else if (cType == "targetDistance")
      text = ::format( ::loc($"conditions/{(condition.gt ? "min" : "max")}_limit"), v.tostring())
    else if (::isInArray(cType, [ "ammoMass", "bulletCaliber" ]))
      text = ::format( ::loc(condition.notLess ? "conditions/min_limit" : "conditions/less"), v.tostring())
    else if (::isInArray(cType, [ "activity", "playerUnitRank", "offenderUnitRank", "playerUnitMRank", "offenderUnitMRank",
      "crewsUnitRank", "crewsUnitMRank", "minStat", "higherBR" ])) {
      text = v.tostring()
    }
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
  let cType = condition.type
  local group = ""
  let desc = []

  let res = {
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

      let locValuePrefix = condition?.locValuePrefix ?? "conditions/gameModeInfoString/"
      desc.append(::loc($"{locValuePrefix}{v}"))
    }
    else if (cType == "missionPostfix" ) {
      group = ::loc($"conditions/{condition.locGroup}")

      let locValuePrefix = condition?.locValuePrefix ?? "options/"
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

  let customData = groupsList[cType]
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
  let diffTable = {
    mulArcade = "ArcadeBattle"
    mulRealistic = "HistoricalBattle"
    mulHardcore = "FullRealBattles"
    mulWWBattleForOwnClan = "WWBattleForOwnClan"
  }

  let mulTable = {}
  if (detailedMultiplierModesList.indexof(blk?.type ?? "") != null) {
    let NUM_MISSION_TYPES = 9
    for (local i = 0; i < NUM_MISSION_TYPES; i++)
      mulTable[i] <- blk?[$"mulMode{i}"] ?? 1.0
  }
  else {
    foreach(paramName, diff in diffTable)
      mulTable[diff] <- blk?[paramName] ?? 1
  }

  return mulTable
}

UnlockConditions.getMultipliersText <- function getMultipliersText(condition)
{
  let multiplierTable = condition?.multiplier ?? {}
  let rankMultiplierTable = condition?.rankMultiplier ?? {}
  if (multiplierTable.len() == 0 && rankMultiplierTable.len() == 0)
    return ""

  local mulText = ""

  if ((multiplierTable?.WWBattleForOwnClan ?? 1) > 1)
    return "{0}{1}{2}".subst(::loc("conditions/mulWWBattleForOwnClan"),
                             ::loc("ui/colon"),
                             ::colorize("unlockActiveColor", ::format("x%d", multiplierTable.WWBattleForOwnClan)))

  let isMultipliersByDiff = multiplierTable?.ArcadeBattle != null
  foreach (param, num in multiplierTable) {
    if (num == 1)
      continue

    if (!isMultipliersByDiff && ((param - getShopDiffCode()) % 3 != 0))
      continue

    mulText += mulText.len() > 0 ? ", " : ""
    let mulLocParam = isMultipliersByDiff
      ? ::loc($"clan/short{param}")
      : ::loc($"missions/{::get_mode_localization_text(param)}_short")
    mulText += $"{mulLocParam} (x{num})"
  }

  local mulRankText = ""
  if (rankMultiplierTable.len() > 0) {
    local lastAddedRank = 1
    for (local rank = 1; rank <= ::max_country_rank; rank++) {
      let curRankMul = rankMultiplierTable[rank]
      let nextRankMul = rankMultiplierTable?[rank + 1]
      if (nextRankMul != null && curRankMul == nextRankMul)
        continue
      let rankText = (rank == lastAddedRank + 1) ? ::get_roman_numeral(rank)
        : getRangeString(::get_roman_numeral(lastAddedRank), ::get_roman_numeral(rank))
      if (mulRankText.len() > 0)
        mulRankText = $"{mulRankText}, "
      mulRankText = $"{mulRankText}{rankText} (x{curRankMul})"
      lastAddedRank = rank
    }
  }

  mulText = mulText.len() > 0 ? "{0}{1}{2}".subst(::loc("conditions/multiplier"), ::loc("ui/colon"), mulText) : ""
  if (mulText.len() > 0 && mulRankText.len() > 0)
    mulText = $"{mulText}\n"
  mulRankText = mulRankText.len() > 0 ? "{0}{1}{2}".subst(::loc("conditions/rankMultiplier"), ::loc("ui/colon"), mulRankText) : ""

  return ::colorize("fadedTextColor", "{0}{1}".subst(mulText, mulRankText))
}

UnlockConditions.getLocForBitValues <- function getLocForBitValues(modeType, values, hasCustomUnlockableList = false)
{
  let valuesLoc = []
  if (hasCustomUnlockableList || ::isInArray(modeType, nestedUnlockModes))
    foreach(name in values)
      valuesLoc.append(::get_unlock_name_text(-1, name))
  else if (modeType == "char_unit_exist")
    foreach(name in values)
      valuesLoc.append(::getUnitName(name))
  else if (modeType == "char_resources")
    foreach(id in values)
    {
      let decorator = ::g_decorator.getDecoratorById(id)
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

UnlockConditions.getProgressBarData <- function getProgressBarData(modeType, curVal, maxVal)
{
  let res = {
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

UnlockConditions.getHeaderCondition <- function getHeaderCondition(conditions)
{
  foreach(c in conditions)
    if (c.needToShowInHeader)
      return c.values
  return null
}
