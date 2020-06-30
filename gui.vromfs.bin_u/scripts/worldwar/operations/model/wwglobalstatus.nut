::g_ww_global_status <- {
  [PERSISTENT_DATA_PARAMS] = ["curData", "validListsMask", "lastUpdatetTime", "lastRequestTime"]

  curData = null
  validListsMask = 0

  REQUEST_TIMEOUT_MSEC = 15000
  lastUpdatetTime = -1
  lastRequestTime = -1

  function getNearestAvailableMapToBattle(needFirstAvailable = false)
  {
    local nearestAvailableMap = null
    foreach(map in ::g_ww_global_status_type.MAPS.getList())
    {
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
}

g_ww_global_status.reset <- function reset()
{
  curData = null
  validListsMask = 0
  lastUpdatetTime = -1
  lastRequestTime = -1
  if (::g_login.isLoggedIn())
    refreshData()
}

g_ww_global_status.refreshData <- function refreshData(refreshDelay = WWGS_REFRESH_DELAY.LATENT_QUEUE_REFRESH, taskOptions = null)
{
  if (canRefreshData(refreshDelay))
    actionRequest("cln_ww_global_status", null, taskOptions)
}

//special actions with global status in successCb
g_ww_global_status.actionRequest <- function actionRequest(actionName, requestBlk, taskOptions = null, onSuccessCb = null, onErrorCb = null)
{
  lastRequestTime = ::dagor.getCurTime()
  local wasRequestTime = lastRequestTime
  local cb = ::Callback((@(onSuccessCb, wasRequestTime) function(data) {
                         onGlobalStatusReceived(data, wasRequestTime)
                         if (onSuccessCb)
                           onSuccessCb()
                       })(onSuccessCb, wasRequestTime), this)

  ::g_tasker.charRequestJson(actionName, requestBlk, taskOptions, cb, onErrorCb)
}

g_ww_global_status.onGlobalStatusReceived <- function onGlobalStatusReceived(newData, wasRequestTime)
{
  lastUpdatetTime = ::dagor.getCurTime()
  local changedListsMask = 0
  foreach(gsType in ::g_ww_global_status_type.types)
    if (!::u.isEqual(gsType.getData(curData), gsType.getData(newData)))
      changedListsMask = changedListsMask | gsType.type

  if (!changedListsMask)
    return

  foreach(gsType in ::g_ww_global_status_type.types)
    if (gsType.invalidateByOtherStatusType & changedListsMask)
      changedListsMask = changedListsMask | gsType.type

  curData = newData
  validListsMask = validListsMask & ~changedListsMask
  pushStatusChangedEvent(changedListsMask)
}

g_ww_global_status.pushStatusChangedEvent <- function pushStatusChangedEvent(changedListsMask)
{
  ::ww_event("GlobalStatusChanged", { changedListsMask = changedListsMask })
}

g_ww_global_status.canRefreshData <- function canRefreshData(refreshDelay)
{
  if (lastRequestTime > lastUpdatetTime && lastRequestTime + REQUEST_TIMEOUT_MSEC > ::dagor.getCurTime())
    return false
  if (lastUpdatetTime > 0 && lastUpdatetTime + refreshDelay > ::dagor.getCurTime())
    return false
  if (!::has_feature("WorldWar"))
    return false
  return true
}

g_ww_global_status.getOperationById <- function getOperationById(operationId)
{
  return ::u.search(::g_ww_global_status_type.ACTIVE_OPERATIONS.getList(),
                    (@(operationId) function(o) { return o.id == operationId})(operationId))
}

g_ww_global_status.getMyClanOperation <- function getMyClanOperation()
{
  return ::u.search(::g_ww_global_status_type.ACTIVE_OPERATIONS.getList(),
                    function(o) { return o.isMyClanParticipate() })
}

g_ww_global_status.getNearestAvailableMap <- function getNearestAvailableMap()
{
  local nearestAvailable = []
  foreach(map in  ::g_ww_global_status_type.MAPS.getList())
    if (map.isWillAvailable())
      nearestAvailable.append(map)
  nearestAvailable.sort(@(a, b) a.getChangeStateTime() <=> b.getChangeStateTime())
  return nearestAvailable?[0]
}

g_ww_global_status.getMapByName <- function getMapByName(mapName)
{
  return ::getTblValue(mapName, ::g_ww_global_status_type.MAPS.getList())
}

//always return queue. do not return null
g_ww_global_status.getQueueByMapName <- function getQueueByMapName(mapName)
{
  return ::getTblValue(mapName, ::g_ww_global_status_type.QUEUE.getList()) || ::WwQueue(mapName)
}

g_ww_global_status.getOperationGroupByMapId <- function getOperationGroupByMapId(mapId)
{
  return ::u.search(::g_ww_global_status_type.OPERATIONS_GROUPS.getList(),
                    (@(mapId) function(og) { return og.mapId == mapId })(mapId)) || ::WwOperationsGroup(mapName)
}

g_ww_global_status.isMyClanInQueue <- function isMyClanInQueue()
{
  return ::is_in_clan()
          && !!::u.search(::g_ww_global_status_type.QUEUE.getList(),
                          function(q) { return q.isMyClanJoined() })
}

g_ww_global_status.onEventLoginComplete <- function onEventLoginComplete(p)
{
  refreshData(WWGS_REFRESH_DELAY.FORCED)
}

g_ww_global_status.onEventMyClanIdChanged <- function onEventMyClanIdChanged(p)
{
  foreach(op in ::g_ww_global_status_type.ACTIVE_OPERATIONS.getList())
    op.resetCache()
  foreach(q in ::g_ww_global_status_type.QUEUE.getList())
    q.resetCache()
  pushStatusChangedEvent(WW_GLOBAL_STATUS_TYPE.ACTIVE_OPERATIONS
                         | WW_GLOBAL_STATUS_TYPE.OPERATIONS_GROUPS
                         | WW_GLOBAL_STATUS_TYPE.MAPS
                         | WW_GLOBAL_STATUS_TYPE.QUEUE)
}

g_ww_global_status.onEventScriptsReloaded <- function onEventScriptsReloaded(p)
{
  refreshData()
}

::g_script_reloader.registerPersistentDataFromRoot("g_ww_global_status")
::subscribe_handler(::g_ww_global_status, ::g_listener_priority.DEFAULT_HANDLER)
