//checked for plus_string
from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")

//checked for explicitness
#no-root-fallback
#explicit-this

let class Popup {
  static POPUP_BLK = "%gui/popup/popup.blk"
  static POPUP_BUTTON_BLK = "%gui/popup/popupButton.blk"

  title = ""
  message = ""

  groupName = null
  lifetime = null

  handler = null
  buttons = []
  selfObj = null
  onClickPopupAction = null

  constructor(config) {
    this.onClickPopupAction = config.onClickPopupAction
    this.buttons = config.buttons || []
    this.handler = config.handler
    this.groupName = config.groupName
    this.title = config.title
    this.message = config.msg
    this.lifetime = config.lifetime
  }

  function isValidView() {
    return checkObj(this.selfObj)
  }

  function show(popupNestObj) {
    popupNestObj.setUserData(this)

    let popupGuiScene = ::get_cur_gui_scene()
    this.selfObj = popupGuiScene.createElementByObject(popupNestObj, this.POPUP_BLK, "popup", this)

    if (!u.isEmpty(this.title))
      this.selfObj.findObject("title").setValue(this.title)
    else
      this.selfObj.findObject("title").show(false)

    this.selfObj.findObject("msg").setValue(this.message)
    this.selfObj["skip-navigation"] = (this.onClickPopupAction == null) ? "yes" : "no"

    let obj = this.selfObj.findObject("popup_buttons_place")
    foreach (button in this.buttons) {
      let buttonObj = popupGuiScene.createElementByObject(obj, this.POPUP_BUTTON_BLK, "Button_text", this)
      buttonObj.id = button.id
      buttonObj.setValue(button.text)
    }

    this.selfObj.setUserData(this)

    if (this.lifetime > 0)
      this.selfObj.timer_interval_msec = this.lifetime.tostring()
  }

  function destroy(isForced = false) {
    if (checkObj(this.selfObj))
      this.selfObj.fade = isForced ? "forced" : "out"
  }

  function requestDestroy(isForced = true) {
    this.destroy(isForced)
    ::g_popups.remove(this)
  }

  function performPopupAction(func) {
    if (!func)
      return
    if (this.handler != null)
      func.call(this.handler)
    else
      func()
  }

  function onClickPopup(_obj) {
    if (this.onClickPopupAction)
      this.performPopupAction(this.onClickPopupAction)
    this.requestDestroy()
  }

  function onRClickPopup(_obj) {
    this.requestDestroy()
  }

  function onClosePopup(_obj) {
    this.requestDestroy()
  }

  function onPopupButtonClick(obj) {
    let id = obj?.id
    let button = this.buttons.findvalue(@(b) b.id == id)
    obj.getScene().performDelayed(this, function() {
      if (!this.isValidView())
        return
      this.performPopupAction(button?.func)
      this.requestDestroy()
    })
  }

  function onTimerUpdate(_obj, _dt) {
    this.requestDestroy(false)
  }
}

return Popup