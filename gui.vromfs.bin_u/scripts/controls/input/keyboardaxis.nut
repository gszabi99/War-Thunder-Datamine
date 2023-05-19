//checked for plus_string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")

local blockNameByDirection = {
  [AxisDirection.X] = {
    rangeMin = "rightKey"
    rangeMax = "leftKey"
  },
  [AxisDirection.Y] = {
    rangeMin = "downKey"
    rangeMax = "topKey"
  }
}
/**
 * Input keyboard axis.
 * Container for displayed axis keyboard by min-max range
 */
::Input.KeyboardAxis <- class extends ::Input.InputBase {
  elements = null
  isCompositAxis = null

  constructor(v_elements = []) {
    this.elements = v_elements
    this.isCompositAxis = false
  }

  function getMarkup() {
    let data = this.getMarkupData()
    return handyman.renderCached(data.template, data.view)
  }

  function getMarkupData() {
    let view = {}
    local needArrows = !this.isCompositAxis
    foreach (element in this.elements) {
      needArrows = needArrows
        || element.input.getDeviceId() != STD_KEYBOARD_DEVICE_ID
        || !(element.input instanceof ::Input.Button)
      view[blockNameByDirection[this.isCompositAxis ? element.axisDirection : AxisDirection.X][element.postfix]]
        <- element.input.getMarkup()
    }
    let arrows = [{ direction = AxisDirection.X }]
    if (needArrows && this.isCompositAxis)
      arrows.append({ direction = AxisDirection.Y })
    return {
      template = "%gui/controls/input/keyboardAxis.tpl"
      view = view.__merge({
        needArrows = needArrows
        arrows = arrows })
    }
  }

  function getText() {
    return " - ".join(this.elements.map(@(e) e.getText()), true)
  }

  function getDeviceId() {
    if (this.elements.len())
      return this.elements[0].getDeviceId()

    return NULL_INPUT_DEVICE_ID
  }

  function getConfig() {
    let elemConf = {}
    local needArrows = !this.isCompositAxis
    foreach (element in this.elements) {
      needArrows = needArrows
        || element.input.getDeviceId() != STD_KEYBOARD_DEVICE_ID
        || !(element.input instanceof ::Input.Button)
      elemConf[blockNameByDirection[this.isCompositAxis ? element.axisDirection : AxisDirection.X][element.postfix]]
        <- element.input.getConfig()
    }
    let arrows = [{ direction = AxisDirection.X }]
    if (needArrows && this.isCompositAxis)
      arrows.append({ direction = AxisDirection.Y })

    return {
      inputName = "keyboardAxis"
      needArrows = needArrows
      arrows = arrows
      elements = elemConf
    }
  }
}
