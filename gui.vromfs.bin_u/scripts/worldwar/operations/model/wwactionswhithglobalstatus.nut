from "%scripts/dagui_library.nut" import *
from "%scripts/clans/clanState.nut" import is_in_clan
let { hasRightsToQueueWWar } = require("%scripts/clans/clanInfo.nut")
let { wwGetOperationId } = require("worldwar")
let u = require("%sqStdLibs/helpers/u.nut")
let { isOperationFinished } = require("%appGlobals/worldWar/wwOperationState.nut")
let { wwStatusType } = require("%scripts/worldWar/operations/model/wwGlobalStatusType.nut")

function getNearestMap(mapsList) {
  local nearestMap = null
  foreach (map in mapsList)
    if (map.isAnnounceAndNotDebug(false)) {
      if (map.isActive())
        return map
      else
        nearestMap = !nearestMap
          || nearestMap.getChangeStateTime() > map.getChangeStateTime()
            ? map
            : nearestMap
    }
  return nearestMap
}

let getFirstAvailableMap = @(mapsList)
  mapsList.findvalue(@(map) map.isAnnounceAndNotDebug(false))

let hasAvailableMapToBattle = @()
  getFirstAvailableMap(wwStatusType.MAPS.getList()) != null

let getNearestMapToBattle = @()
  getNearestMap(wwStatusType.MAPS.getList())

let isReceivedGlobalStatusMaps = @() wwStatusType.MAPS.getList().len() > 0

function getOperationById(operationId) {
  return u.search(wwStatusType.ACTIVE_OPERATIONS.getList(),
    @(o) o.id == operationId)
}

function getMyClanOperation() {
  return u.search(wwStatusType.ACTIVE_OPERATIONS.getList(),
    @(o) o.isMyClanParticipate())
}

let getMapByName = @(mapName) wwStatusType.MAPS.getList()?[mapName]

let isMyClanInQueue = @() is_in_clan()
  && u.search(wwStatusType.QUEUE.getList(), @(q) q.isMyClanJoined()) != null

let isWWSeasonActive = @() hasAvailableMapToBattle()

function updateCurOperationStatusInGlobalStatus() {
  let operationId = wwGetOperationId()
  if (operationId == -1)
    return

  let operation = getOperationById(operationId)
  operation?.setFinishedStatus(isOperationFinished())
}

function isWwOperationInviteEnable() {
  let wwOperationId = wwGetOperationId()
  return wwOperationId > -1 && hasRightsToQueueWWar()
    && getOperationById(wwOperationId)?.isMyClanParticipate()
}

let wwGlobalStatusActions = {   
  getOperationById
  getMapByName
}

return {
  hasAvailableMapToBattle
  getNearestMapToBattle
  getMyClanOperation
  getMapByName
  isMyClanInQueue
  getOperationById
  isReceivedGlobalStatusMaps
  isWWSeasonActive
  updateCurOperationStatusInGlobalStatus
  isWwOperationInviteEnable
  wwGlobalStatusActions
}
