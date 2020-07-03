local function getNearestAvailableMapToBattle(needFirstAvailable = false, checkShortStatus = false) {
  local nearestAvailableMap = null
  local mapsList = checkShortStatus ? ::g_ww_global_status_type.MAPS.getShortStatusList()
    : ::g_ww_global_status_type.MAPS.getList()
  foreach(map in mapsList) {
    if (map.isAnnounceAndNotDebug(false))
      if (map.isActive())
        return map
      else
        nearestAvailableMap = !nearestAvailableMap ||
          nearestAvailableMap.getChangeStateTime() > map.getChangeStateTime()
            ? map
            : nearestAvailableMap
    if(needFirstAvailable && nearestAvailableMap)
      return nearestAvailableMap
 }

  return nearestAvailableMap
}

local function getOperationById(operationId) {
  return ::u.search(::g_ww_global_status_type.ACTIVE_OPERATIONS.getList(),
    @(o) o.id == operationId)
}

local function getOperationFromShortStatusById(operationId) {
  return ::u.search(::g_ww_global_status_type.ACTIVE_OPERATIONS.getShortStatusList(),
    @(o) o.id == operationId)
}

local function getMyClanOperation() {
  return ::u.search(::g_ww_global_status_type.ACTIVE_OPERATIONS.getList(),
    @(o) o.isMyClanParticipate())
}

local getMapByName = function(mapName, needShortStatus = false) {
  if (needShortStatus)
    return ::g_ww_global_status_type.MAPS.getShortStatusList()?[mapName]
  else
    return ::g_ww_global_status_type.MAPS.getList()?[mapName]
}

//always return queue. do not return null
local getQueueByMapName = @(mapName) ::g_ww_global_status_type.QUEUE.getList()?[mapName] ?? ::WwQueue(mapName)

local getOperationGroupByMapId = @(mapId)
  ::u.search(::g_ww_global_status_type.OPERATIONS_GROUPS.getList(), @(og) og.mapId == mapId)
    ?? ::WwOperationsGroup(mapName)

local isMyClanInQueue = @() ::is_in_clan()
  && ::u.search(::g_ww_global_status_type.QUEUE.getList(), @(q) q.isMyClanJoined()) != null

::g_ww_global_status_actions <- {   //!!!FIX ME: This global table used in main scripts. It is necessary to remove use of world war scripts from the main scripts and delete this table
  getOperationById = getOperationById
  getMapByName = getMapByName
}

return {
  getNearestAvailableMapToBattle = getNearestAvailableMapToBattle
  getOperationById = getOperationById
  getMyClanOperation = getMyClanOperation
  getMapByName = getMapByName
  getQueueByMapName = getQueueByMapName
  getOperationGroupByMapId = getOperationGroupByMapId
  isMyClanInQueue = isMyClanInQueue
  getOperationFromShortStatusById = getOperationFromShortStatusById
}
