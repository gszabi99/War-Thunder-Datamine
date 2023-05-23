//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { registerPersistentData } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")
let subscriptions = require("%sqStdLibs/helpers/subscriptions.nut")
let { broadcastEvent } = subscriptions
let datablock = require("DataBlock")

let seenList = require("%scripts/seen/seenList.nut").get(SEEN.EXT_PS4_SHOP)
let storeData = require("%sonyLib/storeData.nut")

let { isPlatformSony } = require("%scripts/clientState/platform.nut")

let psnStoreItem = require("%scripts/onlineShop/psnStoreItem.nut")
let { GUI } = require("%scripts/utils/configs.nut")

let persistent = {
  categoriesData = datablock() // Collect one time in a session, reset on relogin
  itemsList = {} //Updatable during game
}
registerPersistentData("PS4ShopData", persistent, ["categoriesData", "itemsList"])



local isFinishedUpdateItems = false //Status of FULL update items till creating list of classes psnStoreItem
local invalidateSeenList = false
let visibleSeenIds = []

let getShopItem = @(id) persistent.itemsList?[id]

let canUseIngameShop = @() isPlatformSony && hasFeature("PS4IngameShop")

local haveItemDiscount = null

// Calls on finish updating skus extended info
let onFinishCollectData = function(v_categoriesData = null) {
  if (!canUseIngameShop())
    return

  persistent.categoriesData.setFrom(v_categoriesData)
  isFinishedUpdateItems = true
  haveItemDiscount = null

  if (invalidateSeenList) {
    visibleSeenIds.clear()
    seenList.onListChanged()
  }
  invalidateSeenList = false

  local itemIndex = 0
  foreach (_category, categoryInfo in persistent.categoriesData)
    foreach (label, itemInfo in (categoryInfo?.links ?? datablock()))
      persistent.itemsList[label] <- psnStoreItem(itemInfo, itemIndex++)

  //Must call in the end
  log("PSN: Shop Data: Finish update items info")
  broadcastEvent("Ps4ShopDataUpdated", { isLoadingInProgress = false })
}

let filterFunc = function(label) {
 //Check gui.blk for skippable items
  let skipItemsList = GUI.get()?.ps4_ingame_shop.itemsHide ?? datablock()
  return label in skipItemsList
}

local isCategoriesInitedOnce = false
let initPs4CategoriesAfterLogin = function() {
  if (!isCategoriesInitedOnce && canUseIngameShop()) {
    persistent.categoriesData.reset()

    isCategoriesInitedOnce = true
    invalidateSeenList = true
    isFinishedUpdateItems = false
    broadcastEvent("Ps4ShopDataUpdated", { isLoadingInProgress = true })

    storeData.request(onFinishCollectData, filterFunc)
  }
}


let getVisibleSeenIds = function() {
  if (isFinishedUpdateItems && !visibleSeenIds.len() && persistent.categoriesData.blockCount() && persistent.itemsList.len()) {
    for (local i = 0; i < persistent.categoriesData.blockCount(); i++) {
      let productsList = persistent.categoriesData.getBlock(i)?.links
      if (productsList == null)
        continue

      for (local j = 0; j < productsList.blockCount(); j++) {
        let item = getShopItem(productsList.getBlock(j).getBlockName())
        if (!item)
          continue

        if (!item.canBeUnseen())
          visibleSeenIds.append(item.getSeenId())
      }
    }
  }
  return visibleSeenIds
}

seenList.setListGetter(getVisibleSeenIds)

let haveAnyItemWithDiscount = function() {
  if (!persistent.itemsList.len())
    return false

  if (haveItemDiscount != null)
    return haveItemDiscount

  haveItemDiscount = false
  foreach (item in persistent.itemsList)
    if (item.haveDiscount()) {
      haveItemDiscount = true
      break
    }

  return haveItemDiscount
}

let haveDiscount = function() {
  if (!canUseIngameShop())
    return false

  if (!isCategoriesInitedOnce) {
    initPs4CategoriesAfterLogin()
    return false
  }

  return haveAnyItemWithDiscount()
}

// For updating single info and send event for updating it in shop, if opened
// We can remake on array of item labels,
// but for now require only for single item at once.
let function onSuccessCb(itemsArray) {
  foreach (itemData in itemsArray) {
    let itemId = itemData.label
    let shopItem = getShopItem(itemId)

    shopItem.updateSkuInfo(itemData)
  }

  // Send event for updating items in shop
  broadcastEvent("PS4IngameShopUpdate")
}

let updateSpecificItemInfo = function(id) {
  storeData.updateSpecificItemInfo([id], onSuccessCb)
}

subscriptions.addListenersWithoutEnv({
  PS4ItemUpdate = @(p) updateSpecificItemInfo(p.id)
  ProfileUpdated = @(_p) initPs4CategoriesAfterLogin()
  ScriptsReloaded = function(_p) {
    visibleSeenIds.clear()
    persistent.itemsList.clear()
    isCategoriesInitedOnce = false
    initPs4CategoriesAfterLogin()
  }
  SignOut = function(_p) {
    isCategoriesInitedOnce = false
    isFinishedUpdateItems = false
    persistent.categoriesData.reset()
    persistent.itemsList.clear()
    visibleSeenIds.clear()
    haveItemDiscount = null
  }
}, ::g_listener_priority.CONFIG_VALIDATION)

return {
  canUseIngameShop = canUseIngameShop
  haveDiscount = haveDiscount

  getData = @() persistent.categoriesData
  getShopItemsTable = @() persistent.itemsList
  getShopItem = getShopItem

  isItemsUpdated = @() isFinishedUpdateItems
}
