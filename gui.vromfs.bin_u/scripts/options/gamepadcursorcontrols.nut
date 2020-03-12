const GAMEPAD_CURSOR_CONTROL_CONFIG_NAME = "use_gamepad_cursor_control"
const GAMEPAD_CURSOR_CONTROL_SPEED_CONFIG_NAME = "gamepad_cursor_control_speed"
const IS_GAMEPAD_CURSOR_ENABLED_DEFAULT = true
const GAMEPAD_CURSOR_CONTROL_SPEED_DEFAULT = 100

::g_gamepad_cursor_controls <- {
  currentOptionValue = IS_GAMEPAD_CURSOR_ENABLED_DEFAULT
  currentOptionSpeed = GAMEPAD_CURSOR_CONTROL_SPEED_DEFAULT
  isPaused = false


  function init()
  {
    currentOptionValue = getValue()
    ::set_use_gamepad_cursor_control(currentOptionValue)
    if (canChangeSpeed())
    {
      currentOptionSpeed = getSpeed()
      ::set_gamepad_cursor_control_speed(currentOptionSpeed)
    }
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

  function setSpeed(newSpeed)
  {
    if (currentOptionSpeed == newSpeed)
      return
    ::set_gamepad_cursor_control_speed(newSpeed)
    if (::g_login.isProfileReceived())
      ::set_gui_option_in_mode(
        ::USEROPT_GAMEPAD_CURSOR_CONTROLLER_SPEED,
        newSpeed,
        ::OPTIONS_MODE_GAMEPLAY
      )
    currentOptionSpeed = newSpeed
    ::setSystemConfigOption(GAMEPAD_CURSOR_CONTROL_SPEED_CONFIG_NAME, currentOptionSpeed)
    ::handlersManager.checkPostLoadCssOnBackToBaseHandler()
  }

  function getSpeed()
  {
    if (!::g_login.isProfileReceived())
      return ::getSystemConfigOption(GAMEPAD_CURSOR_CONTROL_SPEED_CONFIG_NAME, GAMEPAD_CURSOR_CONTROL_SPEED_DEFAULT)
    if (canChangeValue())
      return ::get_gui_option_in_mode(
        ::USEROPT_GAMEPAD_CURSOR_CONTROLLER_SPEED,
        ::OPTIONS_MODE_GAMEPLAY,
        GAMEPAD_CURSOR_CONTROL_SPEED_DEFAULT
      )
    return GAMEPAD_CURSOR_CONTROL_SPEED_DEFAULT
  }

  function canChangeValue()
  {
    return ::has_feature("GamepadCursorControl") && ::is_mouse_available()
  }

  function canChangeSpeed()
  {
    return canChangeValue() && ::getroottable()?.set_gamepad_cursor_control_speed
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
    {
      setValue(getValue())
      setSpeed(getSpeed())
    }
    else if (isPaused)
      pause(false)
  }
}

::subscribe_handler(::g_gamepad_cursor_controls, ::g_listener_priority.CONFIG_VALIDATION)

::g_gamepad_cursor_controls.init()
