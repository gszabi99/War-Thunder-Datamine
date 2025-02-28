from "%scripts/dagui_natives.nut" import get_items_count_for_limits_result, get_items_count_for_limits
from "%scripts/dagui_library.nut" import *
let { appendOnce } = require("%sqStdLibs/helpers/u.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let DataBlock  = require("DataBlock")
let { get_time_msec } = require("dagor.time")
let { addTask } = require("%scripts/tasker.nut")

/** Seconds to keep limit data without updating. */
const ITEM_REFRESH_TIME = 60

/** Seconds to timout the request. */
const REQUEST_UNLOCK_TIMEOUT = 45

/** Maximum number of items to go in a single request. */
const MAX_REQUEST_SIZE = 0 // Disabled for now.

let limitDataByItemName = {}
let itemNamesQueue = []
local isRequestLocked = false
local requestLockTime = -1 // Milliseconds

function checkRequestSize(requestSize) {
  return MAX_REQUEST_SIZE == 0 || requestSize < MAX_REQUEST_SIZE
}

function createLimitData(itemName) {
  assert((itemName not in limitDataByItemName), $"Limit data with name {itemName} already exists.")
  let limitData = {
    itemName = itemName
    countGlobal = -1
    countPersonalTotal = -1
    countPersonalAtTime = -1
    lastUpdateTime = -1 // Milliseconds
  }
  limitDataByItemName[itemName] <- limitData
  return limitData
}

function getLimitDataByItemName(itemName) {
  return limitDataByItemName?[itemName] ?? createLimitData(itemName)
}

function enqueueItem(itemName) {
  appendOnce(itemName, itemNamesQueue)
}

function onRequestComplete(resultBlk) {
  for (local i = resultBlk.blockCount() - 1; i >= 0; --i) {
    let itemBlk = resultBlk.getBlock(i)
    let itemName = itemBlk.getBlockName()
    let limitData = getLimitDataByItemName(itemName)
    limitData.countGlobal = itemBlk?.countGlobal ?? 0
    limitData.countPersonalTotal = itemBlk?.countPersonalTotal ?? 0
    limitData.countPersonalAtTime = itemBlk?.countPersonalAtTime ?? 0
    limitData.lastUpdateTime = get_time_msec()
  }
}

function requestLimits(isBlocking = false) {
  if (requestLockTime < max(get_time_msec() - REQUEST_UNLOCK_TIMEOUT * 1000, 0))
    isRequestLocked = false

  if (isRequestLocked)
    return false

  let curTime = get_time_msec()

  let requestBlk = DataBlock()
  local requestSize = 0
  while (itemNamesQueue.len() > 0 && checkRequestSize(requestSize)) {
    let itemName = itemNamesQueue.pop()
    let limitData = getLimitDataByItemName(itemName)
    if (limitData.lastUpdateTime < max(curTime - ITEM_REFRESH_TIME * 1000, 0)) {
      requestBlk["name"] <- itemName
      ++requestSize
    }
  }

  itemNamesQueue.clear()
  if (requestSize == 0)
    return false

  isRequestLocked = true
  requestLockTime = curTime
  let self = callee()

  let taskId = get_items_count_for_limits(requestBlk)
  let taskOptions = {
    showProgressBox = isBlocking
  }
  let taskCallback = function (result = YU2_OK) {
    isRequestLocked = false
    if (result == YU2_OK) {
      let resultBlk = get_items_count_for_limits_result()
      onRequestComplete(resultBlk)
      self()
    }
    broadcastEvent("ItemLimitsUpdated")
  }
  return addTask(taskId, taskOptions, taskCallback, taskCallback)
}

function requestLimitsForItem(itemId) {
  getLimitDataByItemName(itemId).lastUpdateTime = -1
  enqueueItem(itemId)
  requestLimits()
}

return {
  getLimitDataByItemName
  enqueueItem
  requestLimits
  requestLimitsForItem
}
