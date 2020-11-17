class ::gui_handlers.UniversalSpareApplyWnd extends ::gui_handlers.ItemsListWndBase
{
  sceneTplName = "gui/items/universalSpareApplyWnd"

  unit = null

  sliderObj = null
  amountTextObj = null
  curAmount = -1
  maxAmount = 1
  minAmount = 1

  static function open(unitToActivate, wndAlignObj = null, wndAlign = AL_ORIENT.BOTTOM)
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
  }

  function setCurItem(item)
  {
    base.setCurItem(item)
    updateAmountSlider()
  }

  function updateAmountSlider()
  {
    local itemsAmount = curItem.getAmount()
    local availableAmount = ::g_weaponry_types.SPARE.getMaxAmount(unit, null)  - ::g_weaponry_types.SPARE.getAmount(unit, null)
    maxAmount = ::min(itemsAmount, availableAmount)
    curAmount = 1

    local canChangeAmount = maxAmount > minAmount
    showSceneBtn("slider_block", canChangeAmount)
    if (!canChangeAmount)
      return

    showSceneBtn("buttonMax", true)
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
    curItem.activateOnUnit(unit, curAmount, ::Callback(goBack, this))
  }

  function onButtonMax()
  {
    sliderObj.setValue(maxAmount)
  }
}