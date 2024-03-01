from "%scripts/dagui_library.nut" import *

let { is_touchscreen_enabled } = require("controllerState")
let { isPlatformShieldTv } = require("%scripts/clientState/platform.nut")

let useTouchscreen = !isPlatformShieldTv() && is_touchscreen_enabled()

let isSmallScreen = useTouchscreen // FIXME: Touch screen is not always small.

return {
  useTouchscreen
  isSmallScreen
}
