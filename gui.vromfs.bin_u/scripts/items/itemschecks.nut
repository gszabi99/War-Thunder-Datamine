from "%scripts/dagui_library.nut" import *
from "types" import Integer

let { itemsTab, itemType } = require("%scripts/items/itemsConsts.nut")

let itemTypeFeatures = {
  [itemType.WAGER] = "Wagers",
  [itemType.ORDER] = "Orders",
}

let isItemdefId = @(id) id instanceof Integer

function isItemVisible(item, shopTab) {
  return shopTab == itemsTab.SHOP ? item.isCanBuy() && (!item.isDevItem || hasFeature("devItemShop"))
      && !item.isHiddenItem() && !item.isVisibleInWorkshopOnly() && !item.isHideInShop
    : shopTab == itemsTab.INVENTORY ? !item.isHiddenItem() && !item.isVisibleInWorkshopOnly()
      && (!item.shouldAutoConsume || item.canOpenForGold())
    : shopTab == itemsTab.RECYCLING ? !item.isHiddenItem() && item.canRecycle()
    : false
}


function checkItemsMaskFeatures(itemsMask) {
  foreach (iType, feature in itemTypeFeatures)
    if ((itemsMask & iType) && !hasFeature(feature))
      itemsMask -= iType
  return itemsMask
}

return {
  isItemdefId
  isItemVisible
  checkItemsMaskFeatures
}