from "%sqStdLibs/helpers/handyman.nut" import handyman
from "%scripts/controls/input/inputBase.nut" import InputBase
from "%globalScripts/inputDeviceConsts.nut" import *
from "%scripts/dagui_library.nut" import *

let gamepadIcons = require("%scripts/controls/gamepadIcons.nut")

let DoubleAxis = class (InputBase) {
  
  axisIds = null

  deviceId = null

  text = ""

  function getMarkup() {
    let data = this.getMarkupData()
    return handyman.renderCached(data.template, data.view)
  }

  function getMarkupData() {
    return this.getAxisMarkupData(this.getImage())
  }

  function getText() {
    return this.text
  }

  function getDeviceId() {
    return this.deviceId
  }

  function getImage() {
    if (this.deviceId == JOYSTICK_DEVICE_0_ID)
      return gamepadIcons.getGamepadAxisTexture(this.axisIds)
    else if (this.deviceId == STD_MOUSE_DEVICE_ID)
      return gamepadIcons.getMouseAxisTexture(this.axisIds)

    return null
  }

  function hasImage() {
    return (this.getImage() ?? "") != ""
  }

  function getConfig() {
    return {
      inputName = "doubleAxis"
      buttonImage = this.getImage()
      text = this.getText()
    }
  }
}
return freeze({DoubleAxis})