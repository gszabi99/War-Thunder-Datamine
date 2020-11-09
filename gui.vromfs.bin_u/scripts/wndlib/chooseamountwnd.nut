class ::gui_handlers.ChooseAmountWnd extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneTplName = "gui/wndLib/chooseAmountWnd"
  shouldBlurSceneBg = false
  needVoiceChat = false

  parentObj = null
  align = "bottom"
  minValue = 0
  maxValue = 1
  curValue = 1
  valueStep = 1

  headerText = ""
  buttonText = ""
  getValueText = null //@(value) value.tostring()

  onAcceptCb = null
  onCancelCb = null

  function getSceneTplView()
  {
    local res = {}
    foreach(key in ["align", "headerText", "buttonText",
        "minValue", "maxValue", "curValue", "valueStep"])
      res[key] <- this[key]

    res.needSlider <- minValue != maxValue
    res.hasPopupMenuArrow <- ::check_obj(parentObj)
    return res
  }

  function initScreen()
  {
    if (::check_obj(parentObj))
      align = ::g_dagui_utils.setPopupMenuPosAndAlign(parentObj, align, scene.findObject("popup_frame"))
    initFocusArray()
    updateButtons()
    updateValueText()
  }

  function getMainFocusObj()
  {
    return scene.findObject("amount_slider")
  }

  function updateButtons()
  {
    local buttonDecObj = scene.findObject("buttonDec")
    if (::check_obj(buttonDecObj))
      buttonDecObj.enable(curValue != minValue)
    local buttonIncObj = scene.findObject("buttonInc")
    if (::check_obj(buttonIncObj))
      buttonIncObj.enable(curValue != maxValue)
  }

  function updateValueText()
  {
    if (!getValueText)
      return
    local stakeTextObj = scene.findObject("cur_value_text")
    stakeTextObj.setValue(getValueText(curValue))
  }

  function onValueChange(obj)
  {
    curValue = obj.getValue()
    updateButtons()
    updateValueText()
  }

  function changeSliderValue(newValue)
  {
    newValue = ::clamp(newValue, minValue, maxValue)
    if (newValue != curValue)
      scene.findObject("amount_slider").setValue(newValue)
  }

  function onButtonDec(obj) { changeSliderValue(curValue - valueStep) }
  function onButtonInc(obj) { changeSliderValue(curValue + valueStep) }

  function onCancel()
  {
    if (onCancelCb)
      onCancelCb()
    goBack()
  }

  function onAccept()
  {
    if (onAcceptCb)
      onAcceptCb(curValue)
    goBack()
  }
}

return {
  open = @(params) ::handlersManager.loadHandler(::gui_handlers.ChooseAmountWnd, params)
}