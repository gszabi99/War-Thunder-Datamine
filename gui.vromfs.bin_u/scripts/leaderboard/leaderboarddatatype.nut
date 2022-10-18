from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let enums = require("%sqStdLibs/helpers/enums.nut")
let time = require("%scripts/time.nut")
let stdMath = require("%sqstd/math.nut")
let { getPlayerName } = require("%scripts/clientState/platform.nut")

::g_lb_data_type <- {
  types = []
}

::g_lb_data_type_cache <- {
  byId = {}
}

::g_lb_data_type._getStandartTooltip <- function _getStandartTooltip(lbDataType, value)
{
  let shortText = lbDataType.getShortTextByValue(value)
  local fullText = lbDataType.getFullTextByValue(value)
  return fullText != shortText ? (loc("leaderboards/exactValue") + loc("ui/colon") + fullText) : ""
}

::g_lb_data_type.template <- {
  getFullTextByValue = function (value, _allowNegative = false) {
    return value.tostring()
  }

  getShortTextByValue = function (value, allowNegative = false) {
    return getFullTextByValue(value, allowNegative)
  }

  getPrimaryTooltipText = function (_value, _allowNegative = false) {
    return ""
  }

  getAdditionalTooltipPartValueText = function (_value, _hideIfZero)
  {
    return ""
  }
}

enums.addTypesByGlobalName("g_lb_data_type", {
  NUM = {

    getFullTextByValue = function (value, allowNegative = false) {
      if (typeof value == "string")
        value = ::to_integer_safe(value)

      return (!allowNegative && value < 0) ? loc("leaderboards/notAvailable") : value.tostring()
    }

    getShortTextByValue = function (value, allowNegative = false) {
      if (typeof value == "string")
        value = ::to_integer_safe(value)

      return (!allowNegative && value < 0) ? loc("leaderboards/notAvailable") : ::getShortTextFromNum(stdMath.round_by_value(value, 1))
    }

    getPrimaryTooltipText = function (value, allowNegative = false) {
      if (typeof value == "string")
        value = ::to_integer_safe(value)

      return (allowNegative || value >= 0) ? ::g_lb_data_type._getStandartTooltip(this, value) : ""
    }

    getAdditionalTooltipPartValueText = function (value, hideIfZero)
    {
      if (typeof value == "string")
        value = ::to_integer_safe(value)

      return hideIfZero
        ? (value >  0) ? value.tostring () : ""
        : (value >= 0) ? value.tostring () : ""
    }
  }

  FLOAT = {
    getFullTextByValue = function (value, allowNegative = false) {
      if (typeof value == "string")
        value = ::to_float_safe(value)

      return (!allowNegative && value < 0)
        ? loc("leaderboards/notAvailable")
        : stdMath.round_by_value(value, 0.01)
    }
  }

  TIME = {
    getFullTextByValue = function (value, _allowNegative = false) {
      value = time.secondsToHours(value.tofloat())
      local res = time.hoursToString(value)
      return res
    }

    getShortTextByValue = function (value, _allowNegative = false) {
      value = time.secondsToHours(value.tofloat())
      local res = time.hoursToString(value, false)
      return res
    }

    getPrimaryTooltipText = function (value, _allowNegative = false)
    {
      return ::g_lb_data_type._getStandartTooltip(this, value)
    }
  }

  TIME_MIN = {
    getFullTextByValue = function (value, _allowNegative = false) {
      value = time.secondsToMinutes(value.tofloat())
      local res = time.hoursToString(value)
      return res
    }

    getShortTextByValue = function (value, _allowNegative = false) {
      value = time.secondsToMinutes(value.tofloat())
      local res = time.hoursToString(value, false)
      return res
    }

    getPrimaryTooltipText = function (value, _allowNegative = false)
    {
      return ::g_lb_data_type._getStandartTooltip(this, value)
    }
  }

  TIME_MSEC = {
    getFullTextByValue = function (value, _allowNegative = false) {
      value = value.tofloat() / 1000.0
      return time.getRaceTimeFromSeconds(value)
    }
  }

  PERCENT = {
    getFullTextByValue = function (value, _allowNegative = false) {
      return value < 0 ? loc("leaderboards/notAvailable") : (value * 100).tointeger() + "%"
    }

    getPrimaryTooltipText = function (value, _allowNegative = false) {
      return value < 0 ? loc("multiplayer/victories_battles_na_tooltip") : ""
    }
  }

  PLACE = {

    getFullTextByValue = function (value, allowNegative = false) {
      if (typeof value == "string")
        value = ::to_integer_safe(value)

      return (!allowNegative && value < 0) ? loc("leaderboards/notAvailable") : value.tostring()
    }

    getPrimaryTooltipText = function (value, allowNegative = false) {
      if (typeof value == "string")
        value = ::to_integer_safe(value)

      return (!allowNegative && value < 0) ? loc("leaderboards/not_in_leaderboard") : ""
    }
  }

  DATE = {
    getFullTextByValue = function (value, _allowNegative = false) {
      return time.buildDateStr(value)
    }
  }

  ROLE = {
    getFullTextByValue = function (value,  _allowNegative = false) {
      return loc("clan/" + ::clan_get_role_name(value))
    }

    getPrimaryTooltipText = function (value, _allowNegative =false) {
      local res = loc("clan/roleRights")+" \n"
      let rights = ::clan_get_role_rights(value)

      if (rights.len() > 0)
        foreach(right in rights)
          res += "* "+loc("clan/"+right+"_right")+" \n"
      else
        res = loc("clan/noRights")

      return res
    }
  }

  NICK = {
    getFullTextByValue = function (value, _allowNegative = false) {
      return getPlayerName(value.tostring())
    }
  }
  TEXT = {}
  UNKNOWN = {}
})

::g_lb_data_type.getTypeById <- function getTypeById(id)
{
  return enums.getCachedType("id", id, ::g_lb_data_type_cache.byId,
                                       ::g_lb_data_type, ::g_lb_data_type.UNKNOWN)
}
