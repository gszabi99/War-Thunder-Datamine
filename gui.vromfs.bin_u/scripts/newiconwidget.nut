//checked for plus_string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")

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

::NewIconWidget <- class {
  widgetContainerTag = "newIconWidget"
  defaultIcon = "#ui/gameuiskin#new_icon.svg"

  _guiScene = null
  _containerObj = null
  _textObj = null
  _iconObj = null

  currentValue = 0
  currentVisibility = false

  icon = null

  constructor(guiScene, containerObj = null) {
    this._guiScene = guiScene
    this.setContainer(containerObj)
  }

  static function createLayout(params = {}) {
    let view = {
      needContainer = getTblValue("needContainer", params, true)
      icon = getTblValue("icon", params, ::NewIconWidget.defaultIcon)
      tooltip = getTblValue("tooltip", params, "")
    }
    return handyman.renderCached("%gui/newIconWidget.tpl", view)
  }

  function setContainer(containerObj) {
    this._containerObj = containerObj
    if (checkObj(this._containerObj)) {
      this._containerObj.setUserData(this.weakref())
      this.update()
    }
  }

  function _updateSubObjects() {
    this._textObj = this._getTextObj()
    this._iconObj = this._getIconObj()
  }

  function isValidContainerData() {
    return checkObj(this._textObj) && checkObj(this._iconObj)
  }

  function validateContent() {
    if (!checkObj(this._containerObj))
      return

    if (this.isValidContainerData())
      return

    let needContainer = this._containerObj?.tag != this.widgetContainerTag
    let data = this.createLayout({
                                needContainer = needContainer
                                icon = this.icon || this.defaultIcon
                              })
    this._guiScene.replaceContentFromText(this._containerObj, data, data.len(), this)

    if (needContainer)
      this.setContainer(this._containerObj.findObject("widget_container"))
    else
      this._updateSubObjects()
  }

  function setText(newText) {
    this.currentValue = newText
    this.update()
  }

  function setValue(value) {
    this.currentValue = value
    this.currentVisibility = value != 0
    this.update()
  }

  function setWidgetVisible(value) {
    this.currentVisibility = value
    this.update()
  }

  function update() {
    this.validateContent()

    if (checkObj(this._textObj)) {
      let newText = (this.currentValue > 0) ? this.currentValue.tostring() : ""
      if (checkObj(this._containerObj)) {
         this._containerObj.widgetClass = (newText == "") ? "" : "text"
         this._containerObj.show(this.currentVisibility)
         this._containerObj.enable(this.currentVisibility)
      }
      this._textObj.setValue(newText)
    }
  }

  function setIcon(newIcon) {
    this.icon = newIcon
    if (checkObj(this._iconObj))
      this._iconObj["background-image"] = this.icon
  }

  function _getTextObj() {
    if (!checkObj(this._containerObj))
      return null
    let obj = this._containerObj.findObject("new_icon_widget_text")
    if (!checkObj(obj))
      return null
    return obj
  }

  function _getIconObj() {
    if (!checkObj(this._containerObj))
      return null
    let obj = this._containerObj.findObject("new_icon_widget_icon")
    return checkObj(obj) ? obj : null
  }

  static function getWidgetByObj(obj) {
    if (!checkObj(obj))
      return null
    let widget = obj.getUserData()
    if (widget == null)
      return null
    if (widget instanceof ::NewIconWidget)
      return widget
    return null
  }
}
