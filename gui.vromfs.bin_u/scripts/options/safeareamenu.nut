from "%scripts/dagui_library.nut" import *

let screenInfo = require("%scripts/options/screenInfo.nut")
let { isPlatformSony } = require("%scripts/clientState/platform.nut")
let sony = require("sony")
let { is_stereo_mode } = require("vr")
let { useTouchscreen } = require("%scripts/clientState/touchScreen.nut")
let { OPTIONS_MODE_GAMEPLAY, USEROPT_MENU_SCREEN_SAFE_AREA
} = require("%scripts/options/optionsExtNames.nut")
let { getSystemConfigOption, setSystemConfigOption } = require("%globalScripts/systemConfig.nut")
let { isAuthorized } = require("%appGlobals/login/loginState.nut")
let g_font = require("%scripts/options/fonts.nut")
let { get_gui_option_in_mode, set_gui_option_in_mode } = require("%scripts/options/options.nut")

local currentFont = g_font.LARGE

function is_low_width_screen() { //change this function simultaneously with isWide constant in css
  return currentFont.isLowWidthScreen()
}
let getCurrentFont = @() currentFont
let setCurrentFont = @(font) currentFont=font

let defValue  = 1.0
let values    = [ 1.0, 0.95, 0.9 ]
let items     = ["100%", "95%", "90%"]

let getFixedValue = @() //return -1 when not fixed
  is_stereo_mode() ? 0.8
  : isPlatformSony ? sony.getDisplaySafeArea()
  : useTouchscreen ? 0.9
  : is_low_width_screen() ? 1.0
  : -1

let compatibleGetValue = function() {
  let value = !isAuthorized.get() ?
    to_float_safe(getSystemConfigOption("video/safearea", defValue), defValue) :
    get_gui_option_in_mode(USEROPT_MENU_SCREEN_SAFE_AREA, OPTIONS_MODE_GAMEPLAY, defValue)

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
  if (!isAuthorized.get())
    return

  value = isInArray(value, values) ? value : defValue
  setSystemConfigOption("video/safearea", value == defValue ? null : value)
  set_gui_option_in_mode(USEROPT_MENU_SCREEN_SAFE_AREA, value, OPTIONS_MODE_GAMEPLAY)
}

let getValueOptionIndex = @() values.indexof(getValue())

let canChangeValue = @() getFixedValue() == -1

let getSafearea = @() screenInfo.getFinalSafearea(getValue(), screenInfo.getMenuWidthLimit())

let export = {
  is_low_width_screen
  getCurrentFont
  setCurrentFont

  getValue
  setValue
  canChangeValue
  getValueOptionIndex
  getSafearea

  values
  items
  defValue
}

return export
