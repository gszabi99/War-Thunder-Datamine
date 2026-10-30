from "%sqStdLibs/helpers/handyman.nut" import handyman
from "%scripts/controls/controlsConsts.nut" import AXIS_MODIFIERS, GAMEPAD_AXIS
from "%scripts/controls/input/inputBase.nut" import InputBase
from "%scripts/controls/controlsVisual.nut" import remapAxisName
from "%scripts/controls/controlsState.nut" import getCurControlsPreset
from "%globalScripts/inputDeviceConsts.nut" import *
from "%scripts/dagui_natives.nut" import joystick_get_default
from "%scripts/dagui_library.nut" import *

let gamepadIcons = require("%scripts/controls/gamepadIcons.nut")

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

  function getMarkup() {
    let data = this.getMarkupData()
    return handyman.renderCached(data.template, data.view)
  }

  function getMarkupData() {
    let canShowIcon = this.deviceId == JOYSTICK_DEVICE_0_ID
      || (this.deviceId == STD_MOUSE_DEVICE_ID && this.axisId < 0) 
    return this.getAxisMarkupData(canShowIcon ? this.getImage() : null)
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
return freeze({Axis})