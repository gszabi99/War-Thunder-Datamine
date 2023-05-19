//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { g_script_reloader } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")
let DataBlock = require("DataBlock")
let { Point2 } = require("dagor.math")
let { pow } = require("math")
let { format } = require("string")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let updateExtWatched = require("%scripts/global/updateExtWatched.nut")
let { floatToStringRounded } = require("%sqstd/string.nut")

let persistent = {
  unitsCfg = null
}
g_script_reloader.registerPersistentData("OptionsMeasureUnits", persistent, persistent.keys())

// Preserve the same order as in measureUnits.blk
let optionsByIndex = [
  { useroptId = ::USEROPT_MEASUREUNITS_SPEED,                 optId = "speed" },
  { useroptId = ::USEROPT_MEASUREUNITS_ALT,                   optId = "alt" },
  { useroptId = ::USEROPT_MEASUREUNITS_DIST,                  optId = "dist" },
  { useroptId = ::USEROPT_MEASUREUNITS_CLIMBSPEED,            optId = "climbSpeed" },
  { useroptId = ::USEROPT_MEASUREUNITS_TEMPERATURE,           optId = "temperature" },
  { useroptId = ::USEROPT_MEASUREUNITS_WING_LOADING,          optId = "wing_loading" },
  { useroptId = ::USEROPT_MEASUREUNITS_POWER_TO_WEIGHT_RATIO, optId = "power_to_weight_ratio" },
]

let function isInitialized() {
  return (persistent.unitsCfg?.len() ?? 0) != 0
}

let getMeasureUnitsNames = @() isInitialized()
  ? ::g_measure_type.types.reduce(@(acc, v) acc.__update({ [v.name] = v.getMeasureUnitsLocKey() }), {})
  : null

let function init() {
  persistent.unitsCfg = []
  let blk = DataBlock()
  blk.load("config/measureUnits.blk")
  for (local i = 0; i < blk.blockCount(); i++) {
    let blkUnits = blk.getBlock(i)
    let units = []
    for (local j = 0; j < blkUnits.blockCount(); j++) {
      let blkUnit = blkUnits.getBlock(j)
      let roundAfter = blkUnit.getPoint2("roundAfter", Point2(0, 0))
      let unit = {
        name = blkUnit.getBlockName()
        round = blkUnit.getInt("round", 0)
        koef = blkUnit.getReal("koef", 1.0)
        roundAfterVal = roundAfter.x
        roundAfterBy  = roundAfter.y
      }
      units.append(unit)
    }
    persistent.unitsCfg.append(units)
  }
  updateExtWatched({ measureUnitsNames = getMeasureUnitsNames() })
}

let function getOption(useroptId) {
  let unitNo = optionsByIndex.findindex(@(option) option.useroptId == useroptId)
  let option = optionsByIndex[unitNo]
  let units = persistent.unitsCfg[unitNo]
  let unitName = ::get_option_unit_type(unitNo)

  return {
    id     = $"measure_units_{option.optId}"
    items  = units.map(@(u) $"#measureUnits/{u.name}")
    values = units.map(@(u) u.name)
    value  = units.findindex(@(u) u.name == unitName) ?? -1
  }
}

let function getMeasureCfg(unitNo) {
  let unitName = ::get_option_unit_type(unitNo)
  return persistent.unitsCfg[unitNo].findvalue(@(u) u.name == unitName)
}

local function countMeasure(unitNo, value, separator = " - ", addMeasureUnits = true, forceMaxPrecise = false, isPresize = true) {
  let unit = getMeasureCfg(unitNo)
  if (!unit)
    return ""

  if (type(value) != "array")
    value = [ value ]
  local maxValue = null
  foreach (val in value)
    if (maxValue == null || maxValue < val)
      maxValue = val
  let shouldRoundValue = !forceMaxPrecise &&
    (unit.roundAfterBy > 0 && (maxValue * unit.koef) > unit.roundAfterVal)
  local valuesList = value.map(function(val) {
    val = val * unit.koef
    if (shouldRoundValue && isPresize)
      return format("%d", ((val / unit.roundAfterBy + 0.5).tointeger() * unit.roundAfterBy).tointeger())
    let roundPrecision = (unit.round == 0 || !isPresize) ? 1 : pow(0.1, unit.round)
    return floatToStringRounded(val, roundPrecision)
  })
  local result = separator.join(valuesList)
  if (addMeasureUnits)
    result = "{0} {1}".subst(result, loc($"measureUnits/{unit.name}"))
  return result
}

let function isMetricSystem(unitNo) {
  let unitName = ::get_option_unit_type(unitNo)
  return persistent.unitsCfg[unitNo].findindex(@(u) u.name == unitName) == 0
}

addListenersWithoutEnv({
  MeasureUnitsChanged = @(_) updateExtWatched({ measureUnitsNames = getMeasureUnitsNames() })
})

return {
  init = init
  isInitialized = isInitialized
  getOption = getOption
  getMeasureCfg = getMeasureCfg
  countMeasure = countMeasure
  isMetricSystem = isMetricSystem
}
