from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

::Input.InputImage <- class extends ::Input.InputBase
{
  image = ""
  constructor(imageName)
  {
    image = imageName
  }

  function getMarkup()
  {
    let data = getMarkupData()
    return ::handyman.renderCached(data.template, data.view)
  }

  function getMarkupData()
  {
    return {
      template = "%gui/gamepadButton"
      view = { buttonImage = image }
    }
  }

  function hasImage ()
  {
    return image !=""
  }

  function getConfig()
  {
    return {
      inputName = "inputImage"
      buttonImage = image
    }
  }
}