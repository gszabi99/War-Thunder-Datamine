let stdLog = require("std/log.nut")()
const LOG_PREFIX = "[EpicStore] "
let log = stdLog.with_prefix(LOG_PREFIX)
let logerr = stdLog.logerr

let statsd = require("statsd")
let subscriptions = require("sqStdLibs/helpers/subscriptions.nut")
let seenList = require("scripts/seen/seenList.nut").get(SEEN.EXT_EPIC_SHOP)

let EpicShopPurchasableItem = require("scripts/onlineShop/EpicShopPurchasableItem.nut")

let canUseIngameShop = ::epic_is_running

let shopItemsQueryResult = persist("shopItemsQueryResult", @() ::Watched(null)) //DataBlock
let isLoadingInProgress = ::Watched(false)
let isInitedOnce = ::Watched(false)

local onItemsReceivedCb = null

isLoadingInProgress.subscribe(@(val)
  ::broadcastEvent("EpicShopDataUpdated", {isLoadingInProgress = val})
)

let function requestData(cb = null) {
  log($"Requested store info: cb = {cb}")
  isLoadingInProgress(true)

  onItemsReceivedCb = cb

  ::epic_get_shop_items_async()
}

isInitedOnce.subscribe(function(val) {
  if (!val || !canUseIngameShop())
    return

  log($"Init Once")
  requestData()
})

shopItemsQueryResult.subscribe(function(v) {
  isLoadingInProgress(false)

  if (!v || !v.blockCount()) {
    statsd.send_counter("sq.ingame_store.open.empty_catalog", 1)
    logerr($"{LOG_PREFIX}Empty catalog. Don't open shop")
    return
  }
})

let epicCatalog = ::Computed(function() {
  if (!shopItemsQueryResult.value)
    return {}

  let res = {}
  for (local i = 0; i < shopItemsQueryResult.value.blockCount(); i++) {
    let itemBlk = shopItemsQueryResult.value.getBlock(i)
    let item = EpicShopPurchasableItem(itemBlk)
    if (!(item.mediaItemType in res))
      res[item.mediaItemType] <- []
    res[item.mediaItemType].append(item)
  }
  return res
})

let epicItems = ::Computed(function() {
  let res = {}
  epicCatalog.value.each(@(itemsList, m) itemsList.each(@(item, idx) res[item.id] <- item))
  return res
})

epicItems.subscribe(function(_) {
  if (onItemsReceivedCb) {
    onItemsReceivedCb()
    onItemsReceivedCb = null
  }

  seenList.onListChanged()
})

let visibleSeenIds = ::Computed(function() {
  let res = []
  epicCatalog.value.each(@(itemsList, m)
    res.extend(itemsList.filter(@(it) !it.canBeUnseen()).map(@(it) it.getSeenId()))
  )

  return res
})

seenList.setListGetter(@() visibleSeenIds.value )

let function invaldateCache() {
  isInitedOnce(false)
}

let function updateSpecificItemInfo(itemId) {
  if (!itemId)
    return

  ::epic_get_shop_item_async(itemId)
}

let function onUpdateItemCb(blk) {
  ::epic_update_purchases_on_auth()
  ::g_tasker.addTask( ::update_entitlements_limited(true) )

  let itemId = blk.id
  if (!epicItems.value?[itemId]) {
    logerr($"{LOG_PREFIX}onUpdateItemCb: item {itemId} not in items list")
    return
  }

  epicItems.value[itemId].update(blk)
  ::broadcastEvent("EpicShopItemUpdated", {item = epicItems.value[itemId]})
}

let haveAnyItemWithDiscount = ::Computed(@()
  epicItems.value.findindex(@(v) v.haveDiscount()) != null
)

let initItemsListAfterLogin = @() isInitedOnce(true)

let function haveDiscount() {
  if (!canUseIngameShop())
    return false

  if (!isInitedOnce.value) {
    initItemsListAfterLogin()
    return false
  }

  return haveAnyItemWithDiscount.value
}

subscriptions.addListenersWithoutEnv({
  LoginComplete = @(p) initItemsListAfterLogin()
  SignOut = @(p) invaldateCache()
  ScriptsReloaded = function(p) {
    invaldateCache()
    initItemsListAfterLogin()
  }
}, ::g_listener_priority.CONFIG_VALIDATION)

::getroottable()["epic_shop_items_callback"] <- @(res) shopItemsQueryResult(res)
::getroottable()["epic_shop_item_purchased_callback"] <- updateSpecificItemInfo
::getroottable()["epic_shop_item_callback"] <- onUpdateItemCb

return {
  canUseIngameShop
  requestData
  haveDiscount
  getShopItemsTable = @() epicItems.value
  getShopItem = @(id) epicItems.value?[id]
  catalog = epicCatalog
  isLoadingInProgress
}