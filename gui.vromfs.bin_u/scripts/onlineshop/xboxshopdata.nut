from "%scripts/dagui_library.nut" import *
from "%scripts/mainConsts.nut" import SEEN

let g_listener_priority = require("%scripts/g_listener_priority.nut")
let DataBlock = require("DataBlock")
let subscriptions = require("%sqStdLibs/helpers/subscriptions.nut")
let { broadcastEvent } = subscriptions
let seenList = require("%scripts/seen/seenList.nut").get(SEEN.EXT_XBOX_SHOP)
let statsd = require("statsd")
let progressMsg = require("%sqDagui/framework/progressMsg.nut")
let { GUI } = require("%scripts/utils/configs.nut")
let { isPlatformXboxOne } = require("%scripts/clientState/platform.nut")

let XboxShopPurchasableItem = require("%scripts/onlineShop/XboxShopPurchasableItem.nut")
let { gather_products_list } = require("%xboxLib/impl/store.nut")

const XBOX_RECEIVE_CATALOG_MSG_ID = "XBOX_RECEIVE_CATALOG"

let itemsList = persist("itemsList", @() {})

let visibleSeenIds = []
let xboxProceedItems = Watched({})

local onReceiveCatalogCb = null
local statsdMetric = "unknown"
local reqProgressMsg = false
local invalidateSeenList = false
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

  xboxProceedItems(xbItems)

  if (invalidateSeenList) {
    visibleSeenIds.clear()
    seenList.onListChanged()
  }
  invalidateSeenList = false

  statsd.send_counter("sq.ingame_store.open", 1, { catalog = statsdMetric })
  if (onReceiveCatalogCb)
    onReceiveCatalogCb()
  onReceiveCatalogCb = null
  statsdMetric = "unknown"

  broadcastEvent("XboxShopDataUpdated")
}

let requestData = function(isSilent = false, cb = null, invSeenList = false, metric = "unknown") {
  if (!isPlatformXboxOne)
    return

  onReceiveCatalogCb = cb
  statsdMetric = metric
  reqProgressMsg = !isSilent
  invalidateSeenList = invSeenList
  haveItemDiscount = null

  if (reqProgressMsg)
    progressMsg.create(XBOX_RECEIVE_CATALOG_MSG_ID, null)

  gather_products_list(on_xbox_products_list_update)
}

let canUseIngameShop = @() isPlatformXboxOne && hasFeature("XboxIngameShop")

let getVisibleSeenIds = function() {
  if (!visibleSeenIds.len() && xboxProceedItems.value.len()) {
    foreach (_, items in xboxProceedItems.value)
      visibleSeenIds.extend(items.filter(@(it) !it.canBeUnseen()).map(@(it) it.getSeenId()))
  }
  return visibleSeenIds
}

seenList.setListGetter(getVisibleSeenIds)

local isItemsInitedOnce = false
let initXboxItemsListAfterLogin = function() {
  if (canUseIngameShop() && !isItemsInitedOnce) {
    isItemsInitedOnce = true
    requestData(true, null, true)
  }
}

let haveAnyItemWithDiscount = function() {
  if (!xboxProceedItems.value.len())
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
    xboxProceedItems({})
    visibleSeenIds.clear()
    haveItemDiscount = null
  }
}, g_listener_priority.CONFIG_VALIDATION)

return {
  canUseIngameShop
  requestData
  xboxProceedItems
  getShopItemsTable = @() itemsList
  haveDiscount
  getShopItem = @(id) itemsList?[id]
  needEntStoreDiscountIcon = true
}
