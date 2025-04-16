from "%scripts/dagui_library.nut" import *
from "%scripts/queue/queueConsts.nut" import queueStates

let { get_time_msec } = require("dagor.time")
let { deferOnce } = require("dagor.workcycle")
let { appendOnce } = require("%sqStdLibs/helpers/u.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let { checkMatchingError, matchingApiFunc } = require("%scripts/matching/api.nut")
let QUEUE_TYPE_BIT = require("%scripts/queue/queueTypeBit.nut")

let queuesList = persist("queuesList", @() [])
local delayedInfoUpdateEventtTime = -1

let queueDiffParams = ["mode", "team"]

let getCustomModeSaveId = @(eventName) $"queue/customEvent/{eventName}"

function getShouldEventQueueCustomMode(eventName) {
  return loadLocalAccountSettings(getCustomModeSaveId(eventName), false)
}

function setShouldEventQueueCustomMode(eventName, shouldSave) {
  return saveLocalAccountSettings(getCustomModeSaveId(eventName), shouldSave)
}

function requestLeaveQueue(queryParams, successCallback, errorCallback, needShowError = false) {
  matchingApiFunc(
    "match.leave_queue"
    function(response) {
      if (checkMatchingError(response, needShowError))
        successCallback(response)
      else
        errorCallback(response)
    }
    queryParams
  )
}

function isQueueActive(queue) {
  return queue != null && (queue.state == queueStates.IN_QUEUE
    || queue.state == queueStates.ACTUALIZE
    || queue.state == queueStates.JOINING_QUEUE)
}

function isQueuesEqual(q1, q2) {
  if (!q1 || !q2)
    return !q1 == !q2
  return q1.id == q2.id
}

function isEqualQueueParams(params1, params2) {
  foreach (p in queueDiffParams)
    if ((p in params1) != (p in params2))
      continue
    else if ((p in params1) && params1[p] != params2[p])
      return false
  return true
}

function findQueue(params, typeMask = -1, checkActive = true) {
  foreach (q in queuesList)
    if ((typeMask < 0 || (typeMask & q.typeBit)) && (!checkActive || isQueueActive(q)))
        if (isEqualQueueParams(params, q.params))
          return q
  return null
}

function findAllQueues(params, typeMask = -1) {
  let res = []
  foreach (q in queuesList)
    if (typeMask < 0 || (typeMask & q.typeBit))
      if (isEqualQueueParams(params, q.params))
        res.append(q)
  return res
}

function findQueueByName(name, isActive = false) {
  foreach (queue in queuesList)
    if (queue.name == name && (!isActive || isQueueActive(queue)))
      return queue
  return null
}

function findQueueByQueueUid(queueUid) {
  foreach (queue in queuesList)
    if (queueUid in queue.queueUidsList)
      return queue
  return null
}

function applyQueueInfo(info, statsClass) {
  let queue = ("queueId" in info) ? findQueueByQueueUid(info.queueId)
    : ("name" in info)  ? findQueueByName(info.name)
    : null
  if (!queue)
    return false

  if (!queue.queueStats)
    queue.queueStats = statsClass(queue)

  return queue.queueStats.applyQueueInfo(info)
}

function isAnyQueuesActive(typeMask = -1) {
  foreach (q in queuesList)
    if (typeMask < 0 || (typeMask & q.typeBit))
      if (isQueueActive(q))
        return true
  return false
}

function sendQueueInfoUpdatedEventIfQueueActive() {
  delayedInfoUpdateEventtTime = -1
  if (isAnyQueuesActive())
    broadcastEvent("QueueInfoUpdated")
}

function pushQueueInfoUpdatedEvent() {
  if (delayedInfoUpdateEventtTime > 0 && get_time_msec() - delayedInfoUpdateEventtTime < 1000)
    return

  delayedInfoUpdateEventtTime = get_time_msec()
  deferOnce(sendQueueInfoUpdatedEventIfQueueActive)
}

function getActiveQueueTypes() {
  let res = []
  foreach (queue in queuesList)
    if (isQueueActive(queue))
      appendOnce(queue.queueType, res)

  return res
}

function getActiveQueueWithType(typeBit) {
  foreach (queue in queuesList)
    if ((typeBit & queue.typeBit) && isQueueActive(queue))
      return queue

  return null
}

function hasActiveQueueWithType(typeBit) {
  return getActiveQueueWithType(typeBit) != null
}

function getQueuesInfoText() {
  local text = loc("inQueueList/header")
  foreach (queue in queuesList)
    if (isQueueActive(queue))
      text = $"{text}\n{queue.getDescription()}"

  return text
}

function isEventQueue(queue) {
  if (!queue)
    return false
  return queue.typeBit == QUEUE_TYPE_BIT.EVENT
}

function checkQueueType(queue, typeMask) {
  return ((queue?.typeBit ?? 0) & typeMask) != 0
}

function removeQueueFromList(queue) {
  foreach (idx, q in queuesList)
    if (q.id == queue.id)
      return queuesList.remove(idx)
}

return {
  getShouldEventQueueCustomMode
  setShouldEventQueueCustomMode
  requestLeaveQueue
  isQueueActive
  isQueuesEqual
  findQueue
  findAllQueues
  findQueueByName
  isAnyQueuesActive
  getActiveQueueTypes
  getActiveQueueWithType
  hasActiveQueueWithType
  getQueuesList = @() freeze(queuesList)
  addQueueToList = @(queue) queuesList.append(queue)
  clearAllQueues = @() queuesList.clear()
  removeQueueFromList
  getQueuesInfoText
  isEventQueue
  checkQueueType
  applyQueueInfo
  pushQueueInfoUpdatedEvent
}
