from "%scripts/dagui_natives.nut" import is_steam_big_picture, set_dagui_mouse_last_time_used
from "%scripts/dagui_library.nut" import *

let { isPlatformSony, isPlatformXbox, isPlatformShieldTv } = require("%scripts/clientState/platform.nut")
let { handlersManager } = require("%sqDagui/framework/baseGuiHandlerManager.nut")
let updateExtWatched = require("%scripts/global/updateExtWatched.nut")
let { hasXInputDevice } = require("controls")
let { OPTIONS_MODE_GAMEPLAY, USEROPT_ENABLE_CONSOLE_MODE } = require("%scripts/options/optionsExtNames.nut")
let { getSystemConfigOption, setSystemConfigOption } = require("%globalScripts/systemConfig.nut")
let { isProfileReceived } = require("%appGlobals/login/loginState.nut")
let { get_gui_option_in_mode, set_gui_option_in_mode } = require("%scripts/options/options.nut")

let showConsoleButtons = mkWatched(persist, "showConsoleButtons", false)

function getIsConsoleModeForceEnabled() {
  return isPlatformSony
         || isPlatformXbox
         || is_platform_android
         || isPlatformShieldTv()
         || (is_steam_big_picture() && hasXInputDevice())
}

function getIsConsoleModeEnabled() {
  if (getIsConsoleModeForceEnabled())
    return true

  if (isProfileReceived.get())
    return get_gui_option_in_mode(USEROPT_ENABLE_CONSOLE_MODE, OPTIONS_MODE_GAMEPLAY, false)

  return getSystemConfigOption("use_gamepad_interface", false)
}

function switchShowConsoleButtons(showCB) {
  if (getIsConsoleModeForceEnabled() && !showCB)
    return false
  if (showCB == showConsoleButtons.value)
    return false

  showConsoleButtons(showCB)
  updateExtWatched({ showConsoleButtons = showCB })
  set_dagui_mouse_last_time_used(!showCB)

  if (!isProfileReceived.get())
    return true

  set_gui_option_in_mode(USEROPT_ENABLE_CONSOLE_MODE, showCB, OPTIONS_MODE_GAMEPLAY)
  setSystemConfigOption("use_gamepad_interface", showCB)
  handlersManager.markfullReloadOnSwitchScene()
  return true
}

return {
  showConsoleButtons
  getIsConsoleModeForceEnabled
  getIsConsoleModeEnabled
  switchShowConsoleButtons
}