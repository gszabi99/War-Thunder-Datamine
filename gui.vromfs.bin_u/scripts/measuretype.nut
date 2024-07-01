//-file:plus-string
from "%scripts/dagui_natives.nut" import get_option_unit_type
from "%scripts/dagui_library.nut" import *

let { ceil } = require("math")
let { addTypes, enumsGetCachedType } = require("%sqStdLibs/helpers/enums.nut")
let stdMath = require("%sqstd/math.nut")
let optionsMeasureUnits = require("%scripts/options/optionsMeasureUnits.nut")
let { USEROPT_MEASUREUNITS_SPEED, USEROPT_MEASUREUNITS_ALT, USEROPT_MEASUREUNITS_DIST,
  USEROPT_MEASUREUNITS_CLIMBSPEED, USEROPT_MEASUREUNITS_TEMPERATURE,
  USEROPT_MEASUREUNITS_WING_LOADING, USEROPT_MEASUREUNITS_POWER_TO_WEIGHT_RATIO,
  USEROPT_MEASUREUNITS_RADIAL_SPEED
} = require("%scripts/options/optionsExtNames.nut")
let time = require("%scripts/time.nut")

let measureType = {
  types = []
  cache = {
    byName = {}
  }
  template = {
    name = "" // Same as in measureUnits.blk.
    userOptCode = -1
    orderCode = -1 // Required if userOptCode != -1.
    presize = 0.01 //presize to round by

    getMeasureUnitsName = @() loc(this.getMeasureUnitsLocKey())
    getMeasureUnitsLocKey = @() this.userOptCode != -1
      ? $"measureUnits/{get_option_unit_type(this.orderCode)}"
      : $"measureUnits/{this.name}"
    isMetricSystem = @() this.userOptCode != -1
      ? optionsMeasureUnits.isMetricSystem(this.orderCode)
      : true

    function getMeasureUnitsText(value, addMeasureUnits = true, forceMaxPrecise = false, isPresize = true) {
      if (this.userOptCode != -1)
        return optionsMeasureUnits
          .countMeasure(this.orderCode, value, " - ", addMeasureUnits, forceMaxPrecise, isPresize)

      let result = stdMath.round_by_value(value, this.presize).tostring()
      return addMeasureUnits
        ? $"{result} {this.getMeasureUnitsName()}"
        : result
    }
  }
}

addTypes(measureType, {
  UNKNOWN = {
    name = "unknown"
    getMeasureUnitsText = @(value, ...) value.tostring()
    getMeasureUnitsName = @() ""
  }

  SPEED = {
    name = "speed"
    userOptCode = USEROPT_MEASUREUNITS_SPEED
    orderCode = 0
  }

  SPEED_PER_SEC = { //only m/s atm
    name = "speed_per_sec"
    getMeasureUnitsLocKey = @() "measureUnits/metersPerSecond_climbSpeed"
  }

  ALTITUDE = {
    name = "alt"
    userOptCode = USEROPT_MEASUREUNITS_ALT
    orderCode = 1
  }

  DEPTH = {
    name = "meters_alt"
    presize = 0.1
  }

  DISTANCE = {
    name = "dist"
    userOptCode = USEROPT_MEASUREUNITS_DIST
    orderCode = 2
  }

  DISTANCE_SHORT = {
    name = "dist_short"
    userOptCode = USEROPT_MEASUREUNITS_ALT
    orderCode = 1
  }

  CLIMBSPEED = {
    name = "climbSpeed"
    userOptCode = USEROPT_MEASUREUNITS_CLIMBSPEED
    orderCode = 3
  }

  TEMPERATURE = {
    name = "temperature"
    userOptCode = USEROPT_MEASUREUNITS_TEMPERATURE
    orderCode = 4
  }

  WING_LOADING = {
    name = "wingLoading"
    userOptCode = USEROPT_MEASUREUNITS_WING_LOADING
    orderCode = 5
  }

  POWER_TO_WEIGHT_RATIO = {
    name = "powerToWeightRatio"
    userOptCode = USEROPT_MEASUREUNITS_POWER_TO_WEIGHT_RATIO
    orderCode = 6
  }

  RADIAL_SPEED = {
    name = "radialSpeed"
    userOptCode = USEROPT_MEASUREUNITS_RADIAL_SPEED
    orderCode = 7
  }

  GFORCE = {
    name = "gForce"
    presize = 0.1
    getMeasureUnitsLocKey = @() "HUD_CRIT_OVERLOAD_G"
  }

  HOURS = {
    name = "hours"
    getMeasureUnitsText = @(value, ...) time.hoursToString(value, true)
    getMeasureUnitsLocKey = @() ""
    getMeasureUnitsName = @() ""
  }

  MM = {
    name = "mm"
    presize = 1
  }

  THRUST_KGF = {
    name = "kgf"
    presize = 10
  }

  HORSEPOWERS = {
    name = "hp"
    presize = 1
  }

  SHIP_DISPLACEMENT_TON = {
    name = "ton"
    presize = 0.1
  }

  PERCENT_FLOAT = {
    name = "percent_float"
    getMeasureUnitsText = function(value, addMeasureUnits = true, _forceMaxPrecise = false) {
      return (100.0 * value + 0.5).tointeger() + (addMeasureUnits ? this.getMeasureUnitsName() : "")
    }
    getMeasureUnitsLocKey = @() "measureUnits/percent"
  }

  FILE_SIZE = {
    name = "file_size"
    unitFactorStep = 1024
    unitNamesList = ["KB", "MB", "GB", "TB"]
    function getMeasureUnitsText(value, addMeasureUnits = true, forceMaxPrecise = false) {
      if (forceMaxPrecise || !addMeasureUnits)
        return ceil(value).tointeger() + (addMeasureUnits ? " " + this.getMeasureUnitsName() : "")

      // Start from kilobytes
      local sizeInUnits = ceil(value.tofloat() / this.unitFactorStep)
      local usedUnitIdx = 0
      while (sizeInUnits >= this.unitFactorStep && usedUnitIdx < this.unitNamesList.len() - 1) {
        sizeInUnits = ceil(sizeInUnits.tofloat() / this.unitFactorStep)
        usedUnitIdx++
      }

      return " ".concat(sizeInUnits, loc($"measureUnits/{this.unitNamesList[usedUnitIdx]}"))
    }

    getMeasureUnitsLocKey = @() "measureUnits/bytes"
  }
})

function getMeasureTypeByName(name, createIfNotFound = false) {
  local res = enumsGetCachedType("name", name, measureType.cache.byName,
    measureType, measureType.UNKNOWN)
  if (res == measureType.UNKNOWN && createIfNotFound) {
    res = ::inherit_table(measureType.template, { name })
    measureType.types.append(res)
  }
  return res
}

::g_measure_type <- measureType

::cross_call_api.measureTypes <- measureType

return {
  measureType
  getMeasureTypeByName
}
