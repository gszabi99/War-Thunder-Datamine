//checked for plus_string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

::Input.InputImage <- class extends ::Input.InputBase {
  image = ""
  constructor(imageName) {
    this.image = imageName
  }

  function getMarkup() {
    let data = this.getMarkupData()
    return ::handyman.renderCached(data.template, data.view)
  }

  function getMarkupData() {
    return {
      template = "%gui/gamepadButton.tpl"
      view = { buttonImage = this.image }
    }
  }

  function hasImage () {
    return this.image != ""
  }

  function getConfig() {
    return {
      inputName = "inputImage"
      buttonImage = this.image
    }
  }
}