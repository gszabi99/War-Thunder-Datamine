from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { get_time_msec } = require("dagor.time")
let subscriptions = require("%sqStdLibs/helpers/subscriptions.nut")
let { secondsToMilliseconds } = require("%scripts/time.nut")

local refreshMinTimeSec = 180
const MULTIPLY_REQUEST_TIMEOUT_BY_REFRESH = 2  //!!!FIX ME: it is better to increase request timeout gradually starting from min request time

let curData = persist("curData", @() Watched(null))
let validListsMask = persist("validListsMask", @() Watched(0))
let lastUpdatetTime = persist("lastUpdatetTime", @() Watched(-1))
let lastRequestTime = persist("lastRequestTime", @() Watched(-1))

let function reset() {
  curData(null)
  validListsMask(0)
  lastUpdatetTime(-1)
  lastRequestTime(-1)
}

let function pushStatusChangedEvent(changedListsMask) {
  ::ww_event("GlobalStatusChanged", { changedListsMask = changedListsMask })
}

local function canRefreshData(refreshDelay = null) {
  if (!hasFeature("WorldWar"))
    return false
  refreshMinTimeSec = ::g_world_war.getWWConfigurableValue("refreshGlobalStatusTimeSec", refreshMinTimeSec)
  let refreshMinTime = secondsToMilliseconds(refreshMinTimeSec)
  refreshDelay = refreshDelay ?? refreshMinTime
  let requestTimeoutMsec = refreshMinTime * MULTIPLY_REQUEST_TIMEOUT_BY_REFRESH
  if (lastRequestTime.value > lastUpdatetTime.value
      && lastRequestTime.value + requestTimeoutMsec > get_time_msec())
    return false
  if (lastUpdatetTime.value > 0 && lastUpdatetTime.value + refreshDelay > get_time_msec())
    return false
  return true
}

let function onGlobalStatusReceived(newData) {
  lastUpdatetTime(get_time_msec())
  local changedListsMask = 0
  foreach(gsType in ::g_ww_global_status_type.types)
    if (!::u.isEqual(gsType.getData(curData.value), gsType.getData(newData)))
      changedListsMask = changedListsMask | gsType.typeMask

  if (!changedListsMask)
    return

  foreach(gsType in ::g_ww_global_status_type.types)
    if (gsType.invalidateByOtherStatusType & changedListsMask)
      changedListsMask = changedListsMask | gsType.typeMask

  curData(newData)
  validListsMask(validListsMask.value & ~changedListsMask)
  pushStatusChangedEvent(changedListsMask)
}

//special actions with global status in successCb
local function actionWithGlobalStatusRequest(actionName, requestBlk, taskOptions = null, onSuccessCb = null, onErrorCb = null) {
  lastRequestTime(get_time_msec())
  let cb = Callback(function(data) {
    onGlobalStatusReceived(data)
    if (onSuccessCb)
      onSuccessCb()
  }, this)
  if (requestBlk == null)
    requestBlk = ::DataBlock()

  requestBlk.addBlock("reqParams")
  requestBlk.reqParams.ERF_FAIL_ONCE = true

  ::g_tasker.charRequestJson(actionName, requestBlk, taskOptions, cb, onErrorCb)
}

let function onEventMyClanIdChanged(_p) {
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
  SignOut = @(_p) reset()
  MyClanIdChanged = onEventMyClanIdChanged
})

let function refreshGlobalStatusData(refreshDelay = null) {
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
