class ::gui_handlers.UniversalSpareApplyWnd extends ::gui_handlers.ItemsListWndBase
{
  sceneTplName = "gui/items/universalSpareApplyWnd"

  unit = null

  sliderObj = null
  amountTextObj = null
  curAmount = -1
  maxAmount = 1
  minAmount = 1

  static function open(unitToActivate, wndAlignObj = null, wndAlign = ALIGN.BOTTOM)
  {
    local list = ::ItemsManager.getInventoryList(itemType.UNIVERSAL_SPARE)
    list = ::u.filter(list, @(item) item.canActivateOnUnit(unitToActivate))
    if (!list.len())
    {
      ::showInfoMsgBox(::loc("msg/noUniversalSpareForUnit"))
      return
    }
    ::handlersManager.loadHandler(::gui_handlers.UniversalSpareApplyWnd,
    {
      unit = unitToActivate
      itemsList = list
      alignObj = wndAlignObj
      align = wndAlign
    })
  }

  function initScreen()
  {
    sliderObj = scene.findObject("amount_slider")
    amountTextObj = scene.findObject("amount_text")

    base.initScreen()

    if (itemsList.findindex(@(i) i.hasTimer()) != null)
      scene.findObject("update_timer").setUserData(this)
  }

  function setCurItem(item)
  {
    base.setCurItem(item)
    updateAmountSlider()
    updateButtons()
  }

  function updateAmountSlider()
  {
    local itemsAmount = curItem.getAmount()
    local availableAmount = ::g_weaponry_types.SPARE.getMaxAmount(unit, null)  - ::g_weaponry_types.SPARE.getAmount(unit, null)
    maxAmount = ::min(itemsAmount, availableAmount)
    curAmount = 1

    local canChangeAmount = maxAmount > minAmount && !curItem.isExpired()
    showSceneBtn("slider_block", canChangeAmount)
    showSceneBtn("buttonMax", canChangeAmount)
    if (!canChangeAmount)
      return

    sliderObj.min = minAmount.tostring()
    sliderObj.max = maxAmount.tostring()
    sliderObj.setValue(curAmount)
    updateText()
  }

  function updateText()
  {
    amountTextObj.setValue(curAmount + ::loc("icon/universalSpare"))
    scene.findObject("buttonMax").enable(curAmount != maxAmount)
  }

  function updateButtons()
  {
    scene.findObject("buttonActivate").enable(!curItem.isExpired())
  }

  function onTimer(obj, dt)
  {
    local listObj = scene.findObject("items_list")
    if (!listObj?.isValid())
      return

    for (local i = 0; i < itemsList.len(); ++i)
    {
      local item = itemsList[i]
      if (!item.hasTimer())
        continue

      local itemObj = listObj.getChild(i)
      if (!itemObj?.isValid())
        continue

      local timeTxtObj = itemObj.findObject("expire_time")
      if (!timeTxtObj?.isValid())
        continue

      timeTxtObj.setValue(item.getTimeLeftText())
    }

    updateAmountSlider()
    updateButtons()
  }

  function onAmountInc()
  {
    if (curAmount < maxAmount)
      sliderObj.setValue(curAmount + 1)
  }

  function onAmountDec()
  {
    if (curAmount > minAmount)
      sliderObj.setValue(curAmount - 1)
  }

  function onAmountChange()
  {
    curAmount = sliderObj.getValue()
    updateText()
  }

  function onActivate()
  {
    local text = ::loc("msgbox/wagerActivate", { name = curItem.getNameWithCount(true, curAmount) })
    local goBackSaved = ::Callback(goBack, this)
    local aUnit= unit
    local item = curItem
    local amount = curAmount
    local onOk = @() item.activateOnUnit(aUnit, amount, goBackSaved)
    ::scene_msg_box("activate_wager_message_box", null, text, [["yes", onOk], ["no"]], "yes")
  }

  function onButtonMax()
  {
    sliderObj.setValue(maxAmount)
  }
}