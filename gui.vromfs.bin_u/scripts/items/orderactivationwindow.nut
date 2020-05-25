local sheets = require("scripts/items/itemsShopSheets.nut")
local { setDoubleTextToButton } = require("scripts/viewUtils/objectTextUpdate.nut")

::gui_start_order_activation_window <- function gui_start_order_activation_window(params = null)
{
  if (params == null)
    params = {}
  params.curTab <- itemsTab.INVENTORY
  ::handlersManager.loadHandler(::gui_handlers.OrderActivationWindow, params)
}

class ::gui_handlers.OrderActivationWindow extends ::gui_handlers.ItemsList
{
  displayItemTypes = [sheets.ORDERS.id, sheets.DEV_ITEMS.id]

  /*override*/ function updateButtons()
  {
    local item = getCurItem()
    local mainActionData = item ? item.getMainActionData() : null
    local showMainAction = !!mainActionData
    local buttonObj = showSceneBtn("btn_main_action", showMainAction)
    if (showMainAction)
    {
      buttonObj.visualStyle = curTab == itemsTab.INVENTORY? "secondary" : "purchase"
      setDoubleTextToButton(scene, "btn_main_action", mainActionData.btnName,
                              mainActionData?.btnColoredName || mainActionData.btnName)
    }

    local text = ""
    if (curTab == itemsTab.INVENTORY)
      text =::g_orders.getWarningText(item)
    setWarningText(text)
  }

  /*override*/ function onTimer(obj, dt)
  {
    base.onTimer(obj, dt)
    updateButtons()
  }

  function onEventActiveOrderChanged(params)
  {
    fillPage()
  }

  /*override*/ function onMainActionComplete(result)
  {
    // This forces "Activate" button for each item to update.
    if (base.onMainActionComplete(result))
      fillPage()
  }

  function onEventOrderUseResultMsgBoxClosed(params)
  {
    goBack()
  }

  /*override*/ function isItemLocked(item)
  {
    return !::g_orders.checkCurrentMission(item)
  }
}
