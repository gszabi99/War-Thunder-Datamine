from "eventbus" import eventbus_subscribe
from "dagor.workcycle" import defer
from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import itemsTab

let { get_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")
let { loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { isItemsManagerEnabled } = require("%scripts/items/itemsManager.nut")
let { findItemById } = require("%scripts/items/itemsManagerModule.nut")

function gui_start_items_list(curTab, params = null) {
  if (!isItemsManagerEnabled())
    return

  let { itemId = null } = params
  let curItem = itemId != null ? findItemById(to_integer_safe(itemId, itemId, false)) : null
  let handlerParams = { curTab, curItem }.__update(params ?? {})
  defer(@() loadHandler(get_gui_handler("ItemsList"), handlerParams))
}

function gui_start_itemsShop(params = null) {
  gui_start_items_list(itemsTab.SHOP, params)
}

function gui_start_inventory(params = null) {
  gui_start_items_list(itemsTab.INVENTORY, params)
}

eventbus_subscribe("gui_start_itemsShop", gui_start_itemsShop)
eventbus_subscribe("gui_start_inventory", gui_start_inventory)

return {
  gui_start_itemsShop
  gui_start_inventory
  gui_start_items_list
}