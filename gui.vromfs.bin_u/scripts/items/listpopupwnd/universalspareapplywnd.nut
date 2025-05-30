from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { ItemsListWndBase } = require("%scripts/items/listPopupWnd/itemsListWndBase.nut")
let { getUniversalSparesForUnit } = require("%scripts/items/itemsManagerModule.nut")
let { weaponryTypes } = require("%scripts/weaponry/weaponryTypes.nut")

gui_handlers.UniversalSpareApplyWnd <- class (ItemsListWndBase) {
  sceneTplName = "%gui/items/universalSpareApplyWnd.tpl"

  unit = null

  sliderObj = null
  amountTextObj = null
  curAmount = -1
  maxAmount = 1
  minAmount = 1

  static function open(unitToActivate, wndAlignObj = null, wndAlign = ALIGN.BOTTOM) {
    let list = getUniversalSparesForUnit(unitToActivate)
    if (!list.len()) {
      showInfoMsgBox(loc("msg/noUniversalSpareForUnit"))
      return
    }
    handlersManager.loadHandler(gui_handlers.UniversalSpareApplyWnd,
    {
      unit = unitToActivate
      itemsList = list
      alignObj = wndAlignObj
      align = wndAlign
    })
  }

  function initScreen() {
    this.sliderObj = this.scene.findObject("amount_slider")
    this.amountTextObj = this.scene.findObject("amount_text")

    base.initScreen()
  }

  function setCurItem(item) {
    base.setCurItem(item)
    this.updateAmountSlider()
  }

  function updateAmountSlider() {
    let itemsAmount = this.curItem.getAmount()
    let availableAmount = weaponryTypes.SPARE.getMaxAmount(this.unit, null) - weaponryTypes.SPARE.getAmount(this.unit, null)
    this.maxAmount = min(itemsAmount, availableAmount)
    this.curAmount = 1

    let canChangeAmount = this.maxAmount > this.minAmount && !this.curItem.isExpired()
    showObjById("slider_block", canChangeAmount, this.scene)
    showObjById("buttonMax", canChangeAmount, this.scene)
    if (!canChangeAmount)
      return

    this.sliderObj.min = this.minAmount.tostring()
    this.sliderObj.max = this.maxAmount.tostring()
    this.sliderObj.setValue(this.curAmount)
    this.updateText()
  }

  function updateText() {
    this.amountTextObj.setValue("".concat(this.curAmount, loc("icon/universalSpare")))
    this.scene.findObject("buttonMax").enable(this.curAmount != this.maxAmount)
  }

  function onTimer(obj, dt) {
    base.onTimer(obj, dt)
    this.updateAmountSlider()
  }

  function onAmountInc() {
    if (this.curAmount < this.maxAmount)
      this.sliderObj.setValue(this.curAmount + 1)
  }

  function onAmountDec() {
    if (this.curAmount > this.minAmount)
      this.sliderObj.setValue(this.curAmount - 1)
  }

  function onAmountChange() {
    this.curAmount = this.sliderObj.getValue()
    this.updateText()
  }

  function onActivate() {
    let text = loc("msgbox/wagerActivate", { name = this.curItem.getNameWithCount(true, this.curAmount) })
    let goBackSaved = Callback(this.goBack, this)
    let aUnit = this.unit
    let item = this.curItem
    let amount = this.curAmount
    let onOk = @() item.activateOnUnit(aUnit, amount, goBackSaved)
    scene_msg_box("activate_wager_message_box", null, text, [["yes", onOk], ["no"]], "yes", { cancel_fn = @()null })
  }

  function onButtonMax() {
    this.sliderObj.setValue(this.maxAmount)
  }
}