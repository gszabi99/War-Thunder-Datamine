from "%scripts/mainmenu/mainMenuHandler.nut" import MainMenu
from "%scripts/inventory/steamInventory.nut" import requestAllItems
from "%scripts/items/exchangeRecipes.nut" import tryUseRecipes
from "%scripts/clientState/clientStates.nut" import isInMenu
from "%scripts/items/itemsManagerModule.nut" import findItemById
from "%scripts/items/itemsManagerGetters.nut" import getInventoryItemById
from "%scripts/unlocks/showUnlockWnd.nut" import showUnlockWnd
from "%scripts/queue/queueState.nut" import isAnyQueuesActive
from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv
from "console" import register_command
from "%scripts/dagui_library.nut" import *

let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let logS = log_with_prefix("[Steam Items] ")

let hardPersistWatched = mkHardPersistWatched("inventory.steamCheckNewItems")
let steamNewItems = hardPersistWatched("steamNewItems", [])
wlog(steamNewItems, "[Steam Items]: newitems ")
let unknownSteamNewItems = hardPersistWatched("unknownSteamNewItems", {})
wlog(unknownSteamNewItems, "[Steam Items]: unknownSteamNewItems ")
let inqueueSteamItems = mkWatched(persist, "inqueueSteamItems", {})
wlog(inqueueSteamItems, "[Steam Items]: inqueueSteamItems ")

let steamItemdefidToInventoryItemdefid = {
  [211022] = 211029,
  [211025] = 211030,
}

let showSteamItemNotification = function(itemInfo) {
  let { item, steamItemId } = itemInfo
  showUnlockWnd({
    name = item.getName(false)
    desc = item.getLongDescription()
    popupImage = item.getIconName()
    imgWidth = "300@sf/@pf"
    ratioHeight = 1.0
    onDestroyFunc = function() {
      inqueueSteamItems.mutate(@(v) v.$rawdelete(steamItemId))
      if (item.doMainAction(@(_) null, null, { needConsumeImpl = true, shouldSkipMsgBox = true }))
        return

      let recipes = item.getRelatedRecipes()
      if (recipes.len() > 0)
        tryUseRecipes(recipes, item, { shouldSkipMsgBox = true })
    }
    okBtnText = loc("items/getReward")
    okBtnStyle = "secondary"
  })
}

function tryShowSteamItemsNotification(items = []) {
  if (!isInMenu.get() || isAnyQueuesActive())
    return

  items.each(function(itemInfo) {
    inqueueSteamItems.mutate(@(v) v[itemInfo.steamItemId] <- true)
    showSteamItemNotification(itemInfo)
  })
  steamNewItems.set([])
}

function tryShowSteamItemsNotificationOnUpdate(items = []) {
  let newItems = items
  let handler = handlersManager.getActiveBaseHandler()
  let handlerClass = handler?.getclass()
  if (handler?.isValid() && handlerClass == MainMenu)
    handler.doWhenActive(@() tryShowSteamItemsNotification(newItems))
}

function steamCheckNewItems() {
  let newItems = []
  foreach (sItem in steamNewItems.get()) {
    let steamItem = sItem
    let { itemDef, itemId } = steamItem
    let inventoryItemId = steamItemdefidToInventoryItemdefid?[itemDef] ?? itemDef
    let item = getInventoryItemById(inventoryItemId)
    if (!item) {
      if (inventoryItemId not in unknownSteamNewItems.get())
        unknownSteamNewItems.mutate(@(v) v[inventoryItemId] <- steamItem)
      logS($"Not found inventory item by steam itemDef {itemDef}", steamItem)
      continue
    }

    if (itemId in inqueueSteamItems.get()) {
      logS($"Try to show duplicate {itemDef}. Ignore")
      continue
    }

    newItems.append({
      steamItemId = itemId
      item
    })
  }

  tryShowSteamItemsNotificationOnUpdate(newItems)
}

function requestRewardsAndCheckSteamInventory() {
  requestAllItems(function(res) {
    steamNewItems.set(res?.items ?? [])
    steamCheckNewItems()
  })
}

function checkUnknownItems() {
  if (unknownSteamNewItems.get().len() == 0)
    return

  logS("Check unknown items", unknownSteamNewItems.get())
  let knownItems = []
  foreach (itemDef, sItem in unknownSteamNewItems.get()) {
    if (findItemById(itemDef)) {
      knownItems.append(sItem)
      let itemDefId = itemDef
      unknownSteamNewItems.mutate(@(v) v.$rawdelete(itemDefId))
    }
  }

  logS("Left unknown items", unknownSteamNewItems.get())
  if (!knownItems.len())
    return

  steamNewItems.set(knownItems)
  steamCheckNewItems()
}

register_command(function(itemId = 20366) {
  let inventoryItemId = steamItemdefidToInventoryItemdefid?[itemId] ?? itemId
  let item = getInventoryItemById(inventoryItemId)
  if (item == null)
    return
  showSteamItemNotification({
    item
    steamItemId = 4495219818634627298
  })
}, "debug.showSteamItemNotification")

addListenersWithoutEnv({
  LoginComplete = @(_) requestRewardsAndCheckSteamInventory()
  ItemsShopUpdate = @(_) checkUnknownItems()
  SignOut = @(_) inqueueSteamItems.set({})
})

return freeze({
  steamCheckNewItems
})