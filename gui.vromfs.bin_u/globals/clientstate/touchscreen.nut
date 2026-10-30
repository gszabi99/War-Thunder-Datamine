from "%appGlobals/clientState/platform.nut" import isPlatformShieldTv
from "controllerState" import is_touchscreen_enabled

let useTouchscreen = !isPlatformShieldTv() && is_touchscreen_enabled()

let isSmallScreen = useTouchscreen 

return freeze({
  useTouchscreen
  isSmallScreen
})
