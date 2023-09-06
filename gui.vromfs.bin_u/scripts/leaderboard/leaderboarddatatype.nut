//checked for plus_string
from "%scripts/dagui_library.nut" import *


let enums = require("%sqStdLibs/helpers/enums.nut")
let time = require("%scripts/time.nut")
let stdMath = require("%sqstd/math.nut")
let { getPlayerName } = require("%scripts/clientState/platform.nut")
let { shortTextFromNum } = require("%scripts/langUtils/textFormat.nut")

let function getStandartTooltip(lbDataType, value) {
  let shortText = lbDataType.getShortTextByValue(value)
  let fullText = lbDataType.getFullTextByValue(value)
  return fullText != shortText
    ? "".concat(loc("leaderboards/exactValue"), loc("ui/colon"), fullText)
    : ""
}

let lbDataType = {
  types = []
  template = {
    getFullTextByValue = @(value, _allowNegative = false) value.tostring()
    getShortTextByValue = @(value, allowNegative = false)
      this.getFullTextByValue(value, allowNegative)
    getPrimaryTooltipText = @(_value, _allowNegative = false) ""
    getAdditionalTooltipPartValueText = @(_value, _hideIfZero) ""
  }
}

enums.addTypes(lbDataType, {
  NUM = {
    function getFullTextByValue(value, allowNegative = false) {
      if (type(value) == "string")
        value = ::to_integer_safe(value)

      return (!allowNegative && value < 0)
        ? loc("leaderboards/notAvailable")
        : value.tostring()
    }

    function getShortTextByValue(value, allowNegative = false) {
      if (type(value) == "string")
        value = ::to_integer_safe(value)

      return (!allowNegative && value < 0)
        ? loc("leaderboards/notAvailable")
        : shortTextFromNum(stdMath.round_by_value(value, 1))
    }

    function getPrimaryTooltipText(value, allowNegative = false) {
      if (type(value) == "string")
        value = ::to_integer_safe(value)

      return (allowNegative || value >= 0) ? getStandartTooltip(this, value) : ""
    }

    function getAdditionalTooltipPartValueText(value, hideIfZero) {
      if (type(value) == "string")
        value = ::to_integer_safe(value)

      return hideIfZero
        ? (value >  0) ? value.tostring () : ""
        : (value >= 0) ? value.tostring () : ""
    }
  }

  FLOAT = {
    function getFullTextByValue(value, allowNegative = false) {
      if (type(value) == "string")
        value = ::to_float_safe(value)

      return (!allowNegative && value < 0)
        ? loc("leaderboards/notAvailable")
        : stdMath.round_by_value(value, 0.01)
    }
  }

  TIME = {
    function getFullTextByValue(value, _allowNegative = false) {
      value = time.secondsToHours(value.tofloat())
      return time.hoursToString(value)
    }

    function getShortTextByValue(value, _allowNegative = false) {
      value = time.secondsToHours(value.tofloat())
      return time.hoursToString(value, false)
    }

    function getPrimaryTooltipText(value, _allowNegative = false) {
      return getStandartTooltip(this, value)
    }
  }

  TIME_MIN = {
    function getFullTextByValue(value, _allowNegative = false) {
      value = time.secondsToMinutes(value.tofloat())
      return time.hoursToString(value)
    }

    function getShortTextByValue(value, _allowNegative = false) {
      value = time.secondsToMinutes(value.tofloat())
      return time.hoursToString(value, false)
    }

    function getPrimaryTooltipText(value, _allowNegative = false) {
      return getStandartTooltip(this, value)
    }
  }

  TIME_MSEC = {
    function getFullTextByValue(value, _allowNegative = false) {
      value = value.tofloat() / 1000.0
      return time.getRaceTimeFromSeconds(value)
    }
  }

  PERCENT = {
    function getFullTextByValue(value, _allowNegative = false) {
      return value < 0
        ? loc("leaderboards/notAvailable")
        : "".concat((value * 100 + 0.5).tointeger(), "%")
    }

    function getPrimaryTooltipText(value, _allowNegative = false) {
      return value < 0 ? loc("multiplayer/victories_battles_na_tooltip") : ""
    }
  }

  PLACE = {
    function getFullTextByValue(value, allowNegative = false) {
      if (type(value) == "string")
        value = ::to_integer_safe(value)

      return (!allowNegative && value < 0)
        ? loc("leaderboards/notAvailable")
        : value.tostring()
    }

    function getPrimaryTooltipText(value, allowNegative = false) {
      if (type(value) == "string")
        value = ::to_integer_safe(value)

      return (!allowNegative && value < 0)
        ? loc("leaderboards/not_in_leaderboard")
        : ""
    }
  }

  DATE = {
    function getFullTextByValue(value, _allowNegative = false) {
      return time.buildDateStr(value)
    }
  }

  ROLE = {
    function getFullTextByValue(value,  _allowNegative = false) {
      return loc($"clan/{::clan_get_role_name(value)}")
    }

    function getPrimaryTooltipText(value, _allowNegative = false) {
      local res = "".concat(loc("clan/roleRights"), " \n")
      let rights = ::clan_get_role_rights(value)

      if (rights.len() > 0)
        foreach (right in rights)
          res = "".concat(res, "* ", loc($"clan/{right}_right"), " \n")
      else
        res = loc("clan/noRights")

      return res
    }
  }

  NICK = {
    function getFullTextByValue(value, _allowNegative = false) {
      return getPlayerName(value.tostring())
    }
  }

  TEXT = {}
  UNKNOWN = {}
}, null, null, "lbDataType")

return lbDataType