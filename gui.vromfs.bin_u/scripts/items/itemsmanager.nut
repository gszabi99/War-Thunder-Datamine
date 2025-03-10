from "%scripts/dagui_natives.nut" import get_user_logs_count, get_current_personal_discount_count, get_user_log_blk_body, get_current_personal_discount_uid, get_cyber_cafe_level
from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import itemsTab, itemType
from "%scripts/mainConsts.nut" import LOST_DELAYED_ACTION_MSEC, SEEN

let { search, isDataBlock } = require("%sqStdLibs/helpers/u.nut")
let { loadLocalByAccount, saveLocalByAccount
} = require("%scripts/clientState/localProfileDeprecated.nut")
let { broadcastEvent, addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { get_time_msec } = require("dagor.time")
let DataBlock  = require("DataBlock")
let { getItemGenerator } = require("%scripts/items/itemGeneratorsManager.nut")
let inventoryClient = require("%scripts/inventory/inventoryClient.nut")
let { setShouldCheckAutoConsume, checkAutoConsume } = require("%scripts/items/autoConsumeItems.nut")
let seenList = require("%scripts/seen/seenList.nut")
let { addPromoAction } = require("%scripts/promo/promoActions.nut")
let { deferOnce } = require("dagor.workcycle")
let { isMeNewbie } = require("%scripts/myStats.nut")
let { eventbus_subscribe } = require("eventbus")
let { isProfileReceived } = require("%appGlobals/login/loginState.nut")
let { isItemdefId, isItemVisible, checkItemsMaskFeatures } = require("%scripts/items/itemsChecks.nut")
let { itemsShopListVersion, inventoryListVersion,
  itemsList, inventory, inventoryItemById, shopItemById, itemsByItemdefId,
  rawInventoryItemAmountsByItemdefId, shopVisibleSeenIds
} = require("%scripts/items/itemsManagerState.nut")
let { genericItemsForCyberCafeLevel, checkUpdateList, checkInventoryUpdate,
  reqUpdateList, reqUpdateItemDefsList, needInventoryUpdate
} = require("%scripts/items/itemsManagerChecks.nut")
let { getItemsFromList, getShopList } = require("%scripts/items/itemsManagerGetters.nut")
let { shopSmokeItems, createItem } = require("%scripts/items/itemsTypeClasses.nut")
let { addDelayedAction } = require("%scripts/utils/delayedActions.nut")

let seenInventory = seenList.get(SEEN.INVENTORY)
let seenItems = seenList.get(SEEN.ITEMS_SHOP)

const OUT_OF_DATE_DAYS_ITEMS_SHOP = 28
const OUT_OF_DATE_DAYS_INVENTORY = 0

local inventoryVisibleSeenIds = null
local isInventoryInternalUpdated = false
local isInventoryFullUpdate = false

function requestItemsByItemdefIds(itemdefIdsList) {
  inventoryClient.requestItemdefsByIds(itemdefIdsList)
}


function findItemById(id, _typeMask = itemType.ALL) {
  checkUpdateList()
  let item = shopItemById?[id] ?? itemsByItemdefId?[id]
  if (!item && isItemdefId(id))
    requestItemsByItemdefIds([id])
  return item
}

function collectUserlogItemdefs() {
  let res = []
  for (local i = 0; i < get_user_logs_count(); ++i) {
    let blk = DataBlock()
    get_user_log_blk_body(i, blk)
    let itemDefId = blk?.body.itemDefId
    if (itemDefId)
      res.append(itemDefId)
  }
  requestItemsByItemdefIds(res)
}

function getInventoryList(typeMask = itemType.ALL, filterFunc = null) {
  checkInventoryUpdate()
  checkAutoConsume()
  return getItemsFromList(inventory, typeMask, filterFunc)
}

function findItemByUid(uid, filterType = itemType.ALL) {
  let itemsArray = getInventoryList(filterType)
  let res = search(itemsArray, @(item) isInArray(uid, item.uids))
  return res
}

function getBestItemSpecialOfferByUnit(unit) {
  let res = []
  for (local i = 0; i < get_current_personal_discount_count(); ++i) {
    let uid = get_current_personal_discount_uid(i)
    let item = findItemByUid(uid, itemType.DISCOUNT)
    if (item == null || !(item?.isSpecialOffer ?? false) || !item.isActive())
      continue

    let locParams = item.getSpecialOfferLocParams()
    let itemUnit = locParams?.unit
    if (itemUnit == unit)
      res.append({
        item = item
        discountValue = locParams.discountValue
        discountMax = locParams.discountMax
        discountMin = locParams.discountMin
      })
  }

  if (res.len() == 0)
    return null

  res.sort(@(a, b) b.discountValue <=> a.discountValue
    || b.discountMax <=> a.discountMax
    || b.discountMin <=> a.discountMin)
  return res[0].item
}

function getItemsList(typeMask = itemType.ALL, filterFunc = null) {
  checkUpdateList()
  return getItemsFromList(itemsList, typeMask, filterFunc)
}

function getItemOrRecipeBundleById(id) {
  local item = findItemById(id)
  if (item || !getItemGenerator(id))
    return item

  let itemDefDesc = inventoryClient.getItemdefs()?[id]
  if (!itemDefDesc)
    return item

  item = createItem(itemType.RECIPES_BUNDLE, itemDefDesc)
  
  
  
  itemsByItemdefId[item.id] <- item
  return item
}

function getInventoryItemById(id) {
  checkInventoryUpdate()
  return inventoryItemById?[id]
}

function getInventoryListByShopMask(typeMask, filterFunc = null) {
  checkInventoryUpdate()
  checkAutoConsume()
  return getItemsFromList(inventory, typeMask, filterFunc, "shopFilterMask")
}

let getInventoryItemByCraftedFrom = @(uid) search(getInventoryList(),
  @(item) item.isCraftResult() && item.craftedFrom == uid)

let refreshExtInventory = @() inventoryClient.refreshItems()

function isItemsManagerEnabled() {
  let checkNewbie = !isMeNewbie()
    || seenInventory.hasSeen()
    || inventory.len() > 0
  return hasFeature("Items") && checkNewbie
}

function getItemsSortComparator(itemsSeenList = null) {
  return function(item1, item2) { 
    if (!item1 || !item2)
      return item2 <=> item1
    return item2.isActive() <=> item1.isActive()
      || (itemsSeenList && itemsSeenList.isNew(item2.getSeenId()) <=> itemsSeenList.isNew(item1.getSeenId()))
      || item2.hasExpireTimer() <=> item1.hasExpireTimer()
      || (item1.hasExpireTimer() && (item1.expiredTimeSec <=> item2.expiredTimeSec))
      || item1.iType <=> item2.iType
      || item2.getRarity() <=> item1.getRarity()
      || item1.id <=> item2.id
      || item1.tradeableTimestamp <=> item2.tradeableTimestamp
  }
}

function getRawInventoryItemAmount(itemdefid) {
  return rawInventoryItemAmountsByItemdefId?[itemdefid] ?? 0
}


function consumeItemFromPromo(handler, params) {
  let itemId = params?[0]
  if (itemId == null)
    return

  let item = getInventoryItemById(to_integer_safe(itemId, itemId, false))
  if (!(item?.canConsume() ?? false))
    return

  item?.consume(@(...) null, { needConsumeImpl = params?[1] == "needConsumeImpl" })
  handler.goBack()
}

function canConsumeItemFromPromo(params) {
  let itemId = params?[0]
  if (itemId == null)
    return false
  let item = getInventoryItemById(to_integer_safe(itemId, itemId, false))
  return item?.canConsume() ?? false
}

addPromoAction("consume_item",
  @(handler, params, _obj) consumeItemFromPromo(handler, params),
  @(params) canConsumeItemFromPromo(params))

function getShopVisibleSeenIds() {
  if (shopVisibleSeenIds.get())
    return shopVisibleSeenIds.get()

  let newVal = getShopList(checkItemsMaskFeatures(itemType.INVENTORY_ALL),
    @(it) isItemVisible(it, itemsTab.SHOP)).map(@(it) it.getSeenId())
  shopVisibleSeenIds.set(newVal)
  return newVal
}


let seenIdCanBeNew = {}
function canSeenIdBeNew(seenId) {
  if (!(seenId in seenIdCanBeNew) || seenIdCanBeNew[seenId] == null) {
    let id = to_integer_safe(seenId, seenId, false) 
    let item = findItemById(id)
    let itemCanBeNew = item && !(getAircraftByName(item.getTopPrize()?.unit)?.isBought() ?? false)
    seenIdCanBeNew[seenId] <- itemCanBeNew
    return itemCanBeNew
  }
  return seenIdCanBeNew[seenId]
}

function getInventoryVisibleSeenIds() {
  if (!inventoryVisibleSeenIds) {
    let invItemsList = getInventoryListByShopMask(checkItemsMaskFeatures(itemType.INVENTORY_ALL))
    inventoryVisibleSeenIds = invItemsList.filter(
      @(it) isItemVisible(it, itemsTab.INVENTORY)).map(@(it) it.getSeenId())
  }

  return inventoryVisibleSeenIds
}

let clearSeenCashe = @() seenIdCanBeNew.clear()

seenItems.setListGetter(@() getShopVisibleSeenIds())
seenItems.setCanBeNewFunc(canSeenIdBeNew)
seenInventory.setListGetter(@() getInventoryVisibleSeenIds())

let makeSeenCompatibility = @(savePath) function() {
  let res = {}
  let blk = loadLocalByAccount(savePath)
  if (!isDataBlock(blk))
    return res

  for (local i = 0; i < blk.paramCount(); ++i)
    res[blk.getParamName(i)] <- blk.getParamValue(i)
  saveLocalByAccount(savePath, null)
  return res
}

seenItems.setCompatibilityLoadData(makeSeenCompatibility("seen_shop_items"))
seenInventory.setCompatibilityLoadData(makeSeenCompatibility("seen_inventory_items"))


function markItemsDefsListUpdate() {
  reqUpdateItemDefsList.set(true)
  shopVisibleSeenIds.set(null)
  clearSeenCashe()
  seenItems.onListChanged()
  broadcastEvent("ItemsShopUpdate")
  itemsShopListVersion(itemsShopListVersion.value + 1)
}

local lastItemDefsUpdatedelayedCall = 0
function markItemsDefsListUpdateDelayed() {
  if (reqUpdateItemDefsList.get())
    return
  if (lastItemDefsUpdatedelayedCall
      && lastItemDefsUpdatedelayedCall + LOST_DELAYED_ACTION_MSEC > get_time_msec())
    return

  lastItemDefsUpdatedelayedCall = get_time_msec()
  handlersManager.doDelayed(function() {
    lastItemDefsUpdatedelayedCall = 0
    markItemsDefsListUpdate()
  })
}

function markInventoryUpdate() {
  if (needInventoryUpdate.get())
    return

  needInventoryUpdate.set(true)
  inventoryVisibleSeenIds = null
  if (!isInventoryFullUpdate && isInventoryInternalUpdated && !inventoryClient.isWaitForInventory()) {
    isInventoryFullUpdate = true
    seenInventory.setDaysToUnseen(OUT_OF_DATE_DAYS_INVENTORY)
  }
  seenInventory.onListChanged()
  broadcastEvent("InventoryUpdate")
  inventoryListVersion(inventoryListVersion.value + 1)
}

local lastInventoryUpdateDelayedCall = 0
function markInventoryUpdateDelayed() {
  if (needInventoryUpdate.get())
    return
  if (lastInventoryUpdateDelayedCall
      && lastInventoryUpdateDelayedCall < get_time_msec() + LOST_DELAYED_ACTION_MSEC)
    return

  lastInventoryUpdateDelayedCall = get_time_msec()
  addDelayedAction(function() {
    if (!isProfileReceived.get())
      return
    lastInventoryUpdateDelayedCall = 0
    markInventoryUpdate()
  }, 200)
}

function markItemsListUpdate() {
  reqUpdateList.set(true)
  shopVisibleSeenIds.set(null)
  seenItems.setDaysToUnseen(OUT_OF_DATE_DAYS_ITEMS_SHOP)
  clearSeenCashe()
  seenItems.onListChanged()
  broadcastEvent("ItemsShopUpdate")
  itemsShopListVersion(itemsShopListVersion.value + 1)
}
shopSmokeItems.subscribe(@(_) markItemsListUpdate())

addListenersWithoutEnv({
  PriceUpdated = @(_) markItemsListUpdate()
  ItemDefChanged = @(_) markItemsDefsListUpdate()
  TourRegistrationComplete = @(_) markInventoryUpdate()
  ExtInventoryChanged = @(_) markInventoryUpdateDelayed()
  SendingItemsChanged = @(_) markInventoryUpdateDelayed()
  ExtPricesChanged = @(_) markItemsDefsListUpdateDelayed()
  GameLocalizationChanged = @(_) inventoryClient.forceRefreshItemDefs(
    @() itemsByItemdefId.clear())

  function ProfileUpdated(_) {
    foreach (index, itemCanBeNew in seenIdCanBeNew)
      if (itemCanBeNew == true)
        seenIdCanBeNew[index] = null
  }
  function LoginComplete(_) {
    setShouldCheckAutoConsume(true)
    reqUpdateList.set(true)
  }
  function SignOut(_) {
    isInventoryFullUpdate = false
    isInventoryInternalUpdated = false
  }
  function EntitlementsUpdatedFromOnlineShop(_) {
    let curLevel = get_cyber_cafe_level()
    if (genericItemsForCyberCafeLevel != curLevel) {
      markItemsListUpdate()
      markInventoryUpdate()
    }
  }
})


function onItemsLoaded() {
  isInventoryInternalUpdated = true
  markInventoryUpdate()
}
eventbus_subscribe("on_items_loaded", @(_) deferOnce(onItemsLoaded))

::ItemsManager <- {
  
  requestItemsByItemdefIds
  collectUserlogItemdefs
  findItemById
  findItemByUid
  getInventoryList
  getInventoryItemById
}

return {
  isInventoryFullUpdated = @() isInventoryFullUpdate
  getBestItemSpecialOfferByUnit
  findItemByUid
  findItemById
  getInventoryList
  getInventoryItemById
  isItemsManagerEnabled
  refreshExtInventory
  markInventoryUpdate
  markInventoryUpdateDelayed
  getInventoryItemByCraftedFrom
  getItemsList
  getInventoryListByShopMask
  getItemOrRecipeBundleById
  getRawInventoryItemAmount
  getItemsSortComparator
}
