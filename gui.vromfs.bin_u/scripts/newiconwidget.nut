/*
  widget API:
  static createLayout()  - return widget layout

  setContainer(containerObj) - link current widget to current @containerObj (daguiObj)
  validateContent() - validate current widget container (repaceContent layout on invalid)

  setValue(value)
             @value > 0  - setText value and show widget with text
             @value == 0 - hide widget
             @value < 0  - show only icon
             also validateContent when @value != 0

  setWidgetVisible(value)  - set widget visibility  to @value
  setText(text)            - set widget text to @text
                             @text == ""   - hide widgetText
*/

::NewIconWidget <- class
{
  widgetContainerTag = "newIconWidget"
  defaultIcon = "#ui/gameuiskin#new_icon.svg"

  _guiScene = null
  _containerObj = null
  _textObj = null
  _iconObj = null

  currentValue = 0
  currentVisibility = false

  icon = null

  constructor(guiScene, containerObj = null)
  {
    _guiScene = guiScene
    setContainer(containerObj)
  }

  static function createLayout(params = {})
  {
    let view = {
      needContainer = ::getTblValue("needContainer", params, true)
      icon = ::getTblValue("icon", params, ::NewIconWidget.defaultIcon)
      tooltip = ::getTblValue("tooltip", params, "")
    }
    return ::handyman.renderCached("%gui/newIconWidget", view)
  }

  function setContainer(containerObj)
  {
    _containerObj = containerObj
    if (::check_obj(_containerObj))
    {
      _containerObj.setUserData(this.weakref())
      update()
    }
  }

  function _updateSubObjects()
  {
    _textObj = _getTextObj()
    _iconObj = _getIconObj()
  }

  function isValidContainerData()
  {
    return ::check_obj(_textObj) && ::check_obj(_iconObj)
  }

  function validateContent()
  {
    if (!::check_obj(_containerObj))
      return

    if (isValidContainerData())
      return

    let needContainer = _containerObj?.tag != widgetContainerTag
    let data = createLayout({
                                needContainer = needContainer
                                icon = icon || defaultIcon
                              })
    _guiScene.replaceContentFromText(_containerObj, data, data.len(), this)

    if (needContainer)
      setContainer(_containerObj.findObject("widget_container"))
    else
      _updateSubObjects()
  }

  function setText(newText)
  {
    currentValue = newText
    update()
  }

  function setValue(value)
  {
    currentValue = value
    currentVisibility = value != 0
    update()
  }

  function setWidgetVisible(value)
  {
    currentVisibility = value
    update()
  }

  function update()
  {
    validateContent()

    if (::check_obj(_textObj))
    {
      let newText = (currentValue > 0) ? currentValue.tostring() : ""
      if (::check_obj(_containerObj))
      {
         _containerObj.widgetClass = (newText == "") ? "" : "text"
         _containerObj.show(currentVisibility)
         _containerObj.enable(currentVisibility)
      }
      _textObj.setValue(newText)
    }
  }

  function setIcon(newIcon)
  {
    icon = newIcon
    if (::check_obj(_iconObj))
      _iconObj["background-image"] = icon
  }

  function _getTextObj()
  {
    if (!::check_obj(_containerObj))
      return null
    let obj = _containerObj.findObject("new_icon_widget_text")
    if (!::check_obj(obj))
      return null
    return obj
  }

  function _getIconObj()
  {
    if (!::check_obj(_containerObj))
      return null
    let obj = _containerObj.findObject("new_icon_widget_icon")
    return ::check_obj(obj) ? obj : null
  }

  static function getWidgetByObj(obj)
  {
    if (!::check_obj(obj))
      return null
    let widget = obj.getUserData()
    if (widget == null)
      return null
    if (widget instanceof NewIconWidget)
      return widget
    return null
  }
}
