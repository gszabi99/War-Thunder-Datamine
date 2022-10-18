from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let workshop = require("%scripts/items/workshop/workshop.nut")

let ITEMS_FOR_OFFER_BUY_SAVE_ID = "itemsListForOfferBuy"

let addItemsInOfferBuyList = function() {
  let itemsList = ::ItemsManager.getInventoryList(itemType.ALL,
    @(i) i.needOfferBuyAtExpiration() && i.getAmount() > 0)

  if (!itemsList.len())
    return

  local hasChanges = false
  let needOfferBuyItemsList = ::load_local_account_settings(ITEMS_FOR_OFFER_BUY_SAVE_ID, ::DataBlock())
  foreach (item in itemsList)
  {
    let idString = (item.id).tostring()
    if (needOfferBuyItemsList?[idString])
      continue

    needOfferBuyItemsList[idString] = true
    hasChanges = true
  }

  if (hasChanges)
    ::save_local_account_settings(ITEMS_FOR_OFFER_BUY_SAVE_ID, needOfferBuyItemsList)
}

let checkOfferToBuyAtExpiration = function()
{
  if (!::isInMenu())
    return

  if (!::g_login.isProfileReceived())
    return
  local needOfferBuyItemsList = ::load_local_account_settings(ITEMS_FOR_OFFER_BUY_SAVE_ID)
  if (!needOfferBuyItemsList)
    return

  local hasChanges = false
  foreach(itemId, _value in needOfferBuyItemsList)
  {
    let id = ::to_integer_safe(itemId, itemId, false)
    let inventoryItem = ::ItemsManager.getInventoryItemById(id)
    let shopItem = ::ItemsManager.findItemById(id)
    if (inventoryItem && !inventoryItem.isExpired())
      continue

    if (!shopItem || !shopItem.isCanBuy() || !shopItem.needOfferBuyAtExpiration())
    {
      hasChanges = true
      needOfferBuyItemsList[itemId] = null
      continue
    }

    let wSet = workshop.getSetByItemId(shopItem.id)
    if (!wSet || !wSet.isVisible())
    {
      hasChanges = true
      needOfferBuyItemsList[itemId] = null
      continue
    }

    ::scene_msg_box("offer_buy_item", null,
      loc("msgBox/offerToBuyAtExpiration", { itemName = shopItem.getName() }),
        [
          ["yes", @() ::gui_start_items_list(itemsTab.WORKSHOP,
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

  if (hasChanges)
  {
    if (needOfferBuyItemsList.paramCount() == 0)
      needOfferBuyItemsList = null
    ::save_local_account_settings(ITEMS_FOR_OFFER_BUY_SAVE_ID, needOfferBuyItemsList)
  }
}

::add_event_listener("InventoryUpdate", function(_p) {
  checkOfferToBuyAtExpiration()
  addItemsInOfferBuyList()
})

return {
  checkOfferToBuyAtExpiration = checkOfferToBuyAtExpiration
}
