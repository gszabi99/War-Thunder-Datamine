from "%scripts/dagui_library.nut" import *

let { requestAllItems } = require("%scripts/inventory/steamInventory.nut")
let ExchangeRecipes = require("%scripts/items/exchangeRecipes.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let logS = log_with_prefix("[Steam Items] ")

let steamNewItems = persist("steamNewItems", @() Watched([]))
wlog(steamNewItems, "[Steam Items]: newitems ")
let unknownSteamNewItems = persist("unknownSteamNewItems", @() Watched([]))
wlog(unknownSteamNewItems, "[Steam Items]: unknownSteamNewItems ")
let inqueueSteamItems = persist("inqueueSteamItems", @() Watched({}))
wlog(inqueueSteamItems, "[Steam Items]: inqueueSteamItems ")


let showSteamItemNotification = function(itemInfo) {
  let { item, steamItemId } = itemInfo
  ::showUnlockWnd({
    name = item.getName(false)
    desc = item.getLongDescription()
    popupImage = item.getIconName()
    ratioHeight = 1.0
    onDestroyFunc = function() {
      inqueueSteamItems.mutate(@(v) delete v[steamItemId])
      ExchangeRecipes.tryUse(item.getRelatedRecipes(), item, { shouldSkipMsgBox = true })
    }
    okBtnText = loc("items/getReward")
    okBtnStyle = "secondary"
  })
}

let function tryShowSteamItemsNotification(items = []) {
  if (!::isInMenu() || ::checkIsInQueue())
    return

  items.each(function(itemInfo) {
    inqueueSteamItems.mutate(@(v) v[itemInfo.steamItemId] <- true)
    showSteamItemNotification(itemInfo)
  })
  steamNewItems.update([])
}

let function tryShowSteamItemsNotificationOnUpdate(items = []) {
  let newItems = items
  let handler = ::handlersManager.getActiveBaseHandler()
  let handlerClass = handler?.getclass()
  if (handler?.isValid() && handlerClass == ::gui_handlers.MainMenu)
    handler.doWhenActive(@() tryShowSteamItemsNotification(newItems))
}

let function steamCheckNewItems() {
  let newItems = []
  foreach (sItem in steamNewItems.value) {
    let itemDefId = sItem.itemDef
    let item = ::ItemsManager.getInventoryItemById(itemDefId)
    if (!item) {
      if (!unknownSteamNewItems.value.contains(itemDefId))
        unknownSteamNewItems.mutate(@(v) v.append(itemDefId))
      logS($"Not found inventory item by steam itemDef {itemDefId}", sItem)
      continue
    }

    if (sItem.itemId in inqueueSteamItems.value) {
      logS($"Try to show duplicate {itemDefId}. Ignore")
      continue
    }

    newItems.append({
      steamItemId = sItem.itemId
      item
    })
  }

  tryShowSteamItemsNotificationOnUpdate(newItems)
}

let function requestRewardsAndCheckSteamInventory() {
  requestAllItems(function(res) {
    steamNewItems.update(res?.items ?? [])
    steamCheckNewItems()
  })
}

let function checkUnknownItems() {
  if (unknownSteamNewItems.value.len() == 0)
    return

  logS("Check unknown items", unknownSteamNewItems.value)
  local isListChanged = false
  for (local i = unknownSteamNewItems.value.len() - 1; i >= 0; i--) {
    let itemDefId = unknownSteamNewItems.value[i]
    if (::ItemsManager.findItemById(itemDefId)) {
      unknownSteamNewItems.mutate(@(v) v.remove(i))
      isListChanged = true
    }
  }

  logS("Left unknown items", unknownSteamNewItems.value)
  if (isListChanged)
    requestRewardsAndCheckSteamInventory()
}

addListenersWithoutEnv({
  LoginComplete = function(_) {
    inqueueSteamItems({})
    requestRewardsAndCheckSteamInventory()
  }
  ItemsShopUpdate = @(_) checkUnknownItems()
})

return {
  steamCheckNewItems
}