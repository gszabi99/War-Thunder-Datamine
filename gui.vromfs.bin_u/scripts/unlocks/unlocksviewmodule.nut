from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { format } = require("string")
let { number_of_set_bits, round_by_value } = require("%sqstd/math.nut")
let { buildDateStrShort } = require("%scripts/time.nut")
let { getUnlockConditions } = require("%scripts/unlocks/unlocksConditionsModule.nut")
let { processUnitTypeArray } = require("%scripts/unit/unitClassType.nut")
let { getRoleText } = require("%scripts/unit/unitInfoTexts.nut")
let { getShopDiffCode } = require("%scripts/shop/shopDifficulty.nut")

let customLocTypes = ["gameModeInfoString", "missionPostfix"]

let conditionsOrder = [
  "beginDate", "endDate",
  "missionsWon", "mission", "char_mission_completed",
  "missionType", "atLeastOneUnitsRankOnStartMission", "maxUnitsRankOnStartMission",
  "unitExists", "additional", "unitClass",
  "gameModeInfoString", "missionPostfix", "modes", "events", "tournamentMode",
  "location", "operationMap", "weaponType", "ammoMass", "bulletCaliber", "difficulty",
  "playerUnit", "playerType", "playerExpClass", "playerUnitRank", "playerUnitMRank", "playerTag", "playerCountry",
  "offenderUnit", "offenderType", "offenderUnitRank", "offenderUnitMRank", "offenderTag", "offenderSpeed",
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

let condWithValuesInside = [
  "atLeastOneUnitsRankOnStartMission", "eliteUnitsOnly"
]

let mapConditionUnitType = {
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

let function getUnlockBeginDateText(unlock) {
  let isBlk = unlock?.mode != null
  let conds = isBlk ? getUnlockConditions(unlock.mode) : unlock?.conditions
  local timeCond = conds?.findvalue(@(c) ::unlock_time_range_conditions.contains(c.type))
  if (isBlk)
    timeCond = ::UnlockConditions.loadCondition(timeCond, unlock.mode?.type)
  return (timeCond?.beginTime != null)
    ? buildDateStrShort(timeCond.beginTime).replace(" ", ::nbsp)
    : ""
}

let function getUnlockLocName(config, key = "locId") {
  let isRawBlk = (config?.mode != null)
  local num = (isRawBlk ? config.mode?.num : config?.maxVal) ?? 0
  if (num > 0)
    num = ::UnlockConditions.isBitModeType(isRawBlk ? config.mode.type : config.type) ? number_of_set_bits(num) : num
  local numRealistic = (isRawBlk ? config.mode?.mulRealistic : config?.conditions[0].multiplier.HistoricalBattle) ?? 1
  local numHardcore = (isRawBlk ? config.mode?.mulHardcore : config?.conditions[0].multiplier.FullRealBattles) ?? 1
  numRealistic = ::ceil(num.tofloat() / numRealistic)
  numHardcore = ::ceil(num.tofloat() / numHardcore)

  return "".join(::g_localization.getLocIdsArray(config?[key]).map(@(locId) locId.len() == 1 ? locId :
    loc(locId, { num, numRealistic, numHardcore, beginDate = getUnlockBeginDateText(config) })))
}

let function getSubUnlockLocName(config) {
  let subUnlockBlk = ::g_unlocks.getUnlockById(config?.mode.unlock ?? config?.conditions[0].values[0] ?? "")
  if (subUnlockBlk)
    return subUnlockBlk.locId ? getUnlockLocName(subUnlockBlk) : loc($"{subUnlockBlk.id}/name")
  else
    return ""
}

let function getUnlockStagesDesc(cfg) {
  if (cfg == null)
    return ""

  let hasStages = (cfg.stages.len() ?? 0) > 1
  let hideDesc = ::g_unlocks.isUnlockComplete(cfg) && !cfg.useLastStageAsUnlockOpening
  if (!hasStages || hideDesc)
    return ""

  if (cfg.locStagesDescId != "")
    return "".concat(
      loc(cfg.locStagesDescId),
      loc("ui/colon"),
      colorize("unlockActiveColor", loc($"{cfg.curStage}/{cfg.stages.len()}")))

  return loc("challenge/stage", {
    stage = colorize("unlockActiveColor", cfg.curStage + 1)
    totalStages = colorize("unlockActiveColor", cfg.stages.len())
  })
}

let function getUnlockDesc(cfg) {
  let desc = [getUnlockStagesDesc(cfg)]

  let hasDescInConds = cfg?.conditions.findindex(@(c) "typeLocIDWithoutValue" in c) != null
  if (!hasDescInConds)
    if ((cfg?.locDescId ?? "") != "") {
      let isBitMode = ::UnlockConditions.isBitModeType(cfg.type)
      let num = isBitMode ? number_of_set_bits(cfg.maxVal) : cfg.maxVal
      desc.append(loc(cfg.locDescId, { num }))
    }
    else if ((cfg?.desc ?? "") != "")
      desc.append(cfg.desc)

  return "\n".join(desc, true)
}

let function addValueToGroup(groupsList, group, value) {
  if (group not in groupsList)
    groupsList[group] <- []
  groupsList[group].append(value)
}

let function addTextToCondTextList(condTextsList, group, valuesData, params = null) {
  local valuesText = loc("ui/comma").join(valuesData, true)
  if (valuesText != "") {
    let isExpired = group == "endDate" && params?.isExpired
    valuesText = colorize(isExpired ? "red" : "unlockActiveColor", valuesText)
  }

  local text = !isInArray(group, customLocTypes)
    ? loc($"conditions/{group}", { value = valuesText })
    : params?.customLocGroupText ?? ""

  if (!isInArray(group, condWithValuesInside))
    if (valuesText != "")
      text = $"{text}{(text.len() ? loc("ui/colon") : "")}{valuesText}"
    else
      text = ""

  condTextsList.append(text)
}

let function getUsualCondValueText(condType, v, condition) {
  switch (condType) {
    case "playerUnit":
    case "offenderUnit":
    case "targetUnit":
    case "crewsUnit":
    case "unitExists":
    case "usedInSessionUnit":
    case "lastInSessionUnit":
      return ::getUnitName(v)
    case "playerType":
    case "targetType":
    case "usedInSessionType":
    case "lastInSessionType":
    case "offenderType":
      return loc($"unlockTag/{getTblValue(v, mapConditionUnitType, v)}")
    case "playerExpClass":
    case "unitClass":
    case "usedInSessionClass":
    case "lastInSessionClass":
      return getRoleText(::g_string.cutPrefix(v, "exp_", v))
    case "playerTag":
    case "offenderTag":
    case "crewsTag":
    case "targetTag":
    case "country":
    case "playerCountry":
    case "usedInSessionTag":
    case "lastInSessionTag":
      return loc($"unlockTag/{v}")
    case "targetDistance":
      return format(loc($"conditions/{condition.gt ? "min" : "max"}_limit"), v.tostring())
    case "ammoMass":
    case "bulletCaliber":
    case "offenderSpeed":
      return format(loc(v.notLess ? "conditions/min_limit" : "conditions/less"), v.value.tostring())
    case "activity":
    case "playerUnitRank":
    case "offenderUnitRank":
    case "playerUnitMRank":
    case "offenderUnitMRank":
    case "crewsUnitRank":
    case "crewsUnitMRank":
    case "minStat":
    case "higherBR":
      return v.tostring()
    case "difficulty":
      local text = ::getDifficultyLocalizationText(v)
      if (!getTblValue("exact", condition, false) && v != "hardcore")
        text = $"{text} {loc("conditions/moreComplex")}"
      return text
    case "mission":
    case "char_mission_completed":
    case "missionType":
      return loc($"missions/{v}")
    case "era":
    case "maxUnitsRankOnStartMission":
      return ::get_roman_numeral(v)
    case "events":
      return ::events.getNameByEconomicName(v)
    case "offenderIsSupportGun":
      return loc(v)
    case "operationMap":
      return loc($"worldWar/map/{v}")
    default:
      return loc($"{condType}/{v}")
  }
  return ""
}

let function addUsualConditionsText(groupsList, condition) {
  let condType = condition.type
  let group = getTblValue("locGroup", condition, condType)
  local values = condition.values
  local text = ""

  if (values == null)
    return addValueToGroup(groupsList, group, text)

  if (typeof values != "array")
    values = [values]

  values = processUnitTypeArray(values)
  foreach (v in values)
    addValueToGroup(groupsList, group, getUsualCondValueText(condType, v, condition))
}

let function addUniqConditionsText(groupsList, condition) {
  let condType = condition.type

  if (isInArray(condType, ::unlock_time_range_conditions)) {
    foreach(key in ["beginDate", "endDate"])
      if (key in condition)
        addValueToGroup(groupsList, key, condition[key])
    return true
  }

  if (condType == "atLeastOneUnitsRankOnStartMission") {
    let valuesTexts = condition.values?.map(@(v) ::get_roman_numeral) ?? []
    addValueToGroup(groupsList, condType, "-".join(valuesTexts, true))
    return true
  }

  if (condType == "eliteUnitsOnly") {
    addValueToGroup(groupsList, condType, "")
    return true
  }

  return false
}

let function addDataToCustomGroup(groupsList, condType, data) {
  if (condType not in groupsList)
    groupsList[condType] <- []

  let customData = groupsList[condType]
  foreach (conditionData in customData)
    if (data.groupText == getTblValue("groupText", conditionData)) {
      conditionData.descText.append(getTblValue("descText", data)[0])
      return
    }

  groupsList[condType].append(data)
}

let function addCustomConditionsTextData(groupsList, condition) {
  local values = condition.values
  if (values == null)
    return

  if (typeof values != "array")
    values = [values]

  let condType = condition.type
  let desc = []
  local group = ""

  foreach (v in values) {
    if (condType == "gameModeInfoString") {
      group = condition?.locParamName
        ? loc(condition.locParamName)
        : loc($"conditions/gameModeInfoString/{condition.name}")

      let locValuePrefix = condition?.locValuePrefix ?? "conditions/gameModeInfoString/"
      desc.append(loc($"{locValuePrefix}{v}"))
    }
    else if (condType == "missionPostfix" ) {
      group = loc($"conditions/{condition.locGroup}")

      let locValuePrefix = condition?.locValuePrefix ?? "options/"
      desc.append(loc($"{locValuePrefix}{v}"))
    }
  }

  addDataToCustomGroup(groupsList, condType, {
    groupText = group
    descText = [desc]
  })
}

let function getUnlockCondsDesc(conditions, isExpired = false) {
  let descByLocGroups = {}
  let customDataByLocGroups = {}
  foreach (condition in conditions)
    if (!isInArray(condition.type, customLocTypes)) {
      if (!addUniqConditionsText(descByLocGroups, condition))
        addUsualConditionsText(descByLocGroups, condition)
    }
    else
      addCustomConditionsTextData(customDataByLocGroups, condition)

  let condTextsList = []
  foreach (group in conditionsOrder) {
    if (!isInArray(group, customLocTypes)) {
      let data = getTblValue(group, descByLocGroups)
      if (data == null || data.len() == 0)
        continue

      addTextToCondTextList(condTextsList, group, data, { isExpired })
    }
    else {
      let customData = getTblValue(group, customDataByLocGroups)
      if (customData == null || customData.len() == 0)
        continue

      foreach (condCustomData in customData)
        foreach (descText in condCustomData.descText)
          addTextToCondTextList(condTextsList, group, descText, {
            customLocGroupText = condCustomData.groupText
            isExpired
          })
    }
  }

  return "\n".join(condTextsList, true)
}

let function getUnlockCondsDescByCfg(cfg) {
  if (!cfg?.conditions)
    return ""

  return getUnlockCondsDesc(cfg.conditions, cfg.isExpired)
}

let function getUnlockCostText(cfg) {
  if (!cfg)
    return ""

  let cost = ::get_unlock_cost(cfg.id)
  if (cost > ::zero_money)
    return "".concat(
      loc("ugm/price"),
      loc("ui/colon"),
      colorize("unlockActiveColor", cost.getTextAccordingToBalance()))

  return ""
}

let singleAttachmentList = {
  unlockOpenCount = "unlock"
  unlockStageCount = "unlock"
}

let function isCheckedBySingleAttachment(modeType) {
  return modeType in singleAttachmentList || ::UnlockConditions.isBitModeType(modeType)
}

let function getSingleAttachmentConditionText(condition, curValue, maxValue) {
  let modeType = getTblValue("modeType", condition)
  let locNames = ::UnlockConditions.getLocForBitValues(modeType, condition.values)
  let valueText = colorize("unlockActiveColor", $"\"{loc("ui/comma").join(locNames, true)}\"")
  let progress = colorize("unlockActiveColor", curValue != null
    ? $"{curValue}/{maxValue}"
    : $"{maxValue}")
  return loc($"conditions/{modeType}/single", { value = valueText, progress })
}

// curValue - current value to show in the text (if null, do not show)
// maxValue - overrides progress value from mode if maxValue != null
// param locEnding - ending for main condition loc key
//   if such a loc is not found, usual locId is used
let function getUnlockMainCondDesc(condition, curValue = null, maxValue = null, params = null) {
  let modeType = condition?.modeType
  if (!modeType)
    return ""

  let typeLocIDWithoutValue = getTblValue("typeLocIDWithoutValue", condition)
  if (typeLocIDWithoutValue)
    return loc(typeLocIDWithoutValue)

  let bitMode = ::UnlockConditions.isBitModeType(modeType)
  let haveModeTypeLocID = "modeTypeLocID" in condition

  if (maxValue == null)
    maxValue = getTblValue("rewardNum", condition) || getTblValue("num", condition)

  if (::is_numeric(curValue)) {
    if (bitMode)
      curValue = number_of_set_bits(curValue)
    else if (::is_numeric(maxValue) && curValue > maxValue) // validate values if numeric
      curValue = maxValue
  }

  if (bitMode && ::is_numeric(maxValue))
    maxValue = number_of_set_bits(maxValue)

  if (isCheckedBySingleAttachment(modeType)
      && !haveModeTypeLocID
      && condition.values
      && condition.values.len() == 1)
    return getSingleAttachmentConditionText(condition, curValue, maxValue)

  local textId = $"conditions/{modeType}"
  let textParams = {}

  local progressText = ""
  let showValueForBitList = params?.showValueForBitList
  if (bitMode && (params?.bitListInValue || showValueForBitList)) {
    if (curValue == null || params?.showValueForBitList)
      progressText = ::g_string.implode(::UnlockConditions.getLocForBitValues(modeType, condition.values), ", ")

    if (::is_numeric(maxValue) && maxValue != condition.values.len()) {
      textId = $"{textId}/withValue"
      textParams.value <- colorize("unlockActiveColor", maxValue)
    }
  }
  else if (modeType == "maxUnitsRankOnStartMission") {
    let valuesText = condition.values?.map(@(v) ::get_roman_numeral) ?? []
    progressText = "-".join(valuesText, true)
  }
  else if (modeType == "amountDamagesZone") {
    if (::is_numeric(curValue) && ::is_numeric(maxValue)) {
      let a = round_by_value(curValue * 0.001, 0.001)
      let b = round_by_value(maxValue * 0.001, 0.001)
      progressText = $"{a}/{b}"
    }
  }
  else // usual progress text
    progressText = "/".join([curValue, maxValue], true)

  if (params?.isProgressTextOnly)
    return progressText

  if (haveModeTypeLocID)
    textId = condition.modeTypeLocID

  else if (modeType == "rank" || modeType == "char_country_rank") {
    let country = getTblValue("country", condition)
    textId = country ? $"mainmenu/rank/{country}" : "mainmenu/rank"
  }
  else if (modeType == "unlockCount")
    textId = $"conditions/{getTblValue("unlockType", condition, "")}"
  else if (modeType == "char_static_progress")
    textParams.level <- loc($"crew/qualification/{getTblValue("level", condition, 0)}")
  else if (modeType == "landings" && getTblValue("carrierOnly", condition))
    textId = "conditions/carrierOnly"
  else if (getTblValue("isShip", condition)) // really strange exclude, because this flag is used with various modeTypes
    textId = "conditions/isShip"
  else if (modeType == "killedAirScore")
    textId = "conditions/statKillsAir"
  else if (modeType == "sessionsStarted")
    textId = "conditions/missionsPlayed"
  else if (modeType == "char_resources_count")
    textId = $"conditions/char_resources_count/{getTblValue("resourceType", condition, "")}"
  else if (modeType == "amountDamagesZone")
    textId = "debriefing/Damage"
  else if (modeType == "totalMissionScore")
    textId = "conditions/statScore"

  local res = ""

  if ("locEnding" in params)
    res = loc($"{textId}{params.locEnding}", textParams)

  if (res == "")
    res = loc(textId, textParams)

  if ("reason" in condition) {
    let reason = loc($"{textId}/{condition.reason}")
    res = $"{res} {reason}"
  }

  // if condition lang is empty and max value == 1 no need to show progress text
  if (progressText != "" && (res != "" || maxValue != 1))
    res = $"{res}{loc("ui/colon")}{colorize("unlockActiveColor", progressText)}"

  return res
}

let function getUnlockMainCondDescByCfg(cfg, params = null) {
  if (!cfg?.conditions)
    return ""

  let mainCond = ::UnlockConditions.getMainProgressCondition(cfg.conditions)
  if (!mainCond)
    return ""

  let hideCurVal = ::g_unlocks.isUnlockComplete(cfg) && !cfg.useLastStageAsUnlockOpening
  let curVal = params?.curVal ?? (hideCurVal ? null : cfg.curVal)
  return getUnlockMainCondDesc(mainCond, curVal, cfg.maxVal, params)
}

let function getUnlockMultDesc(condition) {
  let multiplierTable = condition?.multiplier ?? {}
  let rankMultiplierTable = condition?.rankMultiplier ?? {}
  if (multiplierTable.len() == 0 && rankMultiplierTable.len() == 0)
    return ""

  local mulText = ""

  if ((multiplierTable?.WWBattleForOwnClan ?? 1) > 1)
    return "{0}{1}{2}".subst(
      loc("conditions/mulWWBattleForOwnClan"),
      loc("ui/colon"),
      colorize("unlockActiveColor", format("x%d", multiplierTable.WWBattleForOwnClan)))

  let isMultipliersByDiff = multiplierTable?.ArcadeBattle != null
  foreach (param, num in multiplierTable) {
    if (num == 1)
      continue

    if (!isMultipliersByDiff && ((param - getShopDiffCode()) % 3 != 0))
      continue

    if (mulText.len() > 0)
      mulText = $"{mulText}, "

    let mulLocParam = isMultipliersByDiff
      ? loc($"clan/short{param}")
      : loc($"missions/{::get_mode_localization_text(param)}_short")
    mulText = $"{mulText}{mulLocParam} (x{num})"
  }

  local mulRankText = ""
  if (rankMultiplierTable.len() > 0) {
    local lastAddedRank = null
    for (local rank = 1; rank <= ::max_country_rank; rank++) {
      let curRankMul = rankMultiplierTable[rank]
      let nextRankMul = rankMultiplierTable?[rank + 1]
      if (!curRankMul || (nextRankMul && curRankMul == nextRankMul))
        continue

      let rankText = (rank - 1 == lastAddedRank || rank == 1)
        ? ::get_roman_numeral(rank)
        : ::UnlockConditions.getRangeString(::get_roman_numeral(lastAddedRank ?? 1), ::get_roman_numeral(rank))

      if (mulRankText.len() > 0)
        mulRankText = $"{mulRankText}, "

      mulRankText = $"{mulRankText}{rankText} (x{curRankMul})"
      lastAddedRank = rank
    }
  }

  mulText = mulText.len() > 0
    ? "{0}{1}{2}".subst(loc("conditions/multiplier"), loc("ui/colon"), mulText)
    : ""
  if (mulText.len() > 0 && mulRankText.len() > 0)
    mulText = $"{mulText}\n"

  mulRankText = mulRankText.len() > 0
    ? "{0}{1}{2}".subst(loc("conditions/rankMultiplier"), loc("ui/colon"), mulRankText)
    : ""
  return colorize("fadedTextColor", "{0}{1}".subst(mulText, mulRankText))
}

let function getUnlockMultDescByCfg(cfg) {
  if (!cfg?.conditions)
    return ""

  let mainCond = ::UnlockConditions.getMainProgressCondition(cfg.conditions)
  return getUnlockMultDesc(mainCond)
}

let function getFullUnlockDesc(cfg, params = {}) {
  return "\n".join([
    getUnlockDesc(cfg),
    getUnlockMainCondDescByCfg(cfg, params),
    getUnlockCondsDescByCfg(cfg),
    getUnlockMultDescByCfg(cfg)], true)
}

let function getFullUnlockDescByName(unlockName, forUnlockedStage = -1, params = {}) {
  let unlock = ::g_unlocks.getUnlockById(unlockName)
  if (!unlock)
    return ""

  let config = ::build_conditions_config(unlock, forUnlockedStage)
  return getFullUnlockDesc(config, params)
}

let function getFullUnlockCondsDesc(conds, curVal = null, maxVal = null, params = null) {
  if (!conds)
    return ""

  let mainCond = ::UnlockConditions.getMainProgressCondition(conds)
  return "\n".join([
    getUnlockMainCondDesc(mainCond, curVal, maxVal, params),
    getUnlockCondsDesc(conds),
    getUnlockMultDesc(mainCond)
  ], true)
}

let function getFullUnlockCondsDescInline(conds) {
  if (!conds)
    return ""

  let mainCond = ::UnlockConditions.getMainProgressCondition(conds)
  let mainCondText = getUnlockMainCondDesc(mainCond)
  let condsText = getUnlockCondsDesc(conds)
  return ", ".join([
    mainCondText,
    (condsText != "" ? $"({condsText})" : ""),
    getUnlockMultDesc(mainCond)
  ], true)
}

let function getUnitRequireUnlockText(unit) {
  let desc = getFullUnlockDescByName(unit.reqUnlock, -1, { showValueForBitList = true })
  return "\n".concat(loc("mainmenu/needUnlock"), desc)
}

let function getUnitRequireUnlockShortText(unit) {
  let unlockBlk = ::g_unlocks.getUnlockById(unit.reqUnlock)
  let cfg = ::build_conditions_config(unlockBlk)
  let mainCond = ::UnlockConditions.getMainProgressCondition(cfg.conditions)
  return getUnlockMainCondDesc(
    mainCond, cfg.curVal, cfg.maxVal, { isProgressTextOnly = true })
}

return {
  getUnlockLocName
  getSubUnlockLocName
  getFullUnlockDesc
  getFullUnlockDescByName
  getFullUnlockCondsDesc
  getFullUnlockCondsDescInline
  getUnlockDesc
  getUnlockMainCondDesc
  getUnlockMainCondDescByCfg
  getUnlockCondsDesc
  getUnlockCondsDescByCfg
  getUnlockMultDesc
  getUnlockMultDescByCfg
  getUnlockCostText
  getUnitRequireUnlockText
  getUnitRequireUnlockShortText
}