from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import itemType
from "%scripts/mainConsts.nut" import SEEN

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let seenInventory = require("%scripts/seen/seenList.nut").get(SEEN.INVENTORY)

::g_recent_items <- {
  MAX_RECENT_ITEMS = 4
  wasCreated = false
}

::g_recent_items.getRecentItems <- function getRecentItems() {
  let items = ::ItemsManager.getInventoryList(itemType.INVENTORY_ALL, function (item) {
    return item.includeInRecentItems
  })
  items.sort(::ItemsManager.getItemsSortComparator(seenInventory))
  let resultItems = []
  foreach (item in items) {
    if (item.isHiddenItem())
      continue
    resultItems.append(item)
    if (resultItems.len() == this.MAX_RECENT_ITEMS)
      break
  }

  return resultItems
}

::g_recent_items.createHandler <- function createHandler(_owner, containerObj, defShow) {
  if (!checkObj(containerObj))
    return null

  this.wasCreated = true
  return handlersManager.loadHandler(gui_handlers.RecentItemsHandler, { scene = containerObj, defShow = defShow })
}

::g_recent_items.getNumOtherItems <- function getNumOtherItems() {
  let inactiveItems = ::ItemsManager.getInventoryList(itemType.INVENTORY_ALL,
    @(item) !!item.getMainActionData())
  return inactiveItems.len()
}

::g_recent_items.reset <- function reset() {
  this.wasCreated = false
}
