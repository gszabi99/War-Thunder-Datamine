//checked for plus_string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let gamepadIcons = require("%scripts/controls/gamepadIcons.nut")

::Input.DoubleAxis <- class extends ::Input.InputBase {
  //bit mask array of axis ids from ::JoystickParams().getAxis()
  axisIds = null

  deviceId = null

  function getMarkup() {
    let data = this.getMarkupData()
    return ::handyman.renderCached(data.template, data.view)
  }

  function getMarkupData() {
    let data = {
      template = "%gui/shortcutAxis.tpl"
      view = {}
    }

    let image = this.getImage()
    if (image)
      data.view.buttonImage <- image

    return data
  }

  function getText() {
    return ""
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
    }
  }
}
