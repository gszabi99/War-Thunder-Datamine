from "%scripts/dagui_library.nut" import *
from "%scripts/mainConsts.nut" import SEEN

let g_listener_priority = require("%scripts/g_listener_priority.nut")
let subscriptions = require("%sqStdLibs/helpers/subscriptions.nut")
let { broadcastEvent } = subscriptions
let datablock = require("DataBlock")

let seenList = require("%scripts/seen/seenList.nut").get(SEEN.EXT_PS4_SHOP)
let storeData = require("%sonyLib/storeData.nut")

let { isPlatformSony } = require("%scripts/clientState/platform.nut")

let psnStoreItem = require("%scripts/onlineShop/psnStoreItem.nut")
let { GUI } = require("%scripts/utils/configs.nut")

let PS4ShopData = {
  categoriesData = datablock() 
  itemsList = {} 
}

local isFinishedUpdateItems = false 
local invalidateSeenList = false
let visibleSeenIds = []

let getShopItem = @(id) PS4ShopData.itemsList?[id]

let canUseIngameShop = @() isPlatformSony && hasFeature("PS4IngameShop")

local haveItemDiscount = null


function onFinishCollectData(v_categoriesData = null) {
  if (!canUseIngameShop())
    return

  PS4ShopData.categoriesData.setFrom(v_categoriesData)
  isFinishedUpdateItems = true
  haveItemDiscount = null

  if (invalidateSeenList) {
    visibleSeenIds.clear()
    seenList.onListChanged()
  }
  invalidateSeenList = false

  local itemIndex = 0
  foreach (_category, categoryInfo in PS4ShopData.categoriesData)
    foreach (label, itemInfo in (categoryInfo?.links ?? datablock()))
      PS4ShopData.itemsList[label] <- psnStoreItem(itemInfo, itemIndex++)

  
  log("PSN: Shop Data: Finish update items info")
  broadcastEvent("Ps4ShopDataUpdated", { isLoadingInProgress = false })
}

function filterFunc(label) {
 
  let skipItemsList = GUI.get()?.ps4_ingame_shop.itemsHide ?? datablock()
  return label in skipItemsList
}

local isCategoriesInitedOnce = false
function initPs4CategoriesAfterLogin() {
  if (!isCategoriesInitedOnce && canUseIngameShop()) {
    PS4ShopData.categoriesData.reset()

    isCategoriesInitedOnce = true
    invalidateSeenList = true
    isFinishedUpdateItems = false
    broadcastEvent("Ps4ShopDataUpdated", { isLoadingInProgress = true })

    storeData.request(onFinishCollectData, filterFunc)
  }
}
initPs4CategoriesAfterLogin()

function getVisibleSeenIds() {
  if (isFinishedUpdateItems && !visibleSeenIds.len() && PS4ShopData.categoriesData.blockCount() && PS4ShopData.itemsList.len()) {
    for (local i = 0; i < PS4ShopData.categoriesData.blockCount(); i++) {
      let productsList = PS4ShopData.categoriesData.getBlock(i)?.links
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

function haveAnyItemWithDiscount() {
  if (!PS4ShopData.itemsList.len())
    return false

  if (haveItemDiscount != null)
    return haveItemDiscount

  haveItemDiscount = false
  foreach (item in PS4ShopData.itemsList)
    if (item.haveDiscount()) {
      haveItemDiscount = true
      break
    }

  return haveItemDiscount
}

function haveDiscount() {
  if (!canUseIngameShop())
    return false

  if (!isCategoriesInitedOnce) {
    initPs4CategoriesAfterLogin()
    return false
  }

  return haveAnyItemWithDiscount()
}




function onSuccessCb(itemsArray) {
  foreach (itemData in itemsArray) {
    let itemId = itemData.label
    let shopItem = getShopItem(itemId)

    shopItem.updateSkuInfo(itemData)
  }

  
  broadcastEvent("PS4IngameShopUpdate")
}

function updateSpecificItemInfo(id) {
  storeData.updateSpecificItemInfo([id], onSuccessCb)
}

subscriptions.addListenersWithoutEnv({
  PS4ItemUpdate = @(p) updateSpecificItemInfo(p.id)
  ProfileUpdated = @(_p) initPs4CategoriesAfterLogin()
  function SignOut(_p) {
    isCategoriesInitedOnce = false
    isFinishedUpdateItems = false
    PS4ShopData.categoriesData.reset()
    PS4ShopData.itemsList.clear()
    visibleSeenIds.clear()
    haveItemDiscount = null
  }
}, g_listener_priority.CONFIG_VALIDATION)

return {
  canUseIngameShop
  haveDiscount

  getShopData = @() PS4ShopData.categoriesData
  getShopItemsTable = @() PS4ShopData.itemsList
  getShopItem

  isItemsUpdated = @() isFinishedUpdateItems
  needEntStoreDiscountIcon = true
}
