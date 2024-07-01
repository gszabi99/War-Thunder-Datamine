from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { setPopupMenuPosAndAlign } = require("%sqDagui/daguiUtil.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")

gui_handlers.ChooseAmountWnd <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneTplName = "%gui/wndLib/chooseAmountWnd.tpl"
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

  function getSceneTplView() {
    let res = {}
    foreach (key in ["align", "headerText", "buttonText",
        "minValue", "maxValue", "curValue", "valueStep"])
      res[key] <- this[key]

    res.needSlider <- this.minValue != this.maxValue
    res.hasPopupMenuArrow <- checkObj(this.parentObj)
    return res
  }

  function initScreen() {
    if (checkObj(this.parentObj))
      this.align = setPopupMenuPosAndAlign(this.parentObj, this.align, this.scene.findObject("popup_frame"))
    this.updateButtons()
    this.updateValueText()
  }

  function updateButtons() {
    let buttonDecObj = this.scene.findObject("buttonDec")
    if (checkObj(buttonDecObj))
      buttonDecObj.enable(this.curValue != this.minValue)
    let buttonIncObj = this.scene.findObject("buttonInc")
    if (checkObj(buttonIncObj))
      buttonIncObj.enable(this.curValue != this.maxValue)
  }

  function updateValueText() {
    if (!this.getValueText)
      return
    local stakeTextObj = this.scene.findObject("cur_value_text")
    stakeTextObj.setValue(this.getValueText(this.curValue))
  }

  function onValueChange(obj) {
    this.curValue = obj.getValue()
    this.updateButtons()
    this.updateValueText()
  }

  function changeSliderValue(newValue) {
    newValue = clamp(newValue, this.minValue, this.maxValue)
    if (newValue != this.curValue)
      this.scene.findObject("amount_slider").setValue(newValue)
  }

  function onButtonDec(_obj) { this.changeSliderValue(this.curValue - this.valueStep) }
  function onButtonInc(_obj) { this.changeSliderValue(this.curValue + this.valueStep) }

  function onCancel() {
    if (this.onCancelCb)
      this.onCancelCb()
    this.goBack()
  }

  function onAccept() {
    if (this.onAcceptCb)
      this.onAcceptCb(this.curValue)
    this.goBack()
  }
}

return {
  open = @(params) handlersManager.loadHandler(gui_handlers.ChooseAmountWnd, params)
}