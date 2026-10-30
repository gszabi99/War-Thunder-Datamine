import "%scripts/global/updateExtWatched.nut" as updateExtWatched
from "%sqstd/platform.nut" import is_android, isSony, isXbox
from "%appGlobals/clientState/platform.nut" import isPlatformShieldTv
from "%scripts/options/optionsExtNames.nut" import OPTIONS_MODE_GAMEPLAY, USEROPT_ENABLE_CONSOLE_MODE
from "%scripts/options/options.nut" import get_gui_option_in_mode, set_gui_option_in_mode
from "%globalScripts/systemConfig.nut" import getSystemConfigOption, setSystemConfigOption
from "%appGlobals/login/loginState.nut" import isProfileReceived
from "controls" import hasXInputDevice
from "%scripts/dagui_natives.nut" import is_steam_big_picture, set_dagui_mouse_last_time_used
from "%scripts/dagui_library.nut" import *

let { handlersManager } = require("%scripts/sqDagui/framework/baseGuiHandlerManager.nut")

let showConsoleButtons = mkHardPersistWatched("options.consoleMode")("showConsoleButtons", false)

function getIsConsoleModeForceEnabled() {
  return isSony
         || isXbox
         || is_android
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
  if (showCB == showConsoleButtons.get())
    return false

  showConsoleButtons.set(showCB)
  updateExtWatched({ showConsoleButtons = showCB })
  set_dagui_mouse_last_time_used(!showCB)

  if (!isProfileReceived.get())
    return true

  set_gui_option_in_mode(USEROPT_ENABLE_CONSOLE_MODE, showCB, OPTIONS_MODE_GAMEPLAY)
  setSystemConfigOption("use_gamepad_interface", showCB)
  handlersManager.markfullReloadOnSwitchScene()
  return true
}

return freeze({
  showConsoleButtons
  getIsConsoleModeForceEnabled
  getIsConsoleModeEnabled
  switchShowConsoleButtons
})