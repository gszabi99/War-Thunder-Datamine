from "%scripts/dagui_library.nut" import *

let { BaseGuiHandler } = require("%sqDagui/framework/baseGuiHandler.nut")
let { select_editbox, loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { setColoredDoubleTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")

::gui_modal_editbox_wnd <- function gui_modal_editbox_wnd(params) {
  if (!params?.okFunc)
    return

  loadHandler(gui_handlers.EditBoxHandler, params)
}

gui_handlers.EditBoxHandler <- class (BaseGuiHandler) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/editBoxWindow.blk"
  okFunc = null
  cancelFunc = null
  owner = null
  value = null
  maxLen = 0
  multiline = false
  charMask = null
  isPassword = false
  editBoxEnableFunc = null
  editBoxTextOnDisable = null

  title = ""
  label = ""
  leftAlignedLabel = false
  editboxWarningTooltip = ""
  okBtnText = ""
  canCancel = true
  allowEmpty = true
  validateFunc = null //function(value)  return true if valid
  checkButtonFunc = null
  checkWarningFunc = null

  editBoxObj = null
  needOpenIMEonInit = true

  function initScreen() {
    this.scene.findObject("edit_box_window_header").setValue(this.title)
    this.checkWarningFunc = this.checkWarningFunc ?? @(...) true

    this.editBoxObj = showObjById(this.multiline ? "edit_box_window_text_multiline" : "edit_box_window_text", true, this.scene)
    showObjById(this.leftAlignedLabel ? "editbox_label_left_aligned" : "editbox_label", true, this.scene).setValue(this.label)

    let isEnabled = this.editBoxEnableFunc ? this.editBoxEnableFunc() : true
    this.editBoxObj.enable(isEnabled)
    if (this.editBoxTextOnDisable)
      this.editBoxObj["edit-hint"] = isEnabled ? "" : this.editBoxTextOnDisable
    if (this.value)
      this.editBoxObj.setValue(this.value)
    if (this.maxLen)
      this.editBoxObj["max-len"] = this.maxLen.tostring()
    if (this.charMask)
      this.editBoxObj["char-mask"] = this.charMask
    if (this.needOpenIMEonInit)
      this.editBoxObj.setValue(true) //opens IME, not change text.
    if (this.isPassword) {
      this.editBoxObj["type"] = "password"
      this.editBoxObj["password-smb"] = loc("password_mask_char", "*")
    }

    this.updateBtnByValue(this.value || "")
    this.value = null

    if (!this.canCancel && !this.cancelFunc)
      showObjById("btn_back", false, this.scene)

    if (this.okBtnText != "")
      setColoredDoubleTextToButton(this.scene, "btn_ok", this.okBtnText)

    if (isEnabled) {
      this.guiScene.applyPendingChanges(false)
      select_editbox(this.editBoxObj)
    }
  }

  function onChangeValue(obj) {
    let curVal = obj.getValue() || ""
    if (this.validateFunc) {
      let newVal = this.validateFunc(curVal)
      if (newVal != curVal)
        return obj.setValue(newVal)
    }
    this.updateBtnByValue(curVal)
    this.updateWarningByValue(obj, curVal)
  }

  function isApplyEnabled(curVal) {
    return (this.checkButtonFunc == null || this.checkButtonFunc(curVal))
           && (this.allowEmpty || curVal != "")
  }

  function updateBtnByValue(curVal) {
    this.scene.findObject("btn_ok").enable(this.isApplyEnabled(curVal))
  }

  function updateWarningByValue(obj, curVal) {
    let res = !this.checkWarningFunc(curVal)
    obj.warning = res ? "yes" : "no"
    obj.warningText = res ? "yes" : "no"
    obj.tooltip = res ? this.editboxWarningTooltip : ""
  }

  function onOk() {
    this.value = this.editBoxObj.getValue() || ""
    if (this.isApplyEnabled(this.value))
      return this.guiScene.performDelayed(this, this.goBack)

    this.value = null
  }

  function goBack() {
    if (this.value || this.canCancel)
      base.goBack()
    else if (this.cancelFunc)
        ::call_for_handler(this.owner, this.cancelFunc)
  }

  function afterModalDestroy() {
    if (this.value && this.okFunc)
      if (this.owner)
        this.okFunc.call(this.owner, this.value)
      else
        this.okFunc(this.value)

    if (!this.value && this.cancelFunc)
      ::call_for_handler(this.owner, this.cancelFunc)
  }
}
