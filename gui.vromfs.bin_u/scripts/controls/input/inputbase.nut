from "%scripts/dagui_library.nut" import *

/**
 * Interface class for all Input classes.
 */
let InputBase = class {

  /**
   * shortcut id for wich this method was created
   * Used mainly for debugging
   */
  shortcutId = ""



  /**
   * Returns markup for impage display of input
   */
  function getMarkup() {
    return ""
  }

  function getMarkupData() {
    return {}
  }


  /**
   * Return text representations of input
   */
  function getText() {
    return ""
  }

  function getTextShort() {
    return this.getText()
  }

  function getDeviceId() {
    return NULL_INPUT_DEVICE_ID
  }


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