class ::Input.InputImage extends ::Input.InputBase
{
  image = ""
  constructor(imageName)
  {
    image = imageName
  }

  function getMarkup()
  {
    local data = getMarkupData()
    return ::handyman.renderCached(data.template, data.view)
  }

  function getMarkupData()
  {
    return {
      template = "gui/gamepadButton"
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