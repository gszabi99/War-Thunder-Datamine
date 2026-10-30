import "sony" as sony
from "%sqstd/platform.nut" import isSony
from "%sqstd/string.nut" import toFloatSafe
from "%appGlobals/options/screenInfo.nut" import getFinalSafearea, getMenuWidthLimit
from "%appGlobals/options/fontTypes.nut" import getPreLoginFontType
from "%appGlobals/clientState/touchScreen.nut" import useTouchscreen
from "%globalScripts/systemConfig.nut" import getSystemConfigOption
from "vr" import is_stereo_mode

const defValue  = 1.0
let values    = [ 1.0, 0.95, 0.9 ]

let getFixedValue = @(font) 
  is_stereo_mode() ? 0.8
  : isSony ? sony.getDisplaySafeArea()
  : useTouchscreen ? 0.9
  : font.isLowWidthScreen() ? 1.0
  : -1

let getConfigValue = @() toFloatSafe(getSystemConfigOption("video/safearea", defValue), defValue, false)

let getValueForFont = function(font, getSavedValue) {
  local value = getFixedValue(font)
  if (value != -1)
    return value

  value = getSavedValue()
  if (value < 0.5)
    value = 1 - value
  return values.contains(value) ? value : defValue
}

let getSafeareaForFont = @(font, getSavedValue) getFinalSafearea(getValueForFont(font, getSavedValue), getMenuWidthLimit())

let getPreLoginSafearea = @() getSafeareaForFont(getPreLoginFontType(), getConfigValue)

return freeze({
  defValue
  values
  getFixedValue
  getConfigValue
  getValueForFont
  getSafeareaForFont
  getPreLoginSafearea
})
