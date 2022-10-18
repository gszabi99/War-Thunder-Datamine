from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let { handlerType } = require("%sqDagui/framework/handlerType.nut")

::gui_handlers.ChooseAmountWnd <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneTplName = "%gui/wndLib/chooseAmountWnd"
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
    let res = {}
    foreach(key in ["align", "headerText", "buttonText",
        "minValue", "maxValue", "curValue", "valueStep"])
      res[key] <- this[key]

    res.needSlider <- minValue != maxValue
    res.hasPopupMenuArrow <- checkObj(parentObj)
    return res
  }

  function initScreen()
  {
    if (checkObj(parentObj))
      align = ::g_dagui_utils.setPopupMenuPosAndAlign(parentObj, align, this.scene.findObject("popup_frame"))
    updateButtons()
    updateValueText()
  }

  function updateButtons()
  {
    let buttonDecObj = this.scene.findObject("buttonDec")
    if (checkObj(buttonDecObj))
      buttonDecObj.enable(curValue != minValue)
    let buttonIncObj = this.scene.findObject("buttonInc")
    if (checkObj(buttonIncObj))
      buttonIncObj.enable(curValue != maxValue)
  }

  function updateValueText()
  {
    if (!getValueText)
      return
    local stakeTextObj = this.scene.findObject("cur_value_text")
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
    newValue = clamp(newValue, minValue, maxValue)
    if (newValue != curValue)
      this.scene.findObject("amount_slider").setValue(newValue)
  }

  function onButtonDec(_obj) { changeSliderValue(curValue - valueStep) }
  function onButtonInc(_obj) { changeSliderValue(curValue + valueStep) }

  function onCancel()
  {
    if (onCancelCb)
      onCancelCb()
    this.goBack()
  }

  function onAccept()
  {
    if (onAcceptCb)
      onAcceptCb(curValue)
    this.goBack()
  }
}

return {
  open = @(params) ::handlersManager.loadHandler(::gui_handlers.ChooseAmountWnd, params)
}