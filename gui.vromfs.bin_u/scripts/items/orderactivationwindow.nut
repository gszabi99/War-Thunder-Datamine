//checked for plus_string
from "%scripts/dagui_library.nut" import *


let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let sheets = require("%scripts/items/itemsShopSheets.nut")
let { setDoubleTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")

::gui_start_order_activation_window <- function gui_start_order_activation_window(params = null) {
  if (params == null)
    params = {}
  params.curTab <- itemsTab.INVENTORY
  handlersManager.loadHandler(gui_handlers.OrderActivationWindow, params)
}

gui_handlers.OrderActivationWindow <- class extends gui_handlers.ItemsList {
  displayItemTypes = [sheets.ORDERS.id, sheets.DEV_ITEMS.id]

  function initScreen() {
    base.initScreen()
    this.showSceneBtn("tabs_list", false)
    this.scene.findObject("back_scene_name").setValue(loc("mainmenu/btnBack"))
    this.scene.findObject("bc_shop_header").setValue(loc("flightmenu/btnActivateOrder"))
  }

  /*override*/ function updateButtons() {
    let item = this.getCurItem()
    let mainActionData = item ? item.getMainActionData() : null
    let showMainAction = !!mainActionData
    let buttonObj = this.showSceneBtn("btn_main_action", showMainAction)
    if (showMainAction) {
      buttonObj.visualStyle = this.curTab == itemsTab.INVENTORY ? "secondary" : "purchase"
      setDoubleTextToButton(this.scene, "btn_main_action", mainActionData.btnName,
                              mainActionData?.btnColoredName || mainActionData.btnName)
    }

    local text = ""
    if (this.curTab == itemsTab.INVENTORY)
      text = ::g_orders.getWarningText(item)
    this.setWarningText(text)
  }

  function goBack() {
    base.goBack()

    if (::get_is_in_flight_menu())
      ::in_flight_menu(false)
  }

  /*override*/ function onTimer(obj, dt) {
    base.onTimer(obj, dt)
    this.updateButtons()
  }

  function onEventActiveOrderChanged(_params) {
    this.fillPage()
  }

  /*override*/ function onMainActionComplete(result) {
    // This forces "Activate" button for each item to update.
    if (base.onMainActionComplete(result))
      this.fillPage()
  }

  function onEventOrderUseResultMsgBoxClosed(_params) {
    this.goBack()
  }

  /*override*/ function isItemLocked(item) {
    return !::g_orders.checkCurrentMission(item)
  }
}
