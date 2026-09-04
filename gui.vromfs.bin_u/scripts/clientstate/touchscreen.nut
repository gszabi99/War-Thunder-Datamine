from "controllerState" import is_touchscreen_enabled
from "%scripts/dagui_library.nut" import *

let { isPlatformShieldTv } = require("%scripts/clientState/platform.nut")

let useTouchscreen = !isPlatformShieldTv() && is_touchscreen_enabled()

let isSmallScreen = useTouchscreen 

return {
  useTouchscreen
  isSmallScreen
}
