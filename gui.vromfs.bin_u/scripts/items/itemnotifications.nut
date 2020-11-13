local workshop = ::require("scripts/items/workshop/workshop.nut")

local ITEMS_FOR_OFFER_BUY_SAVE_ID = "itemsListForOfferBuy"

local addItemsInOfferBuyList = function() {
  local itemsList = ::ItemsManager.getInventoryList(itemType.ALL,
    @(i) i.needOfferBuyAtExpiration() && i.getAmount() > 0)

  if (!itemsList.len())
    return

  local hasChanges = false
  local needOfferBuyItemsList = ::load_local_account_settings(ITEMS_FOR_OFFER_BUY_SAVE_ID, ::DataBlock())
  foreach (item in itemsList)
  {
    local idString = (item.id).tostring()
    if (needOfferBuyItemsList?[idString])
      continue

    needOfferBuyItemsList[idString] = true
    hasChanges = true
  }

  if (hasChanges)
    ::save_local_account_settings(ITEMS_FOR_OFFER_BUY_SAVE_ID, needOfferBuyItemsList)
}

local checkOfferToBuyAtExpiration = function()
{
  if (!::isInMenu())
    return

  if (!::g_login.isProfileReceived())
    return
  local needOfferBuyItemsList = ::load_local_account_settings(ITEMS_FOR_OFFER_BUY_SAVE_ID)
  if (!needOfferBuyItemsList)
    return

  local hasChanges = false
  foreach(itemId, value in needOfferBuyItemsList)
  {
    local id = ::to_integer_safe(itemId, itemId, false)
    local inventoryItem = ::ItemsManager.getInventoryItemById(id)
    local shopItem = ::ItemsManager.findItemById(id)
    if (inventoryItem && !inventoryItem.isExpired())
      continue

    if (!shopItem || !shopItem.isCanBuy() || !shopItem.needOfferBuyAtExpiration())
    {
      hasChanges = true
      needOfferBuyItemsList[itemId] = null
      continue
    }

    local wSet = workshop.getSetByItemId(shopItem.id)
    if (!wSet || !wSet.isVisible())
    {
      hasChanges = true
      needOfferBuyItemsList[itemId] = null
      continue
    }

    ::scene_msg_box("offer_buy_item", null,
      ::loc("msgBox/offerToBuyAtExpiration", { itemName = shopItem.getName() }),
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

::add_event_listener("InventoryUpdate", function(p) {
  checkOfferToBuyAtExpiration()
  addItemsInOfferBuyList()
})

return {
  checkOfferToBuyAtExpiration = checkOfferToBuyAtExpiration
}
