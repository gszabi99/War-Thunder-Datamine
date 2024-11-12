from "%scripts/dagui_library.nut" import *
from "%scripts/dagui_natives.nut" import char_send_custom_action
from "%scripts/items/itemsConsts.nut" import itemType
from "app" import is_dev_version
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let DataBlock = require("DataBlock")
let { addTask } = require("%scripts/tasker.nut")
let { getUserstatItemRewardData } = require("%scripts/userstat/userstatItemsRewards.nut")

local shouldCheckAutoConsume = false

let failedAutoConsumeItems = {}
local isAutoConsumeInProgress = false

let multiConsumeList = []
let singleConsumeList = []

function onFinishMultiItemsConsume() {
  multiConsumeList.clear()
  isAutoConsumeInProgress = false
}

function fillItemsListsForAutoConsume() {
  let itemList = ::ItemsManager.getInventoryList(itemType.ALL, @(i) i.shouldAutoConsume)
  if (!is_dev_version()) {
    singleConsumeList.extend(itemList)
    return
  }

  foreach (item in itemList) {
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
  foreach (item in list) {
    if (!item.amountByUids)
      continue

    foreach (uid, amount in item.amountByUids) {
      let itemBlk = itemsBlk.addNewBlock("item")
      itemBlk.setInt("itemId", uid.tointeger())
      itemBlk.setInt("quantity", amount)
    }
  }
  return res
}

function consumeMultipleItems() {
  if (isAutoConsumeInProgress || multiConsumeList.len() == 0)
    return

  isAutoConsumeInProgress = true

  let itemsBlk = getItemsBlkForMultiAutoConsume(multiConsumeList)
  let blkParams = DataBlock()
  blkParams.addBool("textBlk", true)

  let taskId = char_send_custom_action(
    "cln_multi_consume_inventory_item",
    EATT_SIMPLE_OK,
    blkParams,
    itemsBlk.formatAsString(),
    -1
  )
  addTask(taskId, {}, onFinishMultiItemsConsume)
}

local consumeSingleItems = @() null
consumeSingleItems = function() {
  if (isAutoConsumeInProgress || singleConsumeList.len() == 0)
    return

  let onConsumeFinish = function(p = {}) {
    if (!(p?.success ?? true) && p?.itemId != null)
      failedAutoConsumeItems[p.itemId] <- true
    isAutoConsumeInProgress = false
    consumeSingleItems()
  }

  foreach (item in singleConsumeList)
    if (!(item.id in failedAutoConsumeItems) && item.consume(onConsumeFinish, {})) {
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
  SignOut = @(_p) failedAutoConsumeItems.clear()
})

return {
  setShouldCheckAutoConsume = @(value) shouldCheckAutoConsume = value
  checkAutoConsume
  autoConsumeItems
}