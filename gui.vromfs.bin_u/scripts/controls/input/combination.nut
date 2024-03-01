from "%scripts/dagui_library.nut" import *

let { handyman } = require("%sqStdLibs/helpers/handyman.nut")

/**
 * Input combination.
 * Container for several elements, which represets single input.
 * It may be a key combination (Ctrl + A) or
 * combinations of several axes (left gamebad trigger + right gamepad trigger.
 */
::Input.Combination <- class (::Input.InputBase) {
  elements = null


  constructor(v_elements = []) {
    this.elements = v_elements
  }

  function getMarkup() {
    let data = this.getMarkupData()
    return handyman.renderCached(data.template, data.view)
  }

  function getMarkupData() {
    let data = {
      template = "%gui/combination.tpl"
      view = { elements = this.elements.map(@(element) { element = element.getMarkup() }) }
    }

    data.view.elements.top().last <- true
    return data
  }

  function getText() {
    let text = []
    foreach (element in this.elements)
      text.append(element.getText())

    return " + ".join(text, true)
  }

  function getDeviceId() {
    if (this.elements.len())
      return this.elements[0].getDeviceId()

    return NULL_INPUT_DEVICE_ID
  }

  function hasImage() {
    if (this.elements.len())
      foreach (item in this.elements)
        if (item.hasImage())
          return true

    return false
  }

  function getConfig() {
    return {
      inputName = "combination"
      text = this.getText()
      elements = this.elements.map(@(element) element.getConfig())
    }
  }

}
