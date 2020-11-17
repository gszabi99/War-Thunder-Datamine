const GAMEPAD_CURSOR_CONTROL_CONFIG_NAME = "use_gamepad_cursor_control"
const IS_GAMEPAD_CURSOR_ENABLED_DEFAULT = true

::g_gamepad_cursor_controls <- {
  currentOptionValue = IS_GAMEPAD_CURSOR_ENABLED_DEFAULT

  function init()
  {
    currentOptionValue = getValue()
    ::get_cur_gui_scene()?.setUseGamepadCursorControl(currentOptionValue)
  }


  function setValue(newValue)
  {
    if (!canChangeValue() || currentOptionValue == newValue)
      return
    ::get_cur_gui_scene()?.setUseGamepadCursorControl(newValue)
    if (::g_login.isProfileReceived())
      ::set_gui_option_in_mode(
        ::USEROPT_GAMEPAD_CURSOR_CONTROLLER,
        newValue,
        ::OPTIONS_MODE_GAMEPLAY
      )
    currentOptionValue = newValue
    ::setSystemConfigOption(GAMEPAD_CURSOR_CONTROL_CONFIG_NAME, currentOptionValue)
    ::handlersManager.checkPostLoadCssOnBackToBaseHandler()
    ::call_darg("updateExtWatched", { gamepadCursorControl = newValue })
  }


  function getValue()
  {
    if (!canChangeValue())
      return IS_GAMEPAD_CURSOR_ENABLED_DEFAULT
    if (!::g_login.isProfileReceived())
      return ::getSystemConfigOption(GAMEPAD_CURSOR_CONTROL_CONFIG_NAME, IS_GAMEPAD_CURSOR_ENABLED_DEFAULT)
    return ::get_gui_option_in_mode(
      ::USEROPT_GAMEPAD_CURSOR_CONTROLLER,
      ::OPTIONS_MODE_GAMEPLAY,
      IS_GAMEPAD_CURSOR_ENABLED_DEFAULT
    )
  }

  function canChangeValue()
  {
    return ::is_mouse_available()
  }

  function onEventProfileUpdated(p)
  {
    if (!::g_login.isLoggedIn())
      setValue(getValue())
  }
}

::subscribe_handler(::g_gamepad_cursor_controls, ::g_listener_priority.CONFIG_VALIDATION)

::g_gamepad_cursor_controls.init()

::cross_call_api.getValueGamepadCursorControl <- @() ::g_gamepad_cursor_controls.getValue()
::cross_call_api.haveXinputDevice <- @() ::have_xinput_device() //FIX ME: remove "haveXinputDevice" when in darg scene will be determined correctly that joystick has controller
