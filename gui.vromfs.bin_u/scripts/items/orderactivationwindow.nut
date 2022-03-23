let sheets = require("%scripts/items/itemsShopSheets.nut")
let { setDoubleTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")

::gui_start_order_activation_window <- function gui_start_order_activation_window(params = null)
{
  if (params == null)
    params = {}
  params.curTab <- itemsTab.INVENTORY
  ::handlersManager.loadHandler(::gui_handlers.OrderActivationWindow, params)
}

::gui_handlers.OrderActivationWindow <- class extends ::gui_handlers.ItemsList
{
  displayItemTypes = [sheets.ORDERS.id, sheets.DEV_ITEMS.id]

  function initScreen() {
    base.initScreen()
    showSceneBtn("tabs_list", false)
    scene.findObject("back_scene_name").setValue(::loc("mainmenu/btnBack"))
    scene.findObject("bc_shop_header").setValue(::loc("flightmenu/btnActivateOrder"))
  }

  /*override*/ function updateButtons()
  {
    let item = getCurItem()
    let mainActionData = item ? item.getMainActionData() : null
    let showMainAction = !!mainActionData
    let buttonObj = showSceneBtn("btn_main_action", showMainAction)
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
