local subscriptions = require("sqStdLibs/helpers/subscriptions.nut")
local seenList = require("scripts/seen/seenList.nut").get(SEEN.EXT_XBOX_SHOP)
local statsd = require("statsd")
local progressMsg = require("sqDagui/framework/progressMsg.nut")

local XboxShopPurchasableItem = require("scripts/onlineShop/XboxShopPurchasableItem.nut")

const XBOX_RECEIVE_CATALOG_MSG_ID = "XBOX_RECEIVE_CATALOG"

local itemsList = persist("itemsList", @() {})

local visibleSeenIds = []
local xboxProceedItems = {}

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
    ::dagor.debug("XBOX SHOP: Empty catalog. Don't open shop.")
    return
  }

  local xboxShopBlk = ::configs.GUI.get()?.xbox_ingame_shop
  local skipItemsList = xboxShopBlk?.itemsHide ?? ::DataBlock()
  xboxProceedItems.clear()
  itemsList.clear()
  for (local i = 0; i < catalog.blockCount(); i++)
  {
    local itemBlock = catalog.getBlock(i)
    if (itemBlock.getBlockName() in skipItemsList)
    {
      ::dagor.debug("XBOX SHOP: SKIP: " + itemBlock.Name + " by id " + itemBlock.getBlockName())
      continue
    }

    local item = XboxShopPurchasableItem(itemBlock)
    if (!(item.mediaItemType in xboxProceedItems))
      xboxProceedItems[item.mediaItemType] <- []
    xboxProceedItems[item.mediaItemType].append(item)
    itemsList[item.id] <- item
  }

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

local requestData = function(isSilent = false, cb = null, invSeenList = false, metric = "unknown")
{
  if (!::is_platform_xbox)
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

local canUseIngameShop = @() ::is_platform_xbox && ::has_feature("XboxIngameShop")

local getVisibleSeenIds = function()
{
  if (!visibleSeenIds.len() && xboxProceedItems.len())
  {
    foreach (mediaType, items in xboxProceedItems)
      visibleSeenIds.extend(items.filter(@(it) !it.canBeUnseen()).map(@(it) it.getSeenId()))
  }
  return visibleSeenIds
}

seenList.setListGetter(getVisibleSeenIds)

local isItemsInitedOnce = false
local initXboxItemsListAfterLogin = function()
{
  if (canUseIngameShop() && !isItemsInitedOnce)
  {
    isItemsInitedOnce = true
    requestData(true, null, true)
  }
}

local haveAnyItemWithDiscount = function()
{
  if (!xboxProceedItems.len())
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

local haveDiscount = function()
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
    xboxProceedItems.clear()
    visibleSeenIds.clear()
    haveItemDiscount = null
  }
}, ::g_listener_priority.CONFIG_VALIDATION)

return {
  canUseIngameShop = canUseIngameShop
  requestData = requestData
  xboxProceedItems = xboxProceedItems
  getShopItemsTable = @() itemsList
  haveDiscount = haveDiscount
  getShopItem = @(id) itemsList?[id]
}
