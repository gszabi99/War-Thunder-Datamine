//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { subscribe_handler } = require("%sqStdLibs/helpers/subscriptions.nut")
let updateExtWatched = require("%scripts/global/updateExtWatched.nut")

const GAMEPAD_CURSOR_CONTROL_CONFIG_NAME = "use_gamepad_cursor_control"
const IS_GAMEPAD_CURSOR_ENABLED_DEFAULT = true

::g_gamepad_cursor_controls <- {
  currentOptionValue = IS_GAMEPAD_CURSOR_ENABLED_DEFAULT

  function init() {
    this.currentOptionValue = this.getValue()
    ::get_cur_gui_scene()?.setUseGamepadCursorControl(this.currentOptionValue)
  }


  function setValue(newValue) {
    if (!this.canChangeValue() || this.currentOptionValue == newValue)
      return
    ::get_cur_gui_scene()?.setUseGamepadCursorControl(newValue)
    if (::g_login.isProfileReceived())
      ::set_gui_option_in_mode(
        ::USEROPT_GAMEPAD_CURSOR_CONTROLLER,
        newValue,
        ::OPTIONS_MODE_GAMEPLAY
      )
    this.currentOptionValue = newValue
    ::setSystemConfigOption(GAMEPAD_CURSOR_CONTROL_CONFIG_NAME, this.currentOptionValue)
    ::handlersManager.checkPostLoadCssOnBackToBaseHandler()
    updateExtWatched({ gamepadCursorControl = newValue })
  }


  function getValue() {
    if (!this.canChangeValue())
      return IS_GAMEPAD_CURSOR_ENABLED_DEFAULT
    if (!::g_login.isProfileReceived())
      return ::getSystemConfigOption(GAMEPAD_CURSOR_CONTROL_CONFIG_NAME, IS_GAMEPAD_CURSOR_ENABLED_DEFAULT)
    return ::get_gui_option_in_mode(
      ::USEROPT_GAMEPAD_CURSOR_CONTROLLER,
      ::OPTIONS_MODE_GAMEPLAY,
      IS_GAMEPAD_CURSOR_ENABLED_DEFAULT
    )
  }

  function canChangeValue() {
    return false // ::is_mouse_available()
  }

  function onEventProfileUpdated(_p) {
    if (!::g_login.isLoggedIn())
      this.setValue(this.getValue())
  }
}

subscribe_handler(::g_gamepad_cursor_controls, ::g_listener_priority.CONFIG_VALIDATION)

::g_gamepad_cursor_controls.init()
