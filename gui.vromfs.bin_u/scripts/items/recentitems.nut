from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import itemType
from "%scripts/mainConsts.nut" import SEEN

let seenInventory = require("%scripts/seen/seenList.nut").get(SEEN.INVENTORY)
let { getInventoryList, getItemsSortComparator } = require("%scripts/items/itemsManager.nut")

const MAX_RECENT_ITEMS = 4

function getRecentItems() {
  let items = getInventoryList(itemType.INVENTORY_ALL, function (item) {
    return item.includeInRecentItems
  })
  items.sort(getItemsSortComparator(seenInventory))
  let resultItems = []
  foreach (item in items) {
    if (item.isHiddenItem() || item.shouldAutoConsume)
      continue
    resultItems.append(item)
    if (resultItems.len() == MAX_RECENT_ITEMS)
      break
  }

  return resultItems
}

function getNumOtherItems() {
  let inactiveItems = getInventoryList(itemType.INVENTORY_ALL,
    @(item) !!item.getMainActionData())
  return inactiveItems.len()
}

return freeze({
  getRecentItems
  getNumOtherItems
})
