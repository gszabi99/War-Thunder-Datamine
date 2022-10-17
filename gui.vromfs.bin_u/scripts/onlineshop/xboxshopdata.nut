from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let subscriptions = require("%sqStdLibs/helpers/subscriptions.nut")
let seenList = require("%scripts/seen/seenList.nut").get(SEEN.EXT_XBOX_SHOP)
let statsd = require("statsd")
let progressMsg = require("%sqDagui/framework/progressMsg.nut")
let { GUI } = require("%scripts/utils/configs.nut")

let XboxShopPurchasableItem = require("%scripts/onlineShop/XboxShopPurchasableItem.nut")

const XBOX_RECEIVE_CATALOG_MSG_ID = "XBOX_RECEIVE_CATALOG"

let itemsList = persist("itemsList", @() {})

let visibleSeenIds = []
let xboxProceedItems = Watched({})

local onReceiveCatalogCb = null
local statsdMetric = "unknown"
local reqProgressMsg = false
local invalidateSeenList = false
local haveItemDiscount = null
::xbox_browse_catalog_callback <- function(catalog)
{
  if (!catalog || !catalog.blockCount())
  {
    statsd.send_counter("sq.ingame_store.open.empty_catalog", 1, {catalog = statsdMetric})
    log("XBOX SHOP: Empty catalog. Don't open shop.")
    return
  }

  let xboxShopBlk = GUI.get()?.xbox_ingame_shop
  let skipItemsList = xboxShopBlk?.itemsHide ?? ::DataBlock()

  let xbItems = {}
  itemsList.clear()
  for (local i = 0; i < catalog.blockCount(); i++)
  {
    let itemBlock = catalog.getBlock(i)
    if (itemBlock.getBlockName() in skipItemsList)
    {
      log("XBOX SHOP: SKIP: " + itemBlock.Name + " by id " + itemBlock.getBlockName())
      continue
    }

    let item = XboxShopPurchasableItem(itemBlock)
    foreach (xbItemType in item.categoryId) {
      if (!(xbItemType in xbItems))
        xbItems[xbItemType] <- []
      xbItems[xbItemType].append(item)
    }

    itemsList[item.id] <- item
  }

  xboxProceedItems(xbItems)

  if (invalidateSeenList)
  {
    visibleSeenIds.clear()
    seenList.onListChanged()
  }
  invalidateSeenList = false

  if (reqProgressMsg)
    progressMsg.destroy(XBOX_RECEIVE_CATALOG_MSG_ID)
  reqProgressMsg = false

  statsd.send_counter("sq.ingame_store.open", 1, {catalog = statsdMetric})
  if (onReceiveCatalogCb)
    onReceiveCatalogCb()
  onReceiveCatalogCb = null
  statsdMetric = "unknown"

  ::broadcastEvent("XboxShopDataUpdated")
}

let requestData = function(isSilent = false, cb = null, invSeenList = false, metric = "unknown")
{
  if (!is_platform_xbox)
    return

  onReceiveCatalogCb = cb
  statsdMetric = metric
  reqProgressMsg = !isSilent
  invalidateSeenList = invSeenList
  haveItemDiscount = null

  if (reqProgressMsg)
    progressMsg.create(XBOX_RECEIVE_CATALOG_MSG_ID, null)

  ::xbox_browse_catalog_async()

  /* Debug Purpose Only
  {
    local blk = ::DataBlock()
    blk.load("browseCatalog.blk")
    ::xbox_browse_catalog_callback(blk)
  }
  */
}

let canUseIngameShop = @() is_platform_xbox && hasFeature("XboxIngameShop")

let getVisibleSeenIds = function()
{
  if (!visibleSeenIds.len() && xboxProceedItems.value.len())
  {
    foreach (_, items in xboxProceedItems.value)
      visibleSeenIds.extend(items.filter(@(it) !it.canBeUnseen()).map(@(it) it.getSeenId()))
  }
  return visibleSeenIds
}

seenList.setListGetter(getVisibleSeenIds)

local isItemsInitedOnce = false
let initXboxItemsListAfterLogin = function()
{
  if (canUseIngameShop() && !isItemsInitedOnce)
  {
    isItemsInitedOnce = true
    requestData(true, null, true)
  }
}

let haveAnyItemWithDiscount = function()
{
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

let haveDiscount = function()
{
  if (!canUseIngameShop())
    return false

  if (!isItemsInitedOnce)
  {
    initXboxItemsListAfterLogin()
    return false
  }

  return haveAnyItemWithDiscount()
}

subscriptions.addListenersWithoutEnv({
  ProfileUpdated = @(p) initXboxItemsListAfterLogin()
  SignOut = function(p) {
    isItemsInitedOnce = false
    xboxProceedItems({})
    visibleSeenIds.clear()
    haveItemDiscount = null
  }
}, ::g_listener_priority.CONFIG_VALIDATION)

return {
  canUseIngameShop
  requestData
  xboxProceedItems
  getShopItemsTable = @() itemsList
  haveDiscount
  getShopItem = @(id) itemsList?[id]
}
