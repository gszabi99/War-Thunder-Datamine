from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

let gamepadIcons = require("%scripts/controls/gamepadIcons.nut")

::Input.DoubleAxis <- class extends ::Input.InputBase
{
  //bit mask array of axis ids from ::JoystickParams().getAxis()
  axisIds = null

  deviceId = null

  function getMarkup()
  {
    let data = getMarkupData()
    return ::handyman.renderCached(data.template, data.view)
  }

  function getMarkupData()
  {
    let data = {
      template = "%gui/shortcutAxis"
      view = {}
    }

    let image = getImage()
    if (image)
      data.view.buttonImage <- image

    return data
  }

  function getText()
  {
    return ""
  }

  function getDeviceId()
  {
    return deviceId
  }

  function getImage()
  {
    if (deviceId == JOYSTICK_DEVICE_0_ID)
      return gamepadIcons.getGamepadAxisTexture(axisIds)
    else if (deviceId == STD_MOUSE_DEVICE_ID)
      return gamepadIcons.getMouseAxisTexture(axisIds)

    return null
  }

  function hasImage()
  {
    return (getImage() ?? "") != ""
  }

  function getConfig()
  {
    return {
      inputName = "doubleAxis"
      buttonImage = getImage()
    }
  }
}
