from "%scripts/dagui_library.nut" import *
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let gamepadIcons = require("%scripts/controls/gamepadIcons.nut")
let { getLocalizedControlName, getShortLocalizedControlName} = require("%scripts/controls/controlsVisual.nut")
let { InputBase } = require("%scripts/controls/input/inputBase.nut")
let { getCurControlsPreset } = require("%scripts/controls/controlsState.nut")

let Button = class (InputBase) {
  deviceId = -1
  buttonId = -1

  preset = null

  constructor(dev, btn, presetV = null) {
    this.deviceId = dev
    this.buttonId = btn
    this.preset = presetV || getCurControlsPreset()
  }

  function getMarkup(hasHoldButtonSign = false) {
    let data = this.getMarkupData(hasHoldButtonSign)
    return handyman.renderCached(data.template, data.view)
  }

  function getMarkupData(hasHoldButtonSign) {
    let data = {
      template = ""
      view = { hasHoldButtonSign }
    }

    if (this.deviceId == JOYSTICK_DEVICE_0_ID && gamepadIcons.hasTextureByButtonIdx(this.buttonId)) {
      data.template = "%gui/gamepadButton.tpl"
      data.view.buttonImage <- gamepadIcons.getTextureByButtonIdx(this.buttonId)
    }
    else if (this.deviceId == STD_MOUSE_DEVICE_ID && gamepadIcons.hasMouseTexture(this.buttonId)) {
      data.template = "%gui/gamepadButton.tpl"
      data.view.buttonImage <- gamepadIcons.getMouseTexture(this.buttonId)
    }
    else {
      data.template = "%gui/keyboardButton.tpl"
      data.view.text <- this.getText()
    }

    return data
  }

  function getText() {
    return getLocalizedControlName(this.preset, this.deviceId, this.buttonId)
  }

  function getTextShort() {
    return getShortLocalizedControlName(this.preset, this.deviceId, this.buttonId)
  }

  function getDeviceId() {
    return this.deviceId
  }

  function getImage() {
    if (this.deviceId == JOYSTICK_DEVICE_0_ID && gamepadIcons.hasTextureByButtonIdx(this.buttonId))
      return gamepadIcons.getTextureByButtonIdx(this.buttonId)
    else if (this.deviceId == STD_MOUSE_DEVICE_ID && gamepadIcons.hasMouseTexture(this.buttonId))
      return gamepadIcons.getMouseTexture(this.buttonId)

    return null
  }

  function hasImage () {
    if (this.deviceId == STD_MOUSE_DEVICE_ID)
      return gamepadIcons.hasMouseTexture(this.buttonId)
    if (this.deviceId == JOYSTICK_DEVICE_0_ID)
      return gamepadIcons.hasTextureByButtonIdx(this.buttonId)
    return false
  }

  function getConfig() {
    return {
      inputName = "button"
      buttonImage = this.getImage()
      text = this.getText()
    }
  }
}
return {Button}