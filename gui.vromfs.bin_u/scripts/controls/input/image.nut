from "%scripts/dagui_library.nut" import *

let { handyman } = require("%sqStdLibs/helpers/handyman.nut")

::Input.InputImage <- class (::Input.InputBase) {
  image = ""
  constructor(imageName) {
    this.image = imageName
  }

  function getMarkup() {
    let data = this.getMarkupData()
    return handyman.renderCached(data.template, data.view)
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