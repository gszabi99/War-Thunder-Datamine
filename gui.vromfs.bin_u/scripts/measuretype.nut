local enums = require("sqStdlibs/helpers/enums.nut")
local stdMath = require("std/math.nut")
local optionsMeasureUnits = require("scripts/options/optionsMeasureUnits.nut")

/**
 * Measure type is a useful abstraction above
 * customizable and hard-coded measure units.
 */

local time = require("scripts/time.nut")


::g_measure_type <- {
  types = []
}

g_measure_type._getMeasureUnitsText <- function _getMeasureUnitsText(value, addMeasureUnits = true, forceMaxPrecise = false)
{
  if (userOptCode != -1)
    return optionsMeasureUnits.countMeasure(orderCode, value, " - ", addMeasureUnits, forceMaxPrecise)
  local result = stdMath.round_by_value(value, presize).tostring()
  if (addMeasureUnits)
    result += " " + getMeasureUnitsName()
  return result
}

g_measure_type._getMeasureUnitsName <- function _getMeasureUnitsName()
{
  local unitName = (userOptCode != -1) ? ::get_option_unit_type(orderCode) : name
  return ::loc(::format("measureUnits/%s", unitName))
}

g_measure_type._isMetricSystem <- function _isMetricSystem()
{
  if (userOptCode != -1)
    return optionsMeasureUnits.isMetricSystem(orderCode)
  return true
}

::g_measure_type.template <- {
  name = "" // Same as in measureUnits.blk.
  userOptCode = -1
  orderCode = -1 // Required if userOptCode != -1.
  presize = 0.01 //presize to round by

  getMeasureUnitsText = ::g_measure_type._getMeasureUnitsText
  getMeasureUnitsName = ::g_measure_type._getMeasureUnitsName
  isMetricSystem      = ::g_measure_type._isMetricSystem
}

enums.addTypesByGlobalName("g_measure_type", {
  UNKNOWN = {
    name = "unknown"

    getMeasureUnitsText = function (value, ...)
    {
      return value.tostring()
    }

    getMeasureUnitsName = function ()
    {
      return ""
    }
  }

  SPEED = {
    name = "speed"
    userOptCode = ::USEROPT_MEASUREUNITS_SPEED
    orderCode = 0
  }

  SPEED_PER_SEC = { //only m/s atm
    name = "speed_per_sec"
    getMeasureUnitsName = function ()
    {
      return ::loc("measureUnits/metersPerSecond_climbSpeed")
    }
  }

  ALTITUDE = {
    name = "alt"
    userOptCode = ::USEROPT_MEASUREUNITS_ALT
    orderCode = 1
  }

  DEPTH = {
    name = "meters_alt"
    presize = 0.1
  }

  DISTANCE = {
    name = "dist"
    userOptCode = ::USEROPT_MEASUREUNITS_DIST
    orderCode = 2
  }

  DISTANCE_SHORT = {
    name = "dist_short"
    userOptCode = ::USEROPT_MEASUREUNITS_ALT
    orderCode = 1
  }

  CLIMBSPEED = {
    name = "climbSpeed"
    userOptCode = ::USEROPT_MEASUREUNITS_CLIMBSPEED
    orderCode = 3
  }

  TEMPERATURE = {
    name = "temperature"
    userOptCode = ::USEROPT_MEASUREUNITS_TEMPERATURE
    orderCode = 4
  }

  WING_LOADING = {
    name = "wingLoading"
    userOptCode = ::USEROPT_MEASUREUNITS_WING_LOADING
    orderCode = 5
  }

  POWER_TO_WEIGHT_RATIO = {
    name = "powerToWeightRatio"
    userOptCode = ::USEROPT_MEASUREUNITS_POWER_TO_WEIGHT_RATIO
    orderCode = 6
  }

  GFORCE = {
    name = "gForce"
    presize = 0.1
    getMeasureUnitsName = @() ::loc("HUD_CRIT_OVERLOAD_G")
  }

  HOURS = {
    name = "hours"

    getMeasureUnitsText = function (value, ...)
    {
      return time.hoursToString(value, false)
    }

    getMeasureUnitsName = function ()
    {
      return ""
    }
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
    getMeasureUnitsText = function(value, addMeasureUnits = true, forceMaxPrecise = false)
    {
      return (100.0 * value + 0.5).tointeger() + (addMeasureUnits? getMeasureUnitsName() : "")
    }

    getMeasureUnitsName = function()
    {
      return ::loc("measureUnits/percent")
    }
  }

  FILE_SIZE = {
    name = "file_size"
    unitFactorStep = 1024
    unitNamesList = ["KB", "MB", "GB", "TB"]
    getMeasureUnitsText = function(value, addMeasureUnits = true, forceMaxPrecise = false)
    {
      if (forceMaxPrecise || !addMeasureUnits)
        return ::ceil(value).tointeger() + (addMeasureUnits ? " " + getMeasureUnitsName() : "")

      // Start from kilobytes
      local sizeInUnits = ::ceil(value.tofloat() / unitFactorStep)

      local usedUnitIdx = 0
      while (sizeInUnits >= unitFactorStep && usedUnitIdx < unitNamesList.len() - 1)
      {
        sizeInUnits = ::ceil(sizeInUnits.tofloat() / unitFactorStep)
        usedUnitIdx++
      }

      return sizeInUnits + " " + ::loc("measureUnits/" + unitNamesList[usedUnitIdx])
    }

    getMeasureUnitsName = function()
    {
      return ::loc("measureUnits/bytes")
    }
  }
})

g_measure_type.getTypeByName <- function getTypeByName(name, createIfNotFound = false)
{
  local res = enums.getCachedType("name", name, ::g_measure_type_cache.byName,
                                      ::g_measure_type, ::g_measure_type.UNKNOWN)
  if (res == UNKNOWN && createIfNotFound)
  {
    res = ::inherit_table(::g_measure_type.template, { name = name })
    types.append(res)
  }
  return res
}

::g_measure_type_cache <- {
  byName = {}
}


::cross_call_api.measureTypes <- ::g_measure_type
