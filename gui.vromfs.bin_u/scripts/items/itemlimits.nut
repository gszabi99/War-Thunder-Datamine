from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let { format } = require("string")
let { get_time_msec } = require("dagor.time")
::g_item_limits <- {

  /** Seconds to keep limit data without updating. */
  ITEM_REFRESH_TIME = 60

  /** Seconds to timout the request. */
  REQUEST_UNLOCK_TIMEOUT = 45

  /** Maximum number of items to go in a single request. */
  MAX_REQUEST_SIZE = 0 // Disabled for now.

  limitDataByItemName = {}
  itemNamesQueue = []
  isRequestLocked = false
  requestLockTime = -1 // Milliseconds
}

//
// Public
//

::g_item_limits.requestLimits <- function requestLimits(isBlocking = false)
{
  if (this.requestLockTime < max(get_time_msec() - REQUEST_UNLOCK_TIMEOUT * 1000, 0))
    this.isRequestLocked = false

  if (this.isRequestLocked)
    return false

  let curTime = get_time_msec()

  let requestBlk = ::DataBlock()
  local requestSize = 0
  while (this.itemNamesQueue.len() > 0 && this.checkRequestSize(requestSize))
  {
    let itemName = this.itemNamesQueue.pop()
    let limitData = this.getLimitDataByItemName(itemName)
    if (limitData.lastUpdateTime < max(curTime - ITEM_REFRESH_TIME * 1000, 0))
    {
      requestBlk["name"] <- itemName
      ++requestSize
    }
  }

  this.itemNamesQueue.clear()
  if (requestSize == 0)
    return false

  this.isRequestLocked = true
  this.requestLockTime = curTime

  let taskId = ::get_items_count_for_limits(requestBlk)
  let taskOptions = {
    showProgressBox = isBlocking
  }
  let taskCallback = function (result = YU2_OK)
    {
      ::g_item_limits.isRequestLocked = false
      if (result == YU2_OK)
      {
        let resultBlk = ::get_items_count_for_limits_result()
        ::g_item_limits.onRequestComplete(resultBlk)
      }
      ::broadcastEvent("ItemLimitsUpdated")
    }
  return ::g_tasker.addTask(taskId, taskOptions, taskCallback, taskCallback)
}

::g_item_limits.enqueueItem <- function enqueueItem(itemName)
{
  ::u.appendOnce(itemName, this.itemNamesQueue)
}

::g_item_limits.requestLimitsForItem <- function requestLimitsForItem(itemId, forceRefresh = false)
{
  if (forceRefresh)
    this.getLimitDataByItemName(itemId).lastUpdateTime = -1
  enqueueItem(itemId)
  requestLimits()
}

::g_item_limits.getLimitDataByItemName <- function getLimitDataByItemName(itemName)
{
  return getTblValue(itemName, this.limitDataByItemName) || this.createLimitData(itemName)
}

//
// Private
//

::g_item_limits.onRequestComplete <- function onRequestComplete(resultBlk)
{
  for (local i = resultBlk.blockCount() - 1; i >= 0; --i)
  {
    let itemBlk = resultBlk.getBlock(i)
    let itemName = itemBlk.getBlockName()
    let limitData = getLimitDataByItemName(itemName)
    limitData.countGlobal = itemBlk?.countGlobal ?? 0
    limitData.countPersonalTotal = itemBlk?.countPersonalTotal ?? 0
    limitData.countPersonalAtTime = itemBlk?.countPersonalAtTime ?? 0
    limitData.lastUpdateTime = get_time_msec()
  }
  requestLimits()
}

::g_item_limits.createLimitData <- function createLimitData(itemName)
{
  assert(
    !(itemName in this.limitDataByItemName),
    format("Limit data with name %s already exists.", itemName)
  )

  let limitData = {
    itemName = itemName
    countGlobal = -1
    countPersonalTotal = -1
    countPersonalAtTime = -1
    lastUpdateTime = -1 // Milliseconds
  }
  this.limitDataByItemName[itemName] <- limitData
  return limitData
}

::g_item_limits.checkRequestSize <- function checkRequestSize(requestSize)
{
  return MAX_REQUEST_SIZE == 0 || requestSize < MAX_REQUEST_SIZE
}
