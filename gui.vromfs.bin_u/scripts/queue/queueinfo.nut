from "%scripts/dagui_library.nut" import *
from "%scripts/teamsConsts.nut" import Team

let { getGlobalModule } = require("%scripts/global_modules.nut")
let events = getGlobalModule("events")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { isEventForClan } = require("%scripts/events/eventInfo.nut")

function getQueueEvent(queue) {
  return events.getEvent(queue.name)
}

function isClanQueue(queue) {
  let event = getQueueEvent(queue)
  if (event == null)
    return false
  return isEventForClan(event)
}

function getQueueMode(queue) {
  return queue.params?.mode ?? ""
}

function getQueueTeam(queue) {
  return queue.params?.team ?? Team.Any
}

function getQueueCountry(queue) {
  return queue.params?.country ?? ""
}

function getQueueClusters(queue) {
  return queue?.queueStats.getClusters() ?? []
}

function getQueueSlots(queue) {
  return queue.params?.slots
}

function getQueueOperationId(queue) {
  return queue.params?.operationId ?? -1
}

function getMyRankInQueue(queue) {
  let event = getQueueEvent(queue)
  if (!event)
    return -1

  let country = getQueueCountry(queue)
  return events.getSlotbarRank(event, country,
    getQueueSlots(queue)?.country ?? 0)
}

function updateQueueInfoByType(queueType, successCb, errorCb = null, needAllQueues = false) {
  queueType.updateInfo(
    successCb,
    errorCb,
    needAllQueues
  )
}

function getQueuePreferredViewClass(queue) {
  let defaultHandler = gui_handlers.QiHandlerByTeams
  let event = getQueueEvent(queue)
  if (!event)
    return defaultHandler
  if (!isEventForClan(event) && events.isEventSymmetricTeams(event))
    return gui_handlers.QiHandlerByCountries
  return defaultHandler
}

return {
  getQueueEvent
  isClanQueue
  getQueueMode
  getQueueTeam
  getQueueCountry
  getQueueClusters
  getQueueSlots
  getQueueOperationId
  getMyRankInQueue
  updateQueueInfoByType
  getQueuePreferredViewClass
}
