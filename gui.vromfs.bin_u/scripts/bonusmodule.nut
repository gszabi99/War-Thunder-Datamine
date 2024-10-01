//-file:plus-string
from "%scripts/dagui_natives.nut" import wp_shop_get_aircraft_wp_rate, wp_shop_get_aircraft_xp_rate
from "%scripts/dagui_library.nut" import *

let { format } = require("string")
let stdMath = require("%sqstd/math.nut")

let allowingMultCountry = [1.5, 2, 2.5, 3, 4, 5]
let allowingMultAircraft = [1.3, 1.5, 2, 2.5, 3, 4, 5, 10]

function findMaxLowerValue(val, list) {
  local res = null
  local found = false
  foreach (v in list) {
    if (v == val)
      return v

    if (v < val) {
      if (!found || v > res)
        res = v
      found = true
      continue
    }
    //v > val
    if (!found && (res == null || v < res))
      res = v
  }
  return res
}

function getBonusImage(bType, multiplier, useBy) {
  if ((bType != "item" && bType != "country") || multiplier == 1.0)
    return ""

  let allowingMult = useBy == "country" ? allowingMultCountry : allowingMultAircraft

  multiplier = findMaxLowerValue(multiplier, allowingMult)
  if (multiplier == null)
    return ""

  multiplier = ::stringReplace(multiplier.tostring(), ".", "_")
  return $"#ui/gameuiskin#{bType}_bonus_mult_{multiplier}"
}

function showCurBonus(obj, value, tooltipLocName = "", isDiscount = true, fullUpdate = false, tooltip = null) {
  if (!checkObj(obj))
    return

  if (value <= 0) {
    obj.show(false)
    return
  }

  obj.show(true)

  local text = ""

  if ((isDiscount && value > 0) || (!isDiscount && value != 1)) {
    text = isDiscount ? "-" + value + "%" : "x" + stdMath.roundToDigits(value, 2)
    if (!tooltip && tooltipLocName != "") {
      let prefix = isDiscount ? "discount/" : "bonus/"
      tooltip = format(loc(prefix + tooltipLocName + "/tooltip"), value.tostring())
    }
  }

  if (text != "") {
    obj.setValue(text)
    if (tooltip)
      obj.tooltip = tooltip
  }
  else if (fullUpdate)
    obj.setValue("")
}

function hideBonus(obj) {
  if (checkObj(obj))
    obj.setValue("")
}

function getBonus(exp, wp, imgType, placeType = "", airName = "") {
  local imgColor = ""
  if (exp > 1.0)
    imgColor = (wp > 1.0) ? "wp_exp" : "exp"
  else
    imgColor = (wp > 1.0) ? "wp" : ""

  exp = stdMath.roundToDigits(exp, 2)
  wp = stdMath.roundToDigits(wp, 2)

  let multiplier = exp > wp ?  exp : wp
  let image = getBonusImage(imgType, multiplier, airName == "" ? "country" : "air")

  local tooltipText = ""
  let locEnd = (type(airName) == "string") ? "/tooltip" : "/group/tooltip"
  if (imgColor != "") {
    tooltipText += exp <= 1.0 ? "" : format(loc("bonus/" + (imgColor == "wp_exp" ? "exp" : imgColor) + imgType + placeType + "Mul" + locEnd),$"x{exp}")
    if (wp > 1)
      tooltipText += ((tooltipText == "") ? "" : "\n") + format(loc("bonus/" + (imgColor == "wp_exp" ? "wp" : imgColor) + imgType + placeType + "Mul" + locEnd),$"x{wp}")
  }

  return {
    bonusType = imgColor
    tooltip = tooltipText,
    ["background-image"] = image
  }
}

function showAirExpWpBonus(obj, airName, showExp = true, showWp = true) {
  if (!obj)
    return

  local exp, wp = 1.0
  if (type(airName) == "string") {
    exp = showExp ? wp_shop_get_aircraft_xp_rate(airName) : 1.0
    wp = showWp ? wp_shop_get_aircraft_wp_rate(airName) : 1.0
  }
  else
    foreach (a in airName) {
      let aexp = showExp ? wp_shop_get_aircraft_xp_rate(a) : 1.0
      if (aexp > exp)
        exp = aexp
      let awp = showWp ? wp_shop_get_aircraft_wp_rate(a) : 1.0
      if (awp > wp)
        wp = awp
    }

  let bonusData = getBonus(exp, wp, "item", "Aircraft", airName)
  foreach (name, result in bonusData)
    obj[name] = result
}

return {
  showCurBonus
  hideBonus
  showAirExpWpBonus
  getBonus
  getBonusImage
}