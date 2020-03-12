class ::gui_handlers.SkipableMsgBox extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/weaponry/skipableMsgBox.blk"

  parentHandler = null
  onStartPressed = null
  cancelFunc = null
  skipFunc = null
  isCanceled = true

  message = ""
  list = ""
  startBtnText = ""
  ableToStartAndSkip = true

  function initScreen()
  {
    updateSkipCheckBox()

    local msgTextObj = scene.findObject("msgText")
    if (::check_obj(msgTextObj))
      msgTextObj.setValue(message)

    local listTextObj = scene.findObject("listText")
    if (::check_obj(listTextObj))
      listTextObj.setValue(list)

    local btnSelectObj = scene.findObject("btn_select")
    if (::check_obj(btnSelectObj))
      btnSelectObj.show(ableToStartAndSkip)

    local btnCancelObj = scene.findObject("btn_cancel")
    if(::check_obj(btnCancelObj))
      btnCancelObj.setValue(::loc(ableToStartAndSkip ? "mainmenu/btnCancel" : "mainmenu/btnOk"))

    if (startBtnText != "")
      ::setDoubleTextToButton(scene, "btn_select", startBtnText)
  }

  function updateSkipCheckBox()
  {
    local skipObj = scene.findObject("skip_this")
    if (::check_obj(skipObj))
    {
      skipObj.show(ableToStartAndSkip && skipFunc)
      skipObj.enable(ableToStartAndSkip && skipFunc)
    }
  }

  function onSkipMessageBox(obj)
  {
    if (!obj)
      return

    if (skipFunc)
      skipFunc(obj.getValue())
  }

  function onStart()
  {
    isCanceled = false
    if (parentHandler && onStartPressed)
      onStartPressed.call(parentHandler)

    goBack()
  }

  function afterModalDestroy()
  {
    if (isCanceled)
      ::call_for_handler(parentHandler, cancelFunc)
  }
}
