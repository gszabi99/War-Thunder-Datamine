//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let getNearestMap = function(mapsList) {
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
  getFirstAvailableMap(::g_ww_global_status_type.MAPS.getList()) != null

let getNearestMapToBattle = @()
  getNearestMap(::g_ww_global_status_type.MAPS.getList())

let isRecievedGlobalStatusMaps = @() ::g_ww_global_status_type.MAPS.getList().len() > 0

let function getOperationById(operationId) {
  return ::u.search(::g_ww_global_status_type.ACTIVE_OPERATIONS.getList(),
    @(o) o.id == operationId)
}

let function getMyClanOperation() {
  return ::u.search(::g_ww_global_status_type.ACTIVE_OPERATIONS.getList(),
    @(o) o.isMyClanParticipate())
}

let getMapByName = @(mapName) ::g_ww_global_status_type.MAPS.getList()?[mapName]

//always return queue. do not return null
let getQueueByMapName = @(mapName) ::g_ww_global_status_type.QUEUE.getList()?[mapName] ?? ::WwQueue(mapName)

let getOperationGroupByMapId = @(mapId)
  ::u.search(::g_ww_global_status_type.OPERATIONS_GROUPS.getList(), @(og) og.mapId == mapId)
    ?? ::WwOperationsGroup(mapId)

let isMyClanInQueue = @() ::is_in_clan()
  && ::u.search(::g_ww_global_status_type.QUEUE.getList(), @(q) q.isMyClanJoined()) != null

::g_ww_global_status_actions <- {   //!!!FIX ME: This global table used in main scripts. It is necessary to remove use of world war scripts from the main scripts and delete this table
  getOperationById
  getMapByName
}

return {
  hasAvailableMapToBattle
  getNearestMapToBattle
  getMyClanOperation
  getMapByName
  getQueueByMapName
  getOperationGroupByMapId
  isMyClanInQueue
  getOperationById
  isRecievedGlobalStatusMaps
}
