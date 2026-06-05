from "%scripts/dagui_library.nut" import *
from "controls" import ActivationCondition
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let gamepadIcons = require("%scripts/controls/gamepadIcons.nut")
let { getLocalizedControlName, getShortLocalizedControlName, getActivationTypeImg
} = require("%scripts/controls/controlsVisual.nut")
let { InputBase } = require("%scripts/controls/input/inputBase.nut")
let { getCurControlsPreset } = require("%scripts/controls/controlsState.nut")
let { hasXInputDevice } = require("controls")

let Button = class (InputBase) {
  deviceId = -1
  buttonId = -1
  activationType = ActivationCondition.DEFAULT

  preset = null

  constructor(dev, btn, activationType = ActivationCondition.DEFAULT, presetV = null) {
    this.deviceId = dev
    this.buttonId = btn
    this.activationType = activationType
    this.preset = presetV || getCurControlsPreset()
  }

  function getMarkup() {
    let data = this.getMarkupData()
    return handyman.renderCached(data.template, data.view)
  }

  function getMarkupWithoutActivationType() {
    let data = this.getMarkupData()
    data.view.activationTypeImg = null
    return handyman.renderCached(data.template, data.view)
  }

  function getMarkupData() {
    let data = {
      template = ""
      view = { activationTypeImg = getActivationTypeImg(this.activationType) }
    }

    if (this.deviceId == JOYSTICK_DEVICE_0_ID && hasXInputDevice() && gamepadIcons.hasTextureByButtonIdx(this.buttonId)) {
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
      activationTypeImg = getActivationTypeImg(this.activationType)
      buttonImage = this.getImage()
      text = this.getText()
    }
  }

  function getConfigWithoutActivationType() {
    let data = this.getConfig()
    data.activationTypeImg = null
    return data
  }
}
return {Button}