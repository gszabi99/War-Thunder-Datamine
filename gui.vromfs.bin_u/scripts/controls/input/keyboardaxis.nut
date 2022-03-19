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
class ::Input.KeyboardAxis extends ::Input.InputBase
{
  elements = null
  isCompositAxis = null

  constructor(_elements = [])
  {
    elements = _elements
    isCompositAxis = false
  }

  function getMarkup()
  {
    local data = getMarkupData()
    return ::handyman.renderCached(data.template, data.view)
  }

  function getMarkupData()
  {
    local view = {}
    local needArrows = !isCompositAxis
    foreach (element in elements)
    {
      needArrows = needArrows
        || element.input.getDeviceId() != ::STD_KEYBOARD_DEVICE_ID
        || !(element.input instanceof ::Input.Button)
      view[blockNameByDirection[isCompositAxis ? element.axisDirection : AxisDirection.X][element.postfix]]
        <- element.input.getMarkup()
    }
    local arrows = [{direction = AxisDirection.X}]
    if (needArrows && isCompositAxis)
      arrows.append({direction = AxisDirection.Y})
    return {
      template = "gui/controls/input/keyboardAxis"
      view = view.__merge({
        needArrows = needArrows
        arrows = arrows})
    }
  }

  function getText()
  {
    return ::g_string.implode(elements.map(@(e) e.getText()), " - ")
  }

  function getDeviceId()
  {
    if (elements.len())
      return elements[0].getDeviceId()

    return ::NULL_INPUT_DEVICE_ID
  }

  function getConfig()
  {
    local elemConf = {}
    local needArrows = !isCompositAxis
    foreach (element in elements)
    {
      needArrows = needArrows
        || element.input.getDeviceId() != ::STD_KEYBOARD_DEVICE_ID
        || !(element.input instanceof ::Input.Button)
      elemConf[blockNameByDirection[isCompositAxis ? element.axisDirection : AxisDirection.X][element.postfix]]
        <- element.input.getConfig()
    }
    local arrows = [{direction = AxisDirection.X}]
    if (needArrows && isCompositAxis)
      arrows.append({direction = AxisDirection.Y})

    return {
      inputName = "keyboardAxis"
      needArrows = needArrows
      arrows = arrows
      elements = elemConf
    }
  }
}
