let { number_of_set_bits } = require("%sqstd/math.nut")
let { buildDateStrShort } = require("%scripts/time.nut")
let { getUnlockConditions } = require("%scripts/unlocks/unlocksConditionsModule.nut")

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
    ::loc(locId, { num, numRealistic, numHardcore, beginDate = getUnlockBeginDateText(config) })))
}

let function getSubUnlockLocName(config) {
  let subUnlockBlk = ::g_unlocks.getUnlockById(config?.mode.unlock ?? config?.conditions[0].values[0] ?? "")
  if (subUnlockBlk)
    return subUnlockBlk.locId ? getUnlockLocName(subUnlockBlk) : ::loc($"{subUnlockBlk.id}/name")
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
      ::loc(cfg.locStagesDescId),
      ::loc("ui/colon"),
      ::colorize("unlockActiveColor", ::loc($"{cfg.curStage}/{cfg.stages.len()}")))

  return ::loc("challenge/stage", {
    stage = ::colorize("unlockActiveColor", cfg.curStage + 1)
    totalStages = ::colorize("unlockActiveColor", cfg.stages.len())
  })
}

let function getUnlockDesc(cfg) {
  let desc = [getUnlockStagesDesc(cfg)]

  let hasDescInConds = cfg?.conditions.findindex(@(c) "typeLocIDWithoutValue" in c) != null
  if (!hasDescInConds)
    if ((cfg?.locDescId ?? "") != "") {
      let isBitMode = ::UnlockConditions.isBitModeType(cfg.type)
      let num = isBitMode ? number_of_set_bits(cfg.maxVal) : cfg.maxVal
      desc.append(::loc(cfg.locDescId, { num }))
    }
    else if ((cfg?.desc ?? "") != "")
      desc.append(cfg.desc)

  return "\n".join(desc, true)
}

let function getUnlockConditionsText(cfg, params = {}) {
  if (!cfg?.conditions)
    return ""

  params.isExpired <- cfg.isExpired

  let hideCurVal = ::g_unlocks.isUnlockComplete(cfg) && !cfg.useLastStageAsUnlockOpening
  let curVal = params?.curVal ?? (hideCurVal ? null : cfg.curVal)
  return ::UnlockConditions.getConditionsText(cfg.conditions, curVal, cfg.maxVal, params)
}

let function getUnlockCostText(cfg) {
  if (!cfg)
    return ""

  let cost = ::get_unlock_cost(cfg.id)
  if (cost > ::zero_money)
    return "".concat(
      ::loc("ugm/price"),
      ::loc("ui/colon"),
      ::colorize("unlockActiveColor", cost.getTextAccordingToBalance()))

  return ""
}

let function getUnlockMainCondText(cfg) {
  if (!cfg?.conditions)
    return ""

  let hideCurVal = ::g_unlocks.isUnlockComplete(cfg) && !cfg.useLastStageAsUnlockOpening
  let curVal = hideCurVal ? null : cfg.curVal
  return ::UnlockConditions.getMainConditionText(cfg.conditions, curVal, cfg.maxVal)
}

let function getUnlockMultDesc(cfg) {
  if (!cfg?.conditions)
    return ""

  let mainCond = ::UnlockConditions.getMainProgressCondition(cfg.conditions)
  return ::UnlockConditions.getMultipliersText(mainCond)
}

let function getFullUnlockDesc(cfg, params = {}) {
  return "\n".join([
    getUnlockDesc(cfg),
    getUnlockConditionsText(cfg, params),
    params?.showCost ? getUnlockCostText(cfg) : ""], true)
}

let function getFullUnlockDescByName(unlockName, forUnlockedStage = -1, params = {}) {
  let unlock = ::g_unlocks.getUnlockById(unlockName)
  if (!unlock)
    return ""

  let config = ::build_conditions_config(unlock, forUnlockedStage)
  return getFullUnlockDesc(config, params)
}

return {
  getUnlockLocName
  getSubUnlockLocName
  getFullUnlockDesc
  getFullUnlockDescByName
  getUnlockDesc
  getUnlockConditionsText
  getUnlockMainCondText
  getUnlockMultDesc
}