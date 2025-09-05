from "%scripts/dagui_natives.nut" import epic_is_running, epic_update_purchases_on_auth, epic_get_shop_item_async, epic_get_shop_items_async
from "%scripts/dagui_library.nut" import *
from "%scripts/mainConsts.nut" import SEEN

let g_listener_priority = require("%scripts/g_listener_priority.nut")
let statsd = require("statsd")
let subscriptions = require("%sqStdLibs/helpers/subscriptions.nut")
let { broadcastEvent } = subscriptions
let { eventbus_subscribe } = require("eventbus")
let seenList = require("%scripts/seen/seenList.nut").get(SEEN.EXT_EPIC_SHOP)

let EpicShopPurchasableItem = require("%scripts/onlineShop/EpicShopPurchasableItem.nut")
let { addTask } = require("%scripts/tasker.nut")
let { updateEntitlementsLimited } = require("%scripts/onlineShop/entitlementsUpdate.nut")

const LOG_PREFIX = "[EpicStore] "
let logS = log_with_prefix(LOG_PREFIX)

let canUseIngameShop = epic_is_running

let shopItemsQueryResult = mkWatched(persist, "shopItemsQueryResult", null)
let isLoadingInProgress = Watched(false)
let isInitedOnce = Watched(false)

local onItemsReceivedCb = null

isLoadingInProgress.subscribe(@(val)
  broadcastEvent("EpicShopDataUpdated", { isLoadingInProgress = val })
)

function requestData(cb = null) {
  logS($"Requested store info: cb = {cb}")
  isLoadingInProgress.set(true)

  onItemsReceivedCb = cb

  epic_get_shop_items_async()
}

isInitedOnce.subscribe(function(val) {
  if (!val || !canUseIngameShop())
    return

  logS($"Init Once")
  requestData()
})

shopItemsQueryResult.subscribe(function(v) {
  isLoadingInProgress.set(false)

  if (!v || !v.len()) {
    statsd.send_counter("sq.ingame_store.open.empty_catalog", 1)
    logerr($"{LOG_PREFIX}Empty catalog. Don't open shop")
    return
  }
})

let epicCatalog = Computed(function() {
  let itemsInfo = shopItemsQueryResult.get()
  if (!itemsInfo)
    return {}

  let res = {}
  itemsInfo.each(function(value, _key) {
    let item = EpicShopPurchasableItem(value)
    if (!(item.mediaItemType in res))
      res[item.mediaItemType] <- []
    res[item.mediaItemType].append(item)
  })
  return res
})

let epicItems = Computed(function() {
  let res = {}
  epicCatalog.get().each(@(itemsList, _m) itemsList.each(@(item, _idx) res[item.id] <- item))
  return res
})

epicItems.subscribe(function(_) {
  if (onItemsReceivedCb) {
    onItemsReceivedCb()
    onItemsReceivedCb = null
  }

  seenList.onListChanged()
})

let visibleSeenIds = Computed(function() {
  let res = []
  epicCatalog.get().each(@(itemsList, _m)
    res.extend(itemsList.filter(@(it) !it.canBeUnseen()).map(@(it) it.getSeenId()))
  )

  return res
})

seenList.setListGetter(@() visibleSeenIds.get())

function invaldateCache() {
  isInitedOnce.set(false)
}

function updateSpecificItemInfo(itemId) {
  if (!itemId)
    return

  epic_get_shop_item_async(itemId)
}

function onUpdateItemCb(blk) {
  epic_update_purchases_on_auth()
  addTask(updateEntitlementsLimited(true))

  let itemId = blk.id
  if (!epicItems.get()?[itemId]) {
    logerr($"{LOG_PREFIX}onUpdateItemCb: item {itemId} not in items list")
    return
  }

  epicItems.get()[itemId].update(blk)
  broadcastEvent("EpicShopItemUpdated", { item = epicItems.get()[itemId] })
}

let haveAnyItemWithDiscount = Computed(@()
  epicItems.get().findindex(@(v) v.haveDiscount()) != null
)

let initItemsListAfterLogin = @() isInitedOnce.set(true)

function haveDiscount() {
  if (!canUseIngameShop())
    return false

  if (!isInitedOnce.get()) {
    initItemsListAfterLogin()
    return false
  }

  return haveAnyItemWithDiscount.get()
}

subscriptions.addListenersWithoutEnv({
  LoginComplete = @(_p) initItemsListAfterLogin()
  SignOut = @(_p) invaldateCache()
  ScriptsReloaded = function(_p) {
    invaldateCache()
    initItemsListAfterLogin()
  }
}, g_listener_priority.CONFIG_VALIDATION)

eventbus_subscribe("epicShopItemPurchasedCallback", @(res) updateSpecificItemInfo(res.itemId))
eventbus_subscribe("epicShopItemCallback", @(res) onUpdateItemCb(res))
eventbus_subscribe("epicShopItemsCallback", @(res) shopItemsQueryResult.set(res))

return {
  canUseIngameShop
  requestData
  haveDiscount
  getShopItemsTable = @() epicItems.get()
  getShopItem = @(id) epicItems.get()?[id]
  catalog = epicCatalog
  isLoadingInProgress
  needEntStoreDiscountIcon = true
}
