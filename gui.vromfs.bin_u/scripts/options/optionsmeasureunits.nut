local persistent = {
  unitsCfg = null
}
::g_script_reloader.registerPersistentData("OptionsMeasureUnits", persistent, persistent.keys())

// Preserve the same order as in measureUnits.blk
local optionsByIndex = [
  { useroptId = ::USEROPT_MEASUREUNITS_SPEED,                 optId = "speed" },
  { useroptId = ::USEROPT_MEASUREUNITS_ALT,                   optId = "alt" },
  { useroptId = ::USEROPT_MEASUREUNITS_DIST,                  optId = "dist" },
  { useroptId = ::USEROPT_MEASUREUNITS_CLIMBSPEED,            optId = "climbSpeed" },
  { useroptId = ::USEROPT_MEASUREUNITS_TEMPERATURE,           optId = "temperature" },
  { useroptId = ::USEROPT_MEASUREUNITS_WING_LOADING,          optId = "wing_loading" },
  { useroptId = ::USEROPT_MEASUREUNITS_POWER_TO_WEIGHT_RATIO, optId = "power_to_weight_ratio" },
]

local function init()
{
  persistent.unitsCfg = []
  local blk = ::DataBlock()
  blk.load("config/measureUnits.blk")
  for (local i = 0; i < blk.blockCount(); i++)
  {
    local blkUnits = blk.getBlock(i)
    local units = []
    for (local j = 0; j < blkUnits.blockCount(); j++)
    {
      local blkUnit = blkUnits.getBlock(j)
      local roundAfter = blkUnit.getPoint2("roundAfter", ::Point2(0, 0))
      local unit = {
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
}

local function isInitialized()
{
  return (persistent.unitsCfg?.len() ?? 0) != 0
}

local function getOption(useroptId)
{
  local unitNo = optionsByIndex.findindex(@(option) option.useroptId == useroptId)
  local option = optionsByIndex[unitNo]
  local units = persistent.unitsCfg[unitNo]
  local unitName = ::get_option_unit_type(unitNo)

  return {
    id     = $"measure_units_{option.optId}"
    items  = units.map(@(u) $"#measureUnits/{u.name}")
    values = units.map(@(u) u.name)
    value  = units.findindex(@(u) u.name == unitName) ?? -1
  }
}

local function getMeasureCfg(unitNo)
{
  local unitName = ::get_option_unit_type(unitNo)
  return persistent.unitsCfg[unitNo].findvalue(@(u) u.name == unitName)
}

local function countMeasure(unitNo, value, separator = " - ", addMeasureUnits = true, forceMaxPrecise = false, isPresize = true)
{
  local unit = getMeasureCfg(unitNo)
  if (!unit)
    return ""

  if (type(value) != "array")
    value = [ value ]
  local maxValue = null
  foreach (val in value)
    if (maxValue == null || maxValue < val)
      maxValue = val
  local shouldRoundValue = !forceMaxPrecise &&
    (unit.roundAfterBy > 0 && (maxValue * unit.koef) > unit.roundAfterVal)
  local valuesList = value.map(function(val) {
    val = val * unit.koef
    if (shouldRoundValue && isPresize)
      return ::format("%d", ((val / unit.roundAfterBy + 0.5).tointeger() * unit.roundAfterBy).tointeger())
    local roundPrecision = (unit.round == 0 || !isPresize) ? 1 : ::pow(0.1, unit.round)
    return ::g_string.floatToStringRounded(val, roundPrecision)
  })
  local result = separator.join(valuesList)
  if (addMeasureUnits)
    result = "{0} {1}".subst(result, ::loc($"measureUnits/{unit.name}"))
  return result
}

local function isMetricSystem(unitNo)
{
  local unitName = ::get_option_unit_type(unitNo)
  return persistent.unitsCfg[unitNo].findindex(@(u) u.name == unitName) == 0
}

return {
  init = init
  isInitialized = isInitialized
  getOption = getOption
  getMeasureCfg = getMeasureCfg
  countMeasure = countMeasure
  isMetricSystem = isMetricSystem
}
