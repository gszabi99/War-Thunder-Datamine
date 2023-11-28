from "%scripts/dagui_library.nut" import *

let { move_mouse_on_child_by_value } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { getSelectedChild, findChild, findChildIndex } = require("%sqDagui/daguiUtil.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")

gui_handlers.SkipableMsgBox <- class extends gui_handlers.BaseGuiHandlerWT {
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
  defaultBtnId = "btn_cancel"

  function initScreen() {
    this.updateSkipCheckBox()

    this.scene.findObject("msgText").setValue(this.message)
    this.scene.findObject("listText").setValue(this.list)

    let btnSelectObj = this.showSceneBtn("btn_select", this.ableToStartAndSkip)
    if (this.startBtnText != "")
      btnSelectObj.setValue(this.startBtnText)

    this.scene.findObject("btn_cancel")
      .setValue(loc(this.ableToStartAndSkip ? "mainmenu/btnCancel" : "mainmenu/btnOk"))

    let btnListObj = this.scene.findObject("buttons")
    let defBtnId = this.defaultBtnId
    let defBtnIdx = findChildIndex(btnListObj, @(obj) obj.id == defBtnId)
    btnListObj.setValue(defBtnIdx != -1 ? defBtnIdx : 0)
    if (showConsoleButtons.value) {
      this.guiScene.applyPendingChanges(false)
      move_mouse_on_child_by_value(btnListObj)
    }
  }

  function onAcceptSelection() {
    let btnListObj = this.scene.findObject("buttons")
    let btnObj = findChild(btnListObj, @(obj) obj.isHovered()).childObj
      ?? getSelectedChild(btnListObj)
    if (btnObj == null)
      return

    if (btnObj.id == "btn_select") {
      this.onStart()
      return
    }

    this.goBack()
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
