from "%scripts/events/eventsState.nut" import getEvent
from "%scripts/events/eventTeamsInfo.nut" import isEventSymmetricTeams
from "%scripts/slotbar/slotbarRank.nut" import getSlotbarRank
from "%scripts/sqDagui/framework/gui_handlers.nut" import get_gui_handler
from "%scripts/events/eventInfo.nut" import isEventForClan, isTeamSizeBalancedEvent, isNoneBalancedEvent
from "%scripts/dagui_library.nut" import *
from "%scripts/teamsConsts.nut" import Team

function getQueueEvent(queue) {
  return getEvent(queue.name)
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
  return getSlotbarRank(event, country,
    getQueueSlots(queue)?[country] ?? 0)
}

function updateQueueInfoByType(queueType, successCb, errorCb = null, needAllQueues = false) {
  queueType.updateInfo(
    successCb,
    errorCb,
    needAllQueues
  )
}

function getQueuePreferredViewClass(queue) {
  let defaultHandler = get_gui_handler("QiHandlerByTeams")
  let event = getQueueEvent(queue)
  if (!event)
    return defaultHandler
  if (!isEventForClan(event) && (isTeamSizeBalancedEvent(event) || isNoneBalancedEvent(event)))
    return get_gui_handler("QiHandlerTeamBalanced")
  if (!isEventForClan(event) && isEventSymmetricTeams(event))
    return get_gui_handler("QiHandlerByCountries")
  return defaultHandler
}

return freeze({
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
})
