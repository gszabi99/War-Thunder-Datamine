//checked for plus_string
from "%scripts/dagui_library.nut" import *

let screenInfo = require("%scripts/options/screenInfo.nut")
let { isPlatformSony } = require("%scripts/clientState/platform.nut")
let sony = require("sony")
let { is_stereo_mode } = require("vr")
let { useTouchscreen } = require("%scripts/clientState/touchScreen.nut")

let defValue  = 1.0
let values    = [ 1.0, 0.95, 0.9 ]
let items     = ["100%", "95%", "90%"]

let getFixedValue = @() //return -1 when not fixed
  is_stereo_mode() ? 0.8
  : isPlatformSony ? sony.getDisplaySafeArea()
  : useTouchscreen ? 0.9
  : ::is_low_width_screen() ? 1.0
  : -1

let compatibleGetValue = function() {
  let value = !::g_login.isAuthorized() ?
    ::to_float_safe(::getSystemConfigOption("video/safearea", defValue), defValue) :
    ::get_gui_option_in_mode(::USEROPT_MENU_SCREEN_SAFE_AREA, ::OPTIONS_MODE_GAMEPLAY, defValue)

  if (value < 0.5)
    return 1 - value
  return value
}

let getValue = function() {
  local value = getFixedValue()
  if (value != -1)
    return value

  value = compatibleGetValue()
  return isInArray(value, values) ? value : defValue
}

local setValue = function(value) {
  if (!::g_login.isAuthorized())
    return

  value = isInArray(value, values) ? value : defValue
  ::setSystemConfigOption("video/safearea", value == defValue ? null : value)
  ::set_gui_option_in_mode(::USEROPT_MENU_SCREEN_SAFE_AREA, value, ::OPTIONS_MODE_GAMEPLAY)
}

let getValueOptionIndex = @() values.indexof(getValue())

let canChangeValue = @() getFixedValue() == -1

let getSafearea = @() screenInfo.getFinalSafearea(getValue(), screenInfo.getMenuWidthLimit())

let export = {
  getValue = getValue
  setValue = setValue
  canChangeValue = canChangeValue
  getValueOptionIndex = getValueOptionIndex
  getSafearea = getSafearea

  values = values
  items = items
  defValue = defValue
}

return export
