import "%rGui/globals/extWatched.nut" as extWatched
from "%sqstd/string.nut" import floatToStringRounded
from "math" import pow
from "string" import format
from "%rGui/globals/ui_library.nut" import *
from "types" import Array





let measureUnitsCfg = extWatched("measureUnitsCfg", null)

function countMeasure(orderCode, value, separator = " - ", addMeasureUnits = true, forceMaxPrecise = false, isPresize = true) {
  let unit = measureUnitsCfg.get()?[orderCode]
  if (unit == null)
    return ""

  if (!(value instanceof Array))
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


let mkType = @(orderCode) freeze({
  getMeasureUnitsText = @(value, addMeasureUnits = true, forceMaxPrecise = false, isPresize = true)
    countMeasure(orderCode, value, " - ", addMeasureUnits, forceMaxPrecise, isPresize)
  getMeasureUnitsName = @() loc($"measureUnits/{measureUnitsCfg.get()?[orderCode].name ?? ""}")
})

return freeze({
  SPEED = mkType(0)
  ALTITUDE = mkType(1)
  DISTANCE = mkType(2)
  CLIMBSPEED = mkType(3)
  TEMPERATURE = mkType(4)
  WING_LOADING = mkType(5)
  POWER_TO_WEIGHT_RATIO = mkType(6)
  RADIAL_SPEED = mkType(7)
  DISTANCE_SHORT = mkType(8)
  measureUnitsCfg
})
