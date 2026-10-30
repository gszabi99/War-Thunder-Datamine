import "DataBlock" as DataBlock
from "%scripts/clientState/clientStates.nut" import isInMenu
from "%scripts/crossModuleEvents.nut" import INVENTORY_UPDATE
from "%appGlobals/clientState/localProfile.nut" import saveLocalAccountSettings, loadLocalAccountSettings
from "%scripts/items/startItemsShop.nut" import gui_start_items_list
from "%scripts/items/itemsManagerModule.nut" import findItemById, getInventoryList
from "%scripts/items/itemsManagerGetters.nut" import getInventoryItemById
from "%sqStdLibs/helpers/subscriptions.nut" import add_event_listener
from "%appGlobals/login/loginState.nut" import isProfileReceived
from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import itemsTab, itemType

let workshop = require("%scripts/items/workshop/workshop.nut")


const ITEMS_FOR_OFFER_BUY_SAVE_ID = "itemsListForOfferBuy"

let addItemsInOfferBuyList = function() {
  let itemsList = getInventoryList(itemType.ALL,
    @(i) i.needOfferBuyAtExpiration() && i.getAmount() > 0)

  if (!itemsList.len())
    return

  local hasChanges = false
  let needOfferBuyItemsList = loadLocalAccountSettings(ITEMS_FOR_OFFER_BUY_SAVE_ID, DataBlock())
  foreach (item in itemsList) {
    let idString = (item.id).tostring()
    if (needOfferBuyItemsList?[idString])
      continue

    needOfferBuyItemsList[idString] = true
    hasChanges = true
  }

  if (hasChanges)
    saveLocalAccountSettings(ITEMS_FOR_OFFER_BUY_SAVE_ID, needOfferBuyItemsList)
}

let checkOfferToBuyAtExpiration = function() {
  if (!isInMenu.get())
    return

  if (!isProfileReceived.get())
    return
  local needOfferBuyItemsList = loadLocalAccountSettings(ITEMS_FOR_OFFER_BUY_SAVE_ID)
  if (!needOfferBuyItemsList)
    return

  local hasChanges = false
  foreach (itemId, _value in needOfferBuyItemsList) {
    let id = to_integer_safe(itemId, itemId, false)
    let inventoryItem = getInventoryItemById(id)
    let shopItem = findItemById(id)
    if (inventoryItem && !inventoryItem.isExpired())
      continue

    if (!shopItem || !shopItem.isCanBuy() || !shopItem.needOfferBuyAtExpiration()) {
      hasChanges = true
      needOfferBuyItemsList[itemId] = null
      continue
    }

    let wSet = workshop.getSetByItemId(shopItem.id)
    if (!wSet || !wSet.isVisible()) {
      hasChanges = true
      needOfferBuyItemsList[itemId] = null
      continue
    }

    scene_msg_box("offer_buy_item", null,
      loc("msgBox/offerToBuyAtExpiration", { itemName = shopItem.getName() }),
        [
          ["yes", @() gui_start_items_list(itemsTab.WORKSHOP,
            { curSheet = { id = wSet.getShopTabId() }
              curItem  = shopItem
              initSubsetId = wSet.getSubsetIdByItemId(shopItem.id)
            })],
          ["no", @() null ]
        ], "yes", { cancel_fn = function() {} })

    hasChanges = true
    needOfferBuyItemsList[itemId] = null
    break
  }

  if (hasChanges) {
    if (needOfferBuyItemsList.paramCount() == 0)
      needOfferBuyItemsList = null
    saveLocalAccountSettings(ITEMS_FOR_OFFER_BUY_SAVE_ID, needOfferBuyItemsList)
  }
}

add_event_listener(INVENTORY_UPDATE, function(_p) {
  checkOfferToBuyAtExpiration()
  addItemsInOfferBuyList()
})

return freeze({
  checkOfferToBuyAtExpiration = checkOfferToBuyAtExpiration
})
