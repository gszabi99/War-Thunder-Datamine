from "%scripts/dagui_natives.nut" import get_is_in_flight_menu, in_flight_menu
from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import itemsTab

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let sheets = require("%scripts/items/itemsShopSheets.nut")
let { setDoubleTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { getWarningText, checkCurrentMission } = require("%scripts/items/orders.nut")

gui_handlers.OrderActivationWindow <- class (gui_handlers.ItemsList) {
  displayItemTypes = [sheets.ORDERS.id, sheets.DEV_ITEMS.id]

  function initScreen() {
    base.initScreen()
    showObjById("tabs_list", false, this.scene)
    this.scene.findObject("back_scene_name").setValue(loc("mainmenu/btnBack"))
    this.scene.findObject("bc_shop_header").setValue(loc("flightmenu/btnActivateOrder"))
  }

  /*override*/ function updateButtons() {
    let item = this.getCurItem()
    let mainActionData = item ? item.getMainActionData() : null
    let showMainAction = !!mainActionData
    let buttonObj = showObjById("btn_main_action", showMainAction, this.scene)
    if (showMainAction) {
      buttonObj.visualStyle = this.curTab == itemsTab.INVENTORY ? "secondary" : "purchase"
      setDoubleTextToButton(this.scene, "btn_main_action", mainActionData.btnName,
                              mainActionData?.btnColoredName || mainActionData.btnName)
    }

    local text = ""
    if (this.curTab == itemsTab.INVENTORY)
      text = getWarningText(item)
    this.setWarningText(text)
  }

  function goBack() {
    base.goBack()

    if (get_is_in_flight_menu())
      in_flight_menu(false)
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
    return !checkCurrentMission(item)
  }
}
