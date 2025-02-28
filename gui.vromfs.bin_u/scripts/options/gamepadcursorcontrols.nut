from "%scripts/dagui_natives.nut" import is_mouse_available
from "%scripts/dagui_library.nut" import *

let g_listener_priority = require("%scripts/g_listener_priority.nut")
let { subscribe_handler } = require("%sqStdLibs/helpers/subscriptions.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let updateExtWatched = require("%scripts/global/updateExtWatched.nut")
let { OPTIONS_MODE_GAMEPLAY, USEROPT_GAMEPAD_CURSOR_CONTROLLER
} = require("%scripts/options/optionsExtNames.nut")
let { getSystemConfigOption, setSystemConfigOption } = require("%globalScripts/systemConfig.nut")
let { isLoggedIn, isProfileReceived } = require("%appGlobals/login/loginState.nut")
let { get_gui_option_in_mode, set_gui_option_in_mode } = require("%scripts/options/options.nut")

const GAMEPAD_CURSOR_CONTROL_CONFIG_NAME = "use_gamepad_cursor_control"
const IS_GAMEPAD_CURSOR_ENABLED_DEFAULT = true

::g_gamepad_cursor_controls <- {
  currentOptionValue = IS_GAMEPAD_CURSOR_ENABLED_DEFAULT

  function init() {
    this.currentOptionValue = this.getValue()
    get_cur_gui_scene()?.setUseGamepadCursorControl(this.currentOptionValue)
    updateExtWatched({ gamepadCursorControl = this.currentOptionValue })
  }


  function setValue(newValue) {
    if (!this.canChangeValue() || this.currentOptionValue == newValue)
      return
    get_cur_gui_scene()?.setUseGamepadCursorControl(newValue)
    if (isProfileReceived.get())
      set_gui_option_in_mode(
        USEROPT_GAMEPAD_CURSOR_CONTROLLER,
        newValue,
        OPTIONS_MODE_GAMEPLAY
      )
    this.currentOptionValue = newValue
    setSystemConfigOption(GAMEPAD_CURSOR_CONTROL_CONFIG_NAME, this.currentOptionValue)
    handlersManager.checkPostLoadCssOnBackToBaseHandler()
    updateExtWatched({ gamepadCursorControl = newValue })
  }


  function getValue() {
    if (!this.canChangeValue())
      return IS_GAMEPAD_CURSOR_ENABLED_DEFAULT
    if (!isProfileReceived.get())
      return getSystemConfigOption(GAMEPAD_CURSOR_CONTROL_CONFIG_NAME, IS_GAMEPAD_CURSOR_ENABLED_DEFAULT)
    return get_gui_option_in_mode(
      USEROPT_GAMEPAD_CURSOR_CONTROLLER,
      OPTIONS_MODE_GAMEPLAY,
      IS_GAMEPAD_CURSOR_ENABLED_DEFAULT
    )
  }

  function canChangeValue() {
    return false // is_mouse_available()
  }

  function onEventProfileUpdated(_p) {
    if (!isLoggedIn.get())
      this.setValue(this.getValue())
  }
}

subscribe_handler(::g_gamepad_cursor_controls, g_listener_priority.CONFIG_VALIDATION)

::g_gamepad_cursor_controls.init()
