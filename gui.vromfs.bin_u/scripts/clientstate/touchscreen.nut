from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let isUseThouchscreen = @() !::is_platform_shield_tv() && ::is_thouchscreen_enabled()

let useTouchscreen = isUseThouchscreen()

let isSmallScreen = useTouchscreen // FIXME: Touch screen is not always small.

return {
  useTouchscreen
  isSmallScreen
}
