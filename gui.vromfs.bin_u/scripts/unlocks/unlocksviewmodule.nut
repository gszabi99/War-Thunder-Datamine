let { number_of_set_bits } = require("%sqstd/math.nut")

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
    ::loc(locId, { num, numRealistic, numHardcore })))
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
  if (!hasStages || ::g_unlocks.isUnlockComplete(cfg))
    return ""

  return ::loc("challenge/stage", {
    stage = ::colorize("unlockActiveColor", cfg.curStage + 1)
    totalStages = ::colorize("unlockActiveColor", cfg.stages.len())
  })
}

let function getUnlockDesc(cfg, params = {}) {
  let desc = [getUnlockStagesDesc(cfg)]

  let hasDescInConds = cfg?.conditions.findindex(@(c) "typeLocIDWithoutValue" in c) != null
  if (!hasDescInConds)
    if ((cfg?.locDescId ?? "") != "") {
      let isBitMode = ::UnlockConditions.isBitModeType(cfg.type)
      let maxVal = params?.maxVal ?? cfg.maxVal
      let num = isBitMode ? number_of_set_bits(maxVal) : maxVal
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

  let curVal = params?.curVal ?? (::g_unlocks.isUnlockComplete(cfg) ? null : cfg.curVal)
  let maxVal = params?.maxVal ?? cfg.maxVal
  let desc = [::UnlockConditions.getConditionsText(cfg.conditions, curVal, maxVal, params)]

  if (params?.showCost ?? false) {
    let cost = ::get_unlock_cost(cfg.id)
    if (cost > ::zero_money)
      desc.append("".concat(
        ::loc("ugm/price"),
        ::loc("ui/colon"),
        ::colorize("unlockActiveColor", cost.getTextAccordingToBalance())))
  }

  return "\n".join(desc, true)
}

let function getUnlockMainCondText(cfg) {
  if (!cfg?.conditions)
    return ""

  let curVal = ::g_unlocks.isUnlockComplete(cfg) ? null : cfg.curVal
  return ::UnlockConditions.getMainConditionText(cfg.conditions, curVal, cfg.maxVal)
}

let function getUnlockMultDesc(cfg) {
  if (!cfg?.conditions)
    return ""

  let mainCond = ::UnlockConditions.getMainProgressCondition(cfg.conditions)
  return ::UnlockConditions.getMultipliersText(mainCond)
}

let function getFullUnlockDesc(cfg, params) {
  return "\n".join([
    getUnlockDesc(cfg, params),
    getUnlockConditionsText(cfg, params)], true)
}

return {
  getUnlockLocName
  getSubUnlockLocName
  getFullUnlockDesc
  getUnlockDesc
  getUnlockConditionsText
  getUnlockMainCondText
  getUnlockMultDesc
}