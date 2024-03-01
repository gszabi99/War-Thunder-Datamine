from "%scripts/dagui_natives.nut" import set_option_hud_screen_safe_area, get_option_hud_screen_safe_area
from "%scripts/dagui_library.nut" import *

let screenInfo = require("%scripts/options/screenInfo.nut")
let { isPlatformSony } = require("%scripts/clientState/platform.nut")
let sony = require("sony")
let { is_stereo_mode } = require("vr")
let { useTouchscreen } = require("%scripts/clientState/touchScreen.nut")
let { OPTIONS_MODE_GAMEPLAY, USEROPT_HUD_SCREEN_SAFE_AREA
} = require("%scripts/options/optionsExtNames.nut")

let defValue  = 1.0
let values    = [1.0, 0.95, 0.9, 0.85]
let items     = ["100%", "95%", "90%", "85%"]
if (is_platform_xbox) {
  const XBOX_SAFE_AREA = 0.89
  // so remove all below of it to fit in.
  for (local i = values.len() - 1; i >= 0; i--) {
    if (values[i] < XBOX_SAFE_AREA) {
      values.remove(i)
      items.remove(i)
    }
  }
}


let getFixedValue = @() //return -1 when not fixed
  is_stereo_mode() ? 1.0
  : isPlatformSony ? sony.getDisplaySafeArea()
  : useTouchscreen ? 0.9
  : -1

let getValue = function() {
  let value = getFixedValue()
  if (value != -1)
    return value

  if (!::g_login.isAuthorized())
    return defValue

  return get_option_hud_screen_safe_area()
}

local setValue = function(value) {
  if (!::g_login.isAuthorized())
    return

  value = isInArray(value, values) ? value : defValue
  set_option_hud_screen_safe_area(value)
  ::set_gui_option_in_mode(USEROPT_HUD_SCREEN_SAFE_AREA, value, OPTIONS_MODE_GAMEPLAY)
}

let getSafearea = @() screenInfo.getFinalSafearea(getValue(), screenInfo.getHudWidthLimit())

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
