from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let gamepadIcons = require("%scripts/controls/gamepadIcons.nut")

::Input.Button <- class extends ::Input.InputBase
{
  deviceId = -1
  buttonId = -1

  preset = null

  constructor(dev, btn, presetV = null)
  {
    this.deviceId = dev
    this.buttonId = btn
    this.preset = presetV || ::g_controls_manager.getCurPreset()
  }

  function getMarkup()
  {
    let data = this.getMarkupData()
    return ::handyman.renderCached(data.template, data.view)
  }

  function getMarkupData()
  {
    let data = {
      template = ""
      view = {}
    }

    if (this.deviceId == JOYSTICK_DEVICE_0_ID && gamepadIcons.hasTextureByButtonIdx(this.buttonId))
    {
      data.template = "%gui/gamepadButton.tpl"
      data.view.buttonImage <- gamepadIcons.getTextureByButtonIdx(this.buttonId)
    }
    else if (this.deviceId == STD_MOUSE_DEVICE_ID && gamepadIcons.hasMouseTexture(this.buttonId))
    {
      data.template = "%gui/gamepadButton.tpl"
      data.view.buttonImage <- gamepadIcons.getMouseTexture(this.buttonId)
    }
    else
    {
      data.template = "%gui/keyboardButton.tpl"
      data.view.text <- this.getText()
    }

    return data
  }

  function getText()
  {
    return ::getLocalizedControlName(this.preset, this.deviceId, this.buttonId)
  }

  function getDeviceId()
  {
    return this.deviceId
  }

  function getImage()
  {
    if (this.deviceId == JOYSTICK_DEVICE_0_ID && gamepadIcons.hasTextureByButtonIdx(this.buttonId))
      return gamepadIcons.getTextureByButtonIdx(this.buttonId)
    else if (this.deviceId == STD_MOUSE_DEVICE_ID && gamepadIcons.hasMouseTexture(this.buttonId))
      return gamepadIcons.getMouseTexture(this.buttonId)

    return null
  }

  function hasImage ()
  {
    return gamepadIcons.hasMouseTexture(this.buttonId) || gamepadIcons.hasTextureByButtonIdx(this.buttonId)
  }

  function getConfig()
  {
    return {
      inputName = "button"
      buttonImage = this.getImage()
      text = this.getText()
    }
  }
}
