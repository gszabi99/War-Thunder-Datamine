local getNearestMap = function(mapsList) {
  local nearestMap = null
  foreach(map in mapsList)
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

local getFirstAvailableMap = @(mapsList)
  mapsList.findvalue(@(map) map.isAnnounceAndNotDebug(false))

local hasAvailableMapToBattleShort = @()
  getFirstAvailableMap(::g_ww_global_status_type.MAPS.getShortStatusList()) != null

local getNearestMapToBattleShort = @()
  getNearestMap(::g_ww_global_status_type.MAPS.getShortStatusList())

local hasAvailableMapToBattle = @()
  getFirstAvailableMap(::g_ww_global_status_type.MAPS.getList()) != null

local getNearestMapToBattle = @()
  getNearestMap(::g_ww_global_status_type.MAPS.getList())

local isRecievedGlobalStatusMaps = @() ::g_ww_global_status_type.MAPS.getList().len() > 0

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

local getMapByName = @(mapName) ::g_ww_global_status_type.MAPS.getList()?[mapName]

local getMapFromShortStatusByName = @(mapName) ::g_ww_global_status_type.MAPS.getShortStatusList()?[mapName]

//always return queue. do not return null
local getQueueByMapName = @(mapName) ::g_ww_global_status_type.QUEUE.getList()?[mapName] ?? ::WwQueue(mapName)

local getOperationGroupByMapId = @(mapId)
  ::u.search(::g_ww_global_status_type.OPERATIONS_GROUPS.getList(), @(og) og.mapId == mapId)
    ?? ::WwOperationsGroup(mapId)

local isMyClanInQueue = @() ::is_in_clan()
  && ::u.search(::g_ww_global_status_type.QUEUE.getList(), @(q) q.isMyClanJoined()) != null

::g_ww_global_status_actions <- {   //!!!FIX ME: This global table used in main scripts. It is necessary to remove use of world war scripts from the main scripts and delete this table
  getOperationById = getOperationById
  getMapByName = getMapByName
}

return {
  hasAvailableMapToBattleShort = hasAvailableMapToBattleShort
  getNearestMapToBattleShort = getNearestMapToBattleShort
  hasAvailableMapToBattle = hasAvailableMapToBattle
  getNearestMapToBattle = getNearestMapToBattle
  getOperationById = getOperationById
  getMyClanOperation = getMyClanOperation
  getMapByName = getMapByName
  getMapFromShortStatusByName = getMapFromShortStatusByName
  getQueueByMapName = getQueueByMapName
  getOperationGroupByMapId = getOperationGroupByMapId
  isMyClanInQueue = isMyClanInQueue
  getOperationFromShortStatusById = getOperationFromShortStatusById
  isRecievedGlobalStatusMaps = isRecievedGlobalStatusMaps
}
