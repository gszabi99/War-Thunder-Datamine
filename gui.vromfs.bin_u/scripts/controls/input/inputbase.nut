from "%globalScripts/inputDeviceConsts.nut" import *
from "%scripts/dagui_library.nut" import *




let InputBase = class {

  



  shortcutId = ""



  


  function getMarkup() {
    return ""
  }

  function getMarkupData() {
    return {}
  }

  function getAxisMarkupData(image) {
    if ((image ?? "") == "")
      return {
        template = "%gui/keyboardButton.tpl"
        view = { text = this.getText() }
      }

    return {
      template = "%gui/shortcutAxis.tpl"
      view = { buttonImage = image }
    }
  }


  


  function getText() {
    return ""
  }

  function getTextShort() {
    return this.getText()
  }

  function getDeviceId() {
    return NULL_INPUT_DEVICE_ID
  }

  isUseDevice = @(devicesList) this.getDeviceId() in devicesList

  function hasImage () {
    return false
  }

  function getConfig() {
    return { inputName = "inputBase" }
  }
}

return {
  InputBase
}