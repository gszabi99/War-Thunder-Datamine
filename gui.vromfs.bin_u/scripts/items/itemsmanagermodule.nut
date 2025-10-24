from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import itemType
let inventoryClient = require("%scripts/inventory/inventoryClient.nut")
let { search } = require("%sqStdLibs/helpers/u.nut")
let { itemsList, inventory, shopItemById, itemsByItemdefId, inventoryItemById
} = require("%scripts/items/itemsManagerState.nut")
let { checkInventoryUpdate, checkUpdateList } = require("%scripts/items/itemsManagerChecks.nut")
let { checkAutoConsume } = require("%scripts/items/autoConsumeItems.nut")
let { getItemsFromList } = require("%scripts/items/itemsManagerGetters.nut")
let { isItemdefId } = require("%scripts/items/itemsChecks.nut")

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

function findItemById(id) {
  checkUpdateList()
  let item = shopItemById?[id] ?? itemsByItemdefId?[id]
  if (!item && isItemdefId(id))
    inventoryClient.requestItemdefsByIds([id])
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

function getItemsList(typeMask = itemType.ALL, filterFunc = null) {
  checkUpdateList()
  return getItemsFromList(itemsList, typeMask, filterFunc)
}

let getInventoryItemByCraftedFrom = @(uid) search(getInventoryList(),
  @(item) item.isCraftResult() && item.craftedFrom == uid)

let getUniversalSparesForUnit = @(unit) getInventoryList(itemType.UNIVERSAL_SPARE)
  .filter(@(item) item.getAmount() > 0 && item.canActivateOnUnit(unit))

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

return {
  getUniversalSparesForUnit
  getInventoryList
  findItemByUid
  findItemById
  getInventoryItemById
  getInventoryListByShopMask
  getItemsList
  getInventoryItemByCraftedFrom
  getItemsSortComparator
}
