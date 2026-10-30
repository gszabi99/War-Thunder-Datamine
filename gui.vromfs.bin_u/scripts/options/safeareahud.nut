import "sony" as sony
from "%sqstd/platform.nut" import is_xbox, isSony
from "%appGlobals/options/screenInfo.nut" import getFinalSafearea, getHudWidthLimit
from "%appGlobals/clientState/touchScreen.nut" import useTouchscreen
from "%scripts/options/optionsExtNames.nut" import OPTIONS_MODE_GAMEPLAY, USEROPT_HUD_SCREEN_SAFE_AREA
from "%scripts/options/options.nut" import set_gui_option_in_mode
from "%appGlobals/login/loginState.nut" import isAuthorized
from "vr" import is_stereo_mode
from "%scripts/dagui_natives.nut" import set_option_hud_screen_safe_area, get_option_hud_screen_safe_area
from "%scripts/dagui_library.nut" import *

const defValue  = 1.0
let values    = [1.0, 0.95, 0.9, 0.85]
let items     = ["100%", "95%", "90%", "85%"]
if (is_xbox) {
  const XBOX_SAFE_AREA = 0.89
  
  for (local i = values.len() - 1; i >= 0; i--) {
    if (values[i] < XBOX_SAFE_AREA) {
      values.remove(i)
      items.remove(i)
    }
  }
}


let getFixedValue = @() 
  is_stereo_mode() ? 1.0
  : isSony ? sony.getDisplaySafeArea()
  : useTouchscreen ? 0.9
  : -1

let getValue = function() {
  let value = getFixedValue()
  if (value != -1)
    return value

  if (!isAuthorized.get())
    return defValue

  return get_option_hud_screen_safe_area()
}

local setValue = function(value) {
  if (!isAuthorized.get())
    return

  value = isInArray(value, values) ? value : defValue
  set_option_hud_screen_safe_area(value)
  set_gui_option_in_mode(USEROPT_HUD_SCREEN_SAFE_AREA, value, OPTIONS_MODE_GAMEPLAY)
}

let getSafearea = @() getFinalSafearea(getValue(), getHudWidthLimit())

return {
  getValue = getValue
  setValue = setValue
  canChangeValue = @() getFixedValue() == -1
  getValueOptionIndex = @() values.indexof(getValue())
  getSafearea = getSafearea

  values = values
  items = items
  defValue = defValue
}
