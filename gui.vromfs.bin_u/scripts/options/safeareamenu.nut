from "%appGlobals/options/safeAreaMenuValue.nut" import defValue, values, getFixedValue, getConfigValue, getValueForFont, getSafeareaForFont
from "%scripts/options/optionsExtNames.nut" import OPTIONS_MODE_GAMEPLAY, USEROPT_MENU_SCREEN_SAFE_AREA
from "%scripts/options/options.nut" import get_gui_option_in_mode, set_gui_option_in_mode
from "%globalScripts/systemConfig.nut" import setSystemConfigOption
from "%appGlobals/login/loginState.nut" import isAuthorized
from "%scripts/dagui_library.nut" import *
from "%scripts/options/fonts.nut" import fontTypes

local currentFont = fontTypes.LARGE

function is_low_width_screen() { 
  return currentFont.isLowWidthScreen()
}
let getCurrentFont = @() currentFont
let setCurrentFont = @(font) currentFont=font

let items     = ["100%", "95%", "90%"]

let getSavedValue = @() !isAuthorized.get() ?
  getConfigValue() :
  get_gui_option_in_mode(USEROPT_MENU_SCREEN_SAFE_AREA, OPTIONS_MODE_GAMEPLAY, defValue)

let getValue = @() getValueForFont(currentFont, getSavedValue)

local setValue = function(value) {
  if (!isAuthorized.get())
    return

  value = isInArray(value, values) ? value : defValue
  setSystemConfigOption("video/safearea", value == defValue ? null : value)
  set_gui_option_in_mode(USEROPT_MENU_SCREEN_SAFE_AREA, value, OPTIONS_MODE_GAMEPLAY)
}

let getValueOptionIndex = @() values.indexof(getValue())

let canChangeValue = @() getFixedValue(currentFont) == -1

let getSafearea = @() getSafeareaForFont(currentFont, getSavedValue)

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
