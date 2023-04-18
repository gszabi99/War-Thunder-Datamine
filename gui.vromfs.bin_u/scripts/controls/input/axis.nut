//checked for plus_string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let gamepadIcons = require("%scripts/controls/gamepadIcons.nut")

::Input.Axis <- class extends ::Input.InputBase {
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
  constructor (deviceAxisDescription, axisMod = AXIS_MODIFIERS.NONE, v_preset = null) {
    this.deviceId = deviceAxisDescription.deviceId
    this.axisId = deviceAxisDescription.axisId
    this.mouseAxis = deviceAxisDescription.mouseAxis
    this.axisModifyer = axisMod
    this.preset = v_preset || ::g_controls_manager.getCurPreset()
  }

  function getMarkup() {
    let data = this.getMarkupData()
    return ::handyman.renderCached(data.template, data.view)
  }

  function getMarkupData() {
    let data = {
      template = ""
      view = {}
    }

    if (this.deviceId == JOYSTICK_DEVICE_0_ID) {
      data.view.buttonImage <- this.getImage()
      data.template = "%gui/shortcutAxis.tpl"
    }
    else if (this.deviceId == STD_MOUSE_DEVICE_ID) {
      data.view.buttonImage <- this.getImage()
      data.template = "%gui/shortcutAxis.tpl"
    }
    else {
      data.view.text <- this.getText()
      data.template = "%gui/keyboardButton.tpl"
    }

    return data
  }

  function getText() {
    let device = ::joystick_get_default()
    if (!device)
      return ""

    return ::remapAxisName(this.preset, this.axisId)
  }

  function getDeviceId() {
    return this.deviceId
  }

  function getImage() {
    if (this.deviceId == JOYSTICK_DEVICE_0_ID) {
      local axis = GAMEPAD_AXIS.NOT_AXIS
      if (this.axisId >= 0)
        axis = 1 << this.axisId
      return gamepadIcons.getGamepadAxisTexture(axis | this.axisModifyer)
    }
    else if (this.deviceId == STD_MOUSE_DEVICE_ID)
      return gamepadIcons.getMouseAxisTexture(this.mouseAxis | this.axisModifyer)

    return null
  }

  function hasImage() {
    return (this.getImage() ?? "") != ""
  }

  function getConfig() {
    return {
      inputName = "axis"
      buttonImage = this.getImage()
      text = this.getText()
    }
  }
}
