const GAMEPAD_CURSOR_CONTROL_CONFIG_NAME = "use_gamepad_cursor_control"
const IS_GAMEPAD_CURSOR_ENABLED_DEFAULT = true

::g_gamepad_cursor_controls <- {
  currentOptionValue = IS_GAMEPAD_CURSOR_ENABLED_DEFAULT
  isPaused = false


  function init()
  {
    currentOptionValue = getValue()
    ::set_use_gamepad_cursor_control(currentOptionValue)
  }


  function setValue(newValue)
  {
    if (currentOptionValue == newValue)
      return
    ::set_use_gamepad_cursor_control(newValue)
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
    if (!::g_login.isProfileReceived())
      return ::getSystemConfigOption(GAMEPAD_CURSOR_CONTROL_CONFIG_NAME, IS_GAMEPAD_CURSOR_ENABLED_DEFAULT)
    if (canChangeValue())
      return ::get_gui_option_in_mode(
        ::USEROPT_GAMEPAD_CURSOR_CONTROLLER,
        ::OPTIONS_MODE_GAMEPLAY,
        IS_GAMEPAD_CURSOR_ENABLED_DEFAULT
      )
    return IS_GAMEPAD_CURSOR_ENABLED_DEFAULT
  }

  function canChangeValue()
  {
    return ::has_feature("GamepadCursorControl") && ::is_mouse_available()
  }

  function pause(isPause)
  {
    local shouldPause = canChangeValue() && getValue()
    if (shouldPause || (isPaused && !isPause))
      isPaused = isPause
    if (shouldPause)
      ::set_use_gamepad_cursor_control(!isPause)
  }

  function onEventProfileUpdated(p)
  {
    if (!::g_login.isLoggedIn())
      setValue(getValue())
    else if (isPaused)
      pause(false)
  }
}

::subscribe_handler(::g_gamepad_cursor_controls, ::g_listener_priority.CONFIG_VALIDATION)

::g_gamepad_cursor_controls.init()

::cross_call_api.getValueGamepadCursorControl <- @() ::g_gamepad_cursor_controls.getValue()
::cross_call_api.haveXinputDevice <- @() ::have_xinput_device() //FIX ME: remove "haveXinputDevice" when in darg scene will be determined correctly that joystick has controller
