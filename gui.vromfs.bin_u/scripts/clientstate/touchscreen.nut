//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { is_touchscreen_enabled } = require("controllerState")

let useTouchscreen = !::is_platform_shield_tv() && is_touchscreen_enabled()

let isSmallScreen = useTouchscreen // FIXME: Touch screen is not always small.

return {
  useTouchscreen
  isSmallScreen
}
