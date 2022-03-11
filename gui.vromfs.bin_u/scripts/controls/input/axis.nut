let gamepadIcons = require("scripts/controls/gamepadIcons.nut")

::Input.Axis <- class extends ::Input.InputBase
{
  //from ::JoystickParams().getAxis()
  axisId = null
  //AXIS_MODIFIERS
  axisModifyer = null
  preset = null

  deviceId = null

  //its impossible to determine mouse axis without shortcut id
  //so we cache it on construction to not to keep shortcut id all the time
  mouseAxis = null

  // @deviceAxisDescription is a result of g_shortcut_type::_getDeviceAxisDescription
  constructor (deviceAxisDescription, axisMod = AXIS_MODIFIERS.NONE, _preset = null)
  {
    deviceId = deviceAxisDescription.deviceId
    axisId = deviceAxisDescription.axisId
    mouseAxis = deviceAxisDescription.mouseAxis
    axisModifyer = axisMod
    preset = _preset || ::g_controls_manager.getCurPreset()
  }

  function getMarkup()
  {
    let data = getMarkupData()
    return ::handyman.renderCached(data.template, data.view)
  }

  function getMarkupData()
  {
    let data = {
      template = ""
      view = {}
    }

    if (deviceId == ::JOYSTICK_DEVICE_0_ID)
    {
      data.view.buttonImage <- getImage()
      data.template = "%gui/shortcutAxis"
    }
    else if (deviceId == ::STD_MOUSE_DEVICE_ID)
    {
      data.view.buttonImage <- getImage()
      data.template = "%gui/shortcutAxis"
    }
    else
    {
      data.view.text <- getText()
      data.template = "%gui/keyboardButton"
    }

    return data
  }

  function getText()
  {
    let device = ::joystick_get_default()
    if (!device)
      return ""

    return ::remapAxisName(preset, axisId)
  }

  function getDeviceId()
  {
    return deviceId
  }

  function getImage()
  {
    if (deviceId == ::JOYSTICK_DEVICE_0_ID)
    {
      local axis = GAMEPAD_AXIS.NOT_AXIS
      if (axisId >= 0)
        axis = 1 << axisId
      return gamepadIcons.getGamepadAxisTexture(axis | axisModifyer)
    }
    else if (deviceId == ::STD_MOUSE_DEVICE_ID)
      return gamepadIcons.getMouseAxisTexture(mouseAxis | axisModifyer)

    return null
  }

  function hasImage()
  {
    return (getImage() ?? "") != ""
  }

  function getConfig()
  {
    return {
      inputName = "axis"
      buttonImage = getImage()
      text = getText()
    }
  }
}
