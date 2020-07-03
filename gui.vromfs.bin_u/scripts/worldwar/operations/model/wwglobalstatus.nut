local subscriptions = require("sqStdlibs/helpers/subscriptions.nut")

const REQUEST_TIMEOUT_MSEC = 300000

local curData = persist("curData", @() ::Watched(null))
local validListsMask = persist("validListsMask", @() ::Watched(0))
local lastUpdatetTime = persist("lastUpdatetTime", @() ::Watched(-1))
local lastRequestTime = persist("lastRequestTime", @() ::Watched(-1))

local function reset() {
  curData(null)
  validListsMask(0)
  lastUpdatetTime(-1)
  lastRequestTime(-1)
}

local function pushStatusChangedEvent(changedListsMask) {
  ::ww_event("GlobalStatusChanged", { changedListsMask = changedListsMask })
}

local function canRefreshData(refreshDelay) {
  if (lastRequestTime.value > lastUpdatetTime.value
      && lastRequestTime.value + REQUEST_TIMEOUT_MSEC > ::dagor.getCurTime())
    return false
  if (lastUpdatetTime.value > 0 && lastUpdatetTime.value + refreshDelay > ::dagor.getCurTime())
    return false
  if (!::has_feature("WorldWar"))
    return false
  return true
}

local function onGlobalStatusReceived(newData, wasRequestTime) {
  lastUpdatetTime(::dagor.getCurTime())
  local changedListsMask = 0
  foreach(gsType in ::g_ww_global_status_type.types)
    if (!::u.isEqual(gsType.getData(curData.value), gsType.getData(newData)))
      changedListsMask = changedListsMask | gsType.type

  if (!changedListsMask)
    return

  foreach(gsType in ::g_ww_global_status_type.types)
    if (gsType.invalidateByOtherStatusType & changedListsMask)
      changedListsMask = changedListsMask | gsType.type

  curData(newData)
  validListsMask(validListsMask.value & ~changedListsMask)
  pushStatusChangedEvent(changedListsMask)
}

//special actions with global status in successCb
local function actionWithGlobalStatusRequest(actionName, requestBlk, taskOptions = null, onSuccessCb = null, onErrorCb = null) {
  lastRequestTime(::dagor.getCurTime())
  local wasRequestTime = lastRequestTime.value
  local cb = ::Callback(function(data) {
    onGlobalStatusReceived(data, wasRequestTime)
    if (onSuccessCb)
      onSuccessCb()
  }, this)

  ::g_tasker.charRequestJson(actionName, requestBlk, taskOptions, cb, onErrorCb)
}

local function onEventMyClanIdChanged(p) {
  foreach(op in ::g_ww_global_status_type.ACTIVE_OPERATIONS.getList())
    op.resetCache()
  foreach(q in ::g_ww_global_status_type.QUEUE.getList())
    q.resetCache()
  pushStatusChangedEvent(WW_GLOBAL_STATUS_TYPE.ACTIVE_OPERATIONS
                         | WW_GLOBAL_STATUS_TYPE.OPERATIONS_GROUPS
                         | WW_GLOBAL_STATUS_TYPE.MAPS
                         | WW_GLOBAL_STATUS_TYPE.QUEUE)
}

subscriptions.addListenersWithoutEnv({
  SignOut = @(p) reset()
  MyClanIdChanged = onEventMyClanIdChanged
})

local function refreshGlobalStatusData(refreshDelay = WWGS_REFRESH_DELAY.LATENT_QUEUE_REFRESH) {
  if (canRefreshData(refreshDelay))
    actionWithGlobalStatusRequest("cln_ww_global_status", null)
}

return {
  refreshGlobalStatusData = refreshGlobalStatusData
  actionWithGlobalStatusRequest = actionWithGlobalStatusRequest
  getValidGlobalStatusListMask = @() validListsMask.value
  setValidGlobalStatusListMask = @(mask) validListsMask(mask)
  getGlobalStatusData = @() curData.value
}
