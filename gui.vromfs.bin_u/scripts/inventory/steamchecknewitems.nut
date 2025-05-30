from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { requestAllItems } = require("%scripts/inventory/steamInventory.nut")
let { tryUseRecipes } = require("%scripts/items/exchangeRecipes.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { isInMenu } = require("%scripts/clientState/clientStates.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { register_command } = require("console")
let logS = log_with_prefix("[Steam Items] ")
let { findItemById, getInventoryItemById } = require("%scripts/items/itemsManager.nut")
let { showUnlockWnd } = require("%scripts/unlocks/showUnlockWnd.nut")
let { isAnyQueuesActive } = require("%scripts/queue/queueState.nut")

let steamNewItems = mkWatched(persist, "steamNewItems", [])
wlog(steamNewItems, "[Steam Items]: newitems ")
let unknownSteamNewItems = mkWatched(persist, "unknownSteamNewItems",{})
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
  steamNewItems.update([])
}

function tryShowSteamItemsNotificationOnUpdate(items = []) {
  let newItems = items
  let handler = handlersManager.getActiveBaseHandler()
  let handlerClass = handler?.getclass()
  if (handler?.isValid() && handlerClass == gui_handlers.MainMenu)
    handler.doWhenActive(@() tryShowSteamItemsNotification(newItems))
}

function steamCheckNewItems() {
  let newItems = []
  foreach (sItem in steamNewItems.value) {
    let steamItem = sItem
    let { itemDef, itemId } = steamItem
    let inventoryItemId = steamItemdefidToInventoryItemdefid?[itemDef] ?? itemDef
    let item = getInventoryItemById(inventoryItemId)
    if (!item) {
      if (inventoryItemId not in unknownSteamNewItems.value)
        unknownSteamNewItems.mutate(@(v) v[inventoryItemId] <- steamItem)
      logS($"Not found inventory item by steam itemDef {itemDef}", steamItem)
      continue
    }

    if (itemId in inqueueSteamItems.value) {
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
    steamNewItems.update(res?.items ?? [])
    steamCheckNewItems()
  })
}

function checkUnknownItems() {
  if (unknownSteamNewItems.value.len() == 0)
    return

  logS("Check unknown items", unknownSteamNewItems.value)
  let knownItems = []
  foreach (itemDef, sItem in unknownSteamNewItems.value) {
    if (findItemById(itemDef)) {
      knownItems.append(sItem)
      let itemDefId = itemDef
      unknownSteamNewItems.mutate(@(v) v.$rawdelete(itemDefId))
    }
  }

  logS("Left unknown items", unknownSteamNewItems.value)
  if (!knownItems.len())
    return

  steamNewItems.update(knownItems)
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
  SignOut = @(_) inqueueSteamItems({})
})

return {
  steamCheckNewItems
}