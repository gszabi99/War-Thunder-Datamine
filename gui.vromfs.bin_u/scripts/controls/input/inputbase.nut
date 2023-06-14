//checked for plus_string
from "%scripts/dagui_library.nut" import *

//All input classes are lives here
::Input <- {}

/**
 * Interface class for all Input classes.
 */
::Input.InputBase <- class {

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
