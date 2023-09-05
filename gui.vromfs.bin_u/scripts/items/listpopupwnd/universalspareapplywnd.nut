//-file:plus-string
from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")

gui_handlers.UniversalSpareApplyWnd <- class extends gui_handlers.ItemsListWndBase {
  sceneTplName = "%gui/items/universalSpareApplyWnd.tpl"

  unit = null

  sliderObj = null
  amountTextObj = null
  curAmount = -1
  maxAmount = 1
  minAmount = 1

  static function open(unitToActivate, wndAlignObj = null, wndAlign = ALIGN.BOTTOM) {
    local list = ::ItemsManager.getInventoryList(itemType.UNIVERSAL_SPARE)
    list = list.filter(@(item) item.canActivateOnUnit(unitToActivate))
    if (!list.len()) {
      ::showInfoMsgBox(loc("msg/noUniversalSpareForUnit"))
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

    if (this.itemsList.findindex(@(i) i.hasTimer()) != null)
      this.scene.findObject("update_timer").setUserData(this)
  }

  function setCurItem(item) {
    base.setCurItem(item)
    this.updateAmountSlider()
    this.updateButtons()
  }

  function updateAmountSlider() {
    let itemsAmount = this.curItem.getAmount()
    let availableAmount = ::g_weaponry_types.SPARE.getMaxAmount(this.unit, null)  - ::g_weaponry_types.SPARE.getAmount(this.unit, null)
    this.maxAmount = min(itemsAmount, availableAmount)
    this.curAmount = 1

    let canChangeAmount = this.maxAmount > this.minAmount && !this.curItem.isExpired()
    this.showSceneBtn("slider_block", canChangeAmount)
    this.showSceneBtn("buttonMax", canChangeAmount)
    if (!canChangeAmount)
      return

    this.sliderObj.min = this.minAmount.tostring()
    this.sliderObj.max = this.maxAmount.tostring()
    this.sliderObj.setValue(this.curAmount)
    this.updateText()
  }

  function updateText() {
    this.amountTextObj.setValue(this.curAmount + loc("icon/universalSpare"))
    this.scene.findObject("buttonMax").enable(this.curAmount != this.maxAmount)
  }

  function updateButtons() {
    this.scene.findObject("buttonActivate").enable(!this.curItem.isExpired())
  }

  function onTimer(_obj, _dt) {
    let listObj = this.scene.findObject("items_list")
    if (!listObj?.isValid())
      return

    for (local i = 0; i < this.itemsList.len(); ++i) {
      let item = this.itemsList[i]
      if (!item.hasTimer())
        continue

      let itemObj = listObj.getChild(i)
      if (!itemObj?.isValid())
        continue

      let timeTxtObj = itemObj.findObject("expire_time")
      if (!timeTxtObj?.isValid())
        continue

      timeTxtObj.setValue(item.getTimeLeftText())
    }

    this.updateAmountSlider()
    this.updateButtons()
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
    ::scene_msg_box("activate_wager_message_box", null, text, [["yes", onOk], ["no"]], "yes", { cancel_fn = @()null })
  }

  function onButtonMax() {
    this.sliderObj.setValue(this.maxAmount)
  }
}