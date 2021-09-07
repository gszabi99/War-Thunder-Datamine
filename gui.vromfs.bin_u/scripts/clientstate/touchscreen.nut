local isUseThouchscreen = @() !::is_platform_shield_tv() && ::is_thouchscreen_enabled()

local useTouchscreen = isUseThouchscreen()

local isSmallScreen = useTouchscreen // FIXME: Touch screen is not always small.

return {
  useTouchscreen
  isSmallScreen
}
