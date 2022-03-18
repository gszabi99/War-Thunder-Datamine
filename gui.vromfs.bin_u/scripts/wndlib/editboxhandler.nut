let { setColoredDoubleTextToButton } = require("scripts/viewUtils/objectTextUpdate.nut")

::gui_modal_editbox_wnd <- function gui_modal_editbox_wnd(params)
{
  if (!params?.okFunc)
    return

  ::gui_start_modal_wnd(::gui_handlers.EditBoxHandler, params)
}

::gui_handlers.EditBoxHandler <- class extends ::BaseGuiHandler
{
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

  function initScreen()
  {
    scene.findObject("edit_box_window_header").setValue(title)
    checkWarningFunc = checkWarningFunc ?? @(...) true

    editBoxObj = showSceneBtn(multiline ? "edit_box_window_text_multiline" : "edit_box_window_text", true)
    showSceneBtn(leftAlignedLabel ? "editbox_label_left_aligned" : "editbox_label", true).setValue(label)

    let isEnabled = editBoxEnableFunc? editBoxEnableFunc() : true
    editBoxObj.enable(isEnabled)
    if (editBoxTextOnDisable)
      editBoxObj["edit-hint"] = isEnabled? "" : editBoxTextOnDisable
    if (value)
      editBoxObj.setValue(value)
    if (maxLen)
      editBoxObj["max-len"] = maxLen.tostring()
    if (charMask)
      editBoxObj["char-mask"] = charMask
    if (needOpenIMEonInit)
      editBoxObj.setValue(true) //opens IME, not change text.
    if (isPassword) {
      editBoxObj["type"] = "password"
      editBoxObj["password-smb"] = ::loc("password_mask_char", "*")
    }

    updateBtnByValue(value || "")
    value = null

    if (!canCancel && !cancelFunc)
      showSceneBtn("btn_back", false)

    if (okBtnText != "")
      setColoredDoubleTextToButton(scene, "btn_ok", okBtnText)

    if (isEnabled)
    {
      guiScene.applyPendingChanges(false)
      ::select_editbox(editBoxObj)
    }
  }

  function onChangeValue(obj)
  {
    let curVal = obj.getValue() || ""
    if (validateFunc)
    {
      let newVal = validateFunc(curVal)
      if (newVal != curVal)
        return obj.setValue(newVal)
    }
    updateBtnByValue(curVal)
    updateWarningByValue(obj, curVal)
  }

  function isApplyEnabled(curVal)
  {
    return (checkButtonFunc == null || checkButtonFunc(curVal))
           && (allowEmpty || curVal != "")
  }

  function updateBtnByValue(curVal)
  {
    scene.findObject("btn_ok").enable(isApplyEnabled(curVal))
  }

  function updateWarningByValue(obj, curVal) {
    let res = !checkWarningFunc(curVal)
    obj.warning = res? "yes" : "no"
    obj.warningText = res? "yes" : "no"
    obj.tooltip = res? editboxWarningTooltip : ""
  }

  function onOk()
  {
    value = editBoxObj.getValue() || ""
    if (isApplyEnabled(value))
      return guiScene.performDelayed(this, goBack)

    value = null
  }

  function goBack()
  {
    if (value || canCancel)
      base.goBack()
    else
      if (cancelFunc)
        ::call_for_handler(owner, cancelFunc)
  }

  function afterModalDestroy()
  {
    if (value && okFunc)
      if (owner)
        okFunc.call(owner, value)
      else
        okFunc(value)

    if (!value && cancelFunc)
      ::call_for_handler(owner, cancelFunc)
  }
}
