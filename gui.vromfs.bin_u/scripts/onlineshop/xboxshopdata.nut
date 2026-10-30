import "%scripts/g_listener_priority.nut" as g_listener_priority
import "%sqStdLibs/helpers/subscriptions.nut" as subscriptions
import "%scripts/sqDagui/framework/progressMsg.nut" as progressMsg
import "DataBlock" as DataBlock
from "%sqstd/platform.nut" import is_gdk
from "%gdkLib/impl/store.nut" import gather_products_list
from "%scripts/dagui_library.nut" import *
from "%scripts/seen/seenIds.nut" import SEEN

let { broadcastEvent } = subscriptions
let seenList = require("%scripts/seen/seenList.nut").get(SEEN.EXT_XBOX_SHOP)
let { GUI } = require("%scripts/utils/configs.nut")

let XboxShopPurchasableItem = require("%scripts/onlineShop/XboxShopPurchasableItem.nut")

const XBOX_RECEIVE_CATALOG_MSG_ID = "XBOX_RECEIVE_CATALOG"

let itemsList = {}

let visibleSeenIds = []
let xboxProceedItems = mkWatchedClearedOnReload({})

local onReceiveCatalogCb = null
local reqProgressMsg = false
local haveItemDiscount = null

function on_xbox_products_list_update(success, products) {
  log($"XBOX SHOP: products list update succeeded: {success}")
  if (reqProgressMsg)
    progressMsg.destroy(XBOX_RECEIVE_CATALOG_MSG_ID)
  reqProgressMsg = false
  if (!success)
    return

  let xboxShopBlk = GUI.get()?.xbox_ingame_shop
  let skipItemsList = xboxShopBlk?.itemsHide ?? DataBlock()

  let xbItems = {}
  itemsList.clear()

  foreach (product in products) {
    if (product.store_id in skipItemsList) {
      log($"XBOX SHOP: SKIP: {product.title} by id {product.store_id}")
      continue
    }

    let item = XboxShopPurchasableItem(product)
    foreach (xbItemType in item.categoriesList) {
      if (!(xbItemType in xbItems))
        xbItems[xbItemType] <- []
      xbItems[xbItemType].append(item)
    }

    itemsList[item.id] <- item
  }

  xboxProceedItems.set(xbItems)

  visibleSeenIds.clear()
  seenList.onListChanged()
  if (onReceiveCatalogCb)
    onReceiveCatalogCb()
  onReceiveCatalogCb = null

  broadcastEvent("XboxShopDataUpdated")
}

let requestData = function(isSilent = false, cb = null) {
  if (!is_gdk)
    return

  onReceiveCatalogCb = cb
  reqProgressMsg = !isSilent
  haveItemDiscount = null

  if (reqProgressMsg)
    progressMsg.create(XBOX_RECEIVE_CATALOG_MSG_ID, null)

  gather_products_list(on_xbox_products_list_update)
}

let canUseIngameShop = @() is_gdk && hasFeature("XboxIngameShop")

let getVisibleSeenIds = function() {
  if (!visibleSeenIds.len() && xboxProceedItems.get().len()) {
    foreach (_, items in xboxProceedItems.get())
      visibleSeenIds.extend(items.filter(@(it) !it.canBeUnseen()).map(@(it) it.getSeenId()))
  }
  return visibleSeenIds
}

seenList.setListGetter(getVisibleSeenIds)

local isItemsInitedOnce = false
let initXboxItemsListAfterLogin = function() {
  if (canUseIngameShop() && !isItemsInitedOnce) {
    isItemsInitedOnce = true
    requestData(true)
  }
}

let haveAnyItemWithDiscount = function() {
  if (!xboxProceedItems.get().len())
    return false

  if (haveItemDiscount != null)
    return haveItemDiscount

  haveItemDiscount = false
  foreach (item in itemsList)
    if (item.haveDiscount()) {
      haveItemDiscount = true
      break
    }

  return haveItemDiscount
}

let haveDiscount = function() {
  if (!canUseIngameShop())
    return false

  if (!isItemsInitedOnce) {
    initXboxItemsListAfterLogin()
    return false
  }

  return haveAnyItemWithDiscount()
}

subscriptions.addListenersWithoutEnv({
  ProfileUpdated = @(_p) initXboxItemsListAfterLogin()
  SignOut = function(_p) {
    isItemsInitedOnce = false
    xboxProceedItems.set({})
    visibleSeenIds.clear()
    haveItemDiscount = null
  }
}, g_listener_priority.CONFIG_VALIDATION)

return freeze({
  canUseIngameShop
  requestData
  xboxProceedItems
  getShopItemsTable = @() itemsList
  haveDiscount
  getShopItem = @(id) itemsList?[id]
  needEntStoreDiscountIcon = true
})
