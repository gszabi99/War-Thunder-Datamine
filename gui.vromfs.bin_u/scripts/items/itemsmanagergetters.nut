from "%scripts/items/itemsManagerChecks.nut" import checkUpdateList, checkInventoryUpdate
from "%scripts/items/itemsConsts.nut" import itemType, itemsTab
from "%scripts/items/itemsChecks.nut" import isItemVisible, checkItemsMaskFeatures
from "%scripts/dagui_library.nut" import *

let { itemsList, inventoryItemById } = require("%scripts/items/itemsManagerState.nut")

function getItemsFromList(list, typeMask, filterFunc = null, itemMaskProperty = "iType") {
  if (typeMask == itemType.ALL && !filterFunc)
    return list

  let res = []
  foreach (item in list)
    if (((item?[itemMaskProperty] ?? item.iType) & typeMask)
        && (!filterFunc || filterFunc(item)))
      res.append(item)
  return res
}

function getShopList(typeMask = itemType.INVENTORY_ALL, filterFunc = null) {
  checkUpdateList()
  return getItemsFromList(itemsList, typeMask, filterFunc, "shopFilterMask")
}

function canGetDecoratorFromTrophy(decorator) {
  if (!decorator || decorator.isUnlocked())
    return false
  let visibleTypeMask = checkItemsMaskFeatures(itemType.TROPHY)
  let filterFunc = @(item) !item.isDevItem && isItemVisible(item, itemsTab.SHOP)
  return getShopList(visibleTypeMask, filterFunc)
    .findindex(@(item) item.getContent().findindex(@(prize) prize?.resource == decorator.id) != null) != null
}

function getInventoryItemById(id) {
  checkInventoryUpdate()
  return inventoryItemById?[id]
}

return freeze({
  getItemsFromList
  getShopList
  getInventoryItemById
  canGetDecoratorFromTrophy
})