from "%scripts/dagui_library.nut" import *

let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { InputBase } = require("%scripts/controls/input/inputBase.nut")







let Combination = class (InputBase) {
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

  function getTextShort() {
    let text = []
    foreach (element in this.elements)
      text.append(element.getTextShort())

    return " + ".join(text, true)
  }

  function getDeviceId() {
    if (this.elements.len())
      return this.elements[0].getDeviceId()

    return NULL_INPUT_DEVICE_ID
  }

  function isUseDevice(devicesList) {
    foreach (element in this.elements)
      if (element.isUseDevice(devicesList))
        return true
    return false
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
return {Combination}