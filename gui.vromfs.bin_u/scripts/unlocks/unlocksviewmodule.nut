let { number_of_set_bits } = require("std/math.nut")

let function getUnlockLocName(config, key = "locId") {
  let isRawBlk = (config?.mode != null)
  local num = (isRawBlk ? config.mode?.num : config?.maxVal) ?? 0
  if (num > 0)
    num = ::UnlockConditions.isBitModeType(isRawBlk ? config.mode.type : config.type) ? number_of_set_bits(num) : num
  local numRealistic = (isRawBlk ? config.mode?.mulRealistic : config?.conditions[0].multiplier.HistoricalBattle) ?? 1
  local numHardcore = (isRawBlk ? config.mode?.mulHardcore : config?.conditions[0].multiplier.FullRealBattles) ?? 1
  numRealistic = ::ceil(num.tofloat() / numRealistic)
  numHardcore = ::ceil(num.tofloat() / numHardcore)

  return "".join(::g_localization.getLocIdsArray(config, key).map(@(locId) locId.len() == 1 ? locId :
    ::loc(locId, { num, numRealistic, numHardcore })))
}

let function getSubUnlockLocName(config) {
  let subUnlockBlk = ::g_unlocks.getUnlockById(config?.mode.unlock ?? config?.conditions[0].values[0] ?? "")
  if (subUnlockBlk)
    return subUnlockBlk.locId ? getUnlockLocName(subUnlockBlk) : ::loc($"{subUnlockBlk.id}/name")
  else
    return ""
}


return {
  getUnlockLocName
  getSubUnlockLocName
}