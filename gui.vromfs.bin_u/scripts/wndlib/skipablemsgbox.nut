//checked for plus_string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { setDoubleTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")


::gui_handlers.SkipableMsgBox <- class extends ::gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/weaponry/skipableMsgBox.blk"

  parentHandler = null
  onStartPressed = null
  cancelFunc = null
  skipFunc = null
  isCanceled = true
  isStarted = false

  message = ""
  list = ""
  startBtnText = ""
  ableToStartAndSkip = true

  function initScreen() {
    this.updateSkipCheckBox()

    let msgTextObj = this.scene.findObject("msgText")
    if (checkObj(msgTextObj))
      msgTextObj.setValue(this.message)

    let listTextObj = this.scene.findObject("listText")
    if (checkObj(listTextObj))
      listTextObj.setValue(this.list)

    let btnSelectObj = this.scene.findObject("btn_select")
    if (checkObj(btnSelectObj))
      btnSelectObj.show(this.ableToStartAndSkip)

    let btnCancelObj = this.scene.findObject("btn_cancel")
    if (checkObj(btnCancelObj))
      btnCancelObj.setValue(loc(this.ableToStartAndSkip ? "mainmenu/btnCancel" : "mainmenu/btnOk"))

    if (this.startBtnText != "")
      setDoubleTextToButton(this.scene, "btn_select", this.startBtnText)
  }

  function updateSkipCheckBox() {
    let skipObj = this.scene.findObject("skip_this")
    if (checkObj(skipObj)) {
      skipObj.show(this.ableToStartAndSkip && this.skipFunc)
      skipObj.enable(this.ableToStartAndSkip && this.skipFunc)
    }
  }

  function onSkipMessageBox(obj) {
    if (!obj)
      return

    if (this.skipFunc)
      this.skipFunc(obj.getValue())
  }

  function onStart() {
    this.isCanceled = false
    if (this.parentHandler && this.onStartPressed)
      this.isStarted = true

    this.goBack()
  }

  function afterModalDestroy() {
    if (this.isCanceled)
      ::call_for_handler(this.parentHandler, this.cancelFunc)
    if (this.isStarted)
      ::call_for_handler(this.parentHandler, this.onStartPressed)
  }
}
