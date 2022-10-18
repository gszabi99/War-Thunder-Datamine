from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let u = require("%sqStdLibs/helpers/u.nut")

/**
 * Input combination.
 * Container for several elements, which represets single input.
 * It may be a key combination (Ctrl + A) or
 * combinations of several axes (left gamebad trigger + right gamepad trigger.
 */
::Input.Combination <- class extends ::Input.InputBase
{
  elements = null


  constructor(v_elements = [])
  {
    elements = v_elements
  }

  function getMarkup()
  {
    let data = getMarkupData()
    return ::handyman.renderCached(data.template, data.view)
  }

  function getMarkupData()
  {
    let data = {
      template = "%gui/combination"
      view = { elements = u.map(elements, @(element) { element = element.getMarkup()}) }
    }

    data.view.elements.top().last <- true
    return data
  }

  function getText()
  {
    let text = []
    foreach (element in elements)
      text.append(element.getText())

    return ::g_string.implode(text, " + ")
  }

  function getDeviceId()
  {
    if (elements.len())
      return elements[0].getDeviceId()

    return NULL_INPUT_DEVICE_ID
  }

  function hasImage()
  {
    if (elements.len())
      foreach (item in elements)
        if (item.hasImage())
          return true

    return false
  }

  function getConfig()
  {
    return {
      inputName = "combination"
      text = getText()
      elements = u.map(elements, @(element) element.getConfig())
    }
  }

}
