from "%scripts/dagui_library.nut" import *




let InputBase = class {

  



  shortcutId = ""



  


  function getMarkup(_hasHoldButtonSign = false) {
    return ""
  }

  function getMarkupData() {
    return {}
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