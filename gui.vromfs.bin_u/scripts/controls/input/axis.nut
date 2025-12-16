from "%scripts/dagui_natives.nut" import joystick_get_default
from "%scripts/dagui_library.nut" import *

let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { AXIS_MODIFIERS, GAMEPAD_AXIS } = require("%scripts/controls/controlsConsts.nut")
let gamepadIcons = require("%scripts/controls/gamepadIcons.nut")
let { InputBase } = require("%scripts/controls/input/inputBase.nut")
let { remapAxisName } = require("%scripts/controls/controlsVisual.nut")
let { getCurControlsPreset } = require("%scripts/controls/controlsState.nut")

let Axis = class (InputBase) {
  
  axisId = null
  
  axisModifier = null
  preset = null

  deviceId = null

  
  
  mouseAxis = null

  
  constructor (deviceAxisDescription, axisMod = AXIS_MODIFIERS.NONE, v_preset = null) {
    this.deviceId = deviceAxisDescription.deviceId
    this.axisId = deviceAxisDescription.axisId
    this.mouseAxis = deviceAxisDescription.mouseAxis
    this.axisModifier = axisMod
    this.preset = v_preset || getCurControlsPreset()
  }

  function getMarkup(_hasHoldButtonSign = false) {
    let data = this.getMarkupData()
    return handyman.renderCached(data.template, data.view)
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
    else if (this.deviceId == STD_MOUSE_DEVICE_ID && this.axisId < 0) {
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
    let device = joystick_get_default()
    if (!device)
      return ""

    return remapAxisName(this.preset, this.axisId)
  }

  function getDeviceId() {
    return this.deviceId
  }

  function getImage() {
    if (this.deviceId == JOYSTICK_DEVICE_0_ID) {
      local axis = GAMEPAD_AXIS.NOT_AXIS
      if (this.axisId >= 0)
        axis = 1 << this.axisId
      return gamepadIcons.getGamepadAxisTexture(axis | this.axisModifier)
    }
    else if (this.deviceId == STD_MOUSE_DEVICE_ID)
      return gamepadIcons.getMouseAxisTexture(this.mouseAxis | this.axisModifier)

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
return {Axis}