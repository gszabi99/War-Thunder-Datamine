from "%scripts/dagui_library.nut" import *
from "%scripts/dagui_natives.nut" import char_send_custom_action
from "%scripts/items/itemsConsts.nut" import itemType
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let DataBlock = require("DataBlock")
let { addTask, TASK_CB_TYPE } = require("%scripts/tasker.nut")
let { getUserstatItemRewardData } = require("%scripts/userstat/userstatItemsRewards.nut")
let inventoryClient = require("%scripts/inventory/inventoryClient.nut")

const MAX_ITEMS_TO_MULTICONSUME_PER_REQUEST = 300
local shouldCheckAutoConsume = false

let failedAutoConsumeItemsByItemdefId = {}
let failedAutoConsumeItemsById = {}
local isAutoConsumeInProgress = false

let multiConsumeList = []
let singleConsumeList = []

function decreaseItemsAmountIfNeed(itemsList) {
  foreach (item in itemsList) {
    let newItem = ::ItemsManager.getInventoryItemById(item.id)
    if (!newItem || item.amount != newItem.amount)
      continue

    local isSameItems = false
    foreach (uid, amount in item.amountByUids) {
      if (amount != newItem.amountByUids?[uid]) {
        isSameItems = false
        break
      }
      isSameItems = true
    }
    if (!isSameItems)
      continue

    newItem.uids.each(@(uid) inventoryClient.removeItem(uid))
    newItem.amountByUids.clear()
    item.uids.clear()
  }
}

function onFinishMultiItemsConsumeSuccess(data) {
  let { revertedItems = [] } = data
  revertedItems.each(@(id) failedAutoConsumeItemsById[id.tostring()] <- true)
  
  
  decreaseItemsAmountIfNeed(multiConsumeList)
  multiConsumeList.clear()
  isAutoConsumeInProgress = false
}

function onFinishMultiItemsConsumeError() {
  isAutoConsumeInProgress = false
}

function fillItemsListsForAutoConsume() {
  let itemList = ::ItemsManager.getInventoryList(itemType.ALL, @(i) i.shouldAutoConsume)

  foreach (item in itemList) {
    if (!item.uids?[0])
      continue
    if (!item.canMultipleConsume || !item?.canConsume() || getUserstatItemRewardData(item.id) != null) {
      singleConsumeList.append(item)
      continue
    }
    multiConsumeList.append(item)
  }
}

function clearItemsListsForAutoConsume() {
  multiConsumeList.clear()
  singleConsumeList.clear()
}

function getItemsBlkForMultiAutoConsume(list) {
  let res = DataBlock()
  let itemsBlk = res.addBlock("items")
  local counter = 0 
  foreach (item in list) {
    if (!item.amountByUids)
      continue
    if (counter >= MAX_ITEMS_TO_MULTICONSUME_PER_REQUEST)
      break

    foreach (uid, amount in item.amountByUids) {
      if ((uid in failedAutoConsumeItemsById) || amount <= 0)
        continue
      if (counter >= MAX_ITEMS_TO_MULTICONSUME_PER_REQUEST)
        break
      let amountToConsume = min(amount, MAX_ITEMS_TO_MULTICONSUME_PER_REQUEST - counter)
      let itemBlk = itemsBlk.addNewBlock("item")
      itemBlk.setInt("itemId", uid.tointeger())
      itemBlk.setInt("quantity", amountToConsume)
      counter+=amountToConsume
    }
  }
  return res
}

function consumeMultipleItems() {
  if (isAutoConsumeInProgress || multiConsumeList.len() == 0)
    return

  let itemsBlk = getItemsBlkForMultiAutoConsume(multiConsumeList)
  if (itemsBlk.items.blockCount() == 0)
    return

  isAutoConsumeInProgress = true
  let blkParams = DataBlock()
  blkParams.addBool("textBlk", true)
  let taskId = char_send_custom_action(
    "cln_multi_consume_inventory_item_json",
    EATT_JSON_REQUEST,
    blkParams,
    itemsBlk.formatAsString(),
    -1
  )
  addTask(taskId, {}, onFinishMultiItemsConsumeSuccess, onFinishMultiItemsConsumeError, TASK_CB_TYPE.REQUEST_DATA)
}

local consumeSingleItems = @() null
consumeSingleItems = function() {
  if (isAutoConsumeInProgress || singleConsumeList.len() == 0)
    return

  let onConsumeFinish = function(p = {}) {
    if (!(p?.success ?? true) && p?.itemId != null)
      failedAutoConsumeItemsByItemdefId[p.itemId] <- true
    isAutoConsumeInProgress = false
    consumeSingleItems()
  }

  foreach (item in singleConsumeList)
    if (!(item.id in failedAutoConsumeItemsByItemdefId) && item.consume(onConsumeFinish, {})) {
      isAutoConsumeInProgress = true
      break
    }
}

function autoConsumeItems() {
  if (isAutoConsumeInProgress)
    return

  clearItemsListsForAutoConsume()
  fillItemsListsForAutoConsume()

  consumeMultipleItems()
  consumeSingleItems()
}

function checkAutoConsume() {
  if (!shouldCheckAutoConsume)
    return
  shouldCheckAutoConsume = false
  autoConsumeItems()
}

addListenersWithoutEnv({
  function SignOut(_) {
    failedAutoConsumeItemsByItemdefId.clear()
    failedAutoConsumeItemsById.clear()
  }
})

return {
  setShouldCheckAutoConsume = @(value) shouldCheckAutoConsume = value
  checkAutoConsume
  autoConsumeItems
}