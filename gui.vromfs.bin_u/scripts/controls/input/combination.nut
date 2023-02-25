//checked for plus_string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let u = require("%sqStdLibs/helpers/u.nut")

/**
 * Input combination.
 * Container for several elements, which represets single input.
 * It may be a key combination (Ctrl + A) or
 * combinations of several axes (left gamebad trigger + right gamepad trigger.
 */
::Input.Combination <- class extends ::Input.InputBase {
  elements = null


  constructor(v_elements = []) {
    this.elements = v_elements
  }

  function getMarkup() {
    let data = this.getMarkupData()
    return ::handyman.renderCached(data.template, data.view)
  }

  function getMarkupData() {
    let data = {
      template = "%gui/combination.tpl"
      view = { elements = u.map(this.elements, @(element) { element = element.getMarkup() }) }
    }

    data.view.elements.top().last <- true
    return data
  }

  function getText() {
    let text = []
    foreach (element in this.elements)
      text.append(element.getText())

    return ::g_string.implode(text, " + ")
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
      elements = u.map(this.elements, @(element) element.getConfig())
    }
  }

}
