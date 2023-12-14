//checked for plus_string
from "%scripts/dagui_natives.nut" import clan_get_my_clan_id
from "%scripts/dagui_library.nut" import *
from "%scripts/worldWar/worldWarConst.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")

let { get_time_msec } = require("dagor.time")
let subscriptions = require("%sqStdLibs/helpers/subscriptions.nut")
let { secondsToMilliseconds } = require("%scripts/time.nut")
let DataBlock  = require("DataBlock")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { charRequestJson } = require("%scripts/tasker.nut")
let wwEvent = require("%scripts/worldWar/wwEvent.nut")

local refreshMinTimeSec = 180
const MULTIPLY_REQUEST_TIMEOUT_BY_REFRESH = 2  //!!!FIX ME: it is better to increase request timeout gradually starting from min request time

let curData = mkWatched(persist, "curData", null)
let validListsMask = mkWatched(persist, "validListsMask", 0)
let lastUpdatetTime = mkWatched(persist, "lastUpdatetTime", -1)
let lastRequestTime = mkWatched(persist, "lastRequestTime", -1)
let isDeveloperMode = mkWatched(persist, "isDeveloperMode", false)

let function reset() {
  curData(null)
  validListsMask(0)
  lastUpdatetTime(-1)
  lastRequestTime(-1)
}

let function pushStatusChangedEvent(changedListsMask) {
  wwEvent("GlobalStatusChanged", { changedListsMask = changedListsMask })
}

let function canRefreshData(refreshDelay = null) {
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

let function updateCurData(newData) {
  let data = curData.value ?? {}
  foreach (name, value in newData)
    data[name] <- value

  curData(data)
}

let function onGlobalStatusReceived(newData) {
  lastUpdatetTime(get_time_msec())
  local changedListsMask = 0
  foreach (gsType in ::g_ww_global_status_type.types)
    if (!u.isEqual(gsType.getData(curData.value), gsType.getData(newData)))
      changedListsMask = changedListsMask | gsType.typeMask

  if (!changedListsMask)
    return

  foreach (gsType in ::g_ww_global_status_type.types)
    if (gsType.invalidateByOtherStatusType & changedListsMask)
      changedListsMask = changedListsMask | gsType.typeMask

  updateCurData(newData)
  validListsMask(validListsMask.value & ~changedListsMask)
  pushStatusChangedEvent(changedListsMask)
}

//special actions with global status in successCb
let function actionWithGlobalStatusRequest(actionName, requestBlk = null, taskOptions = null, onSuccessCb = null) {
  if (isDeveloperMode.value) { // Force full global status request in developer mode
    actionName = "cln_ww_global_status"
    requestBlk = null
  }

  lastRequestTime(get_time_msec())
  let cb = Callback(function(data) {
    onGlobalStatusReceived(data)
    if (onSuccessCb)
      onSuccessCb()
  }, this)

  if (requestBlk == null)
    requestBlk = DataBlock()

  charRequestJson(actionName, requestBlk, taskOptions, cb)
}

let function onEventMyClanIdChanged(_p) {
  foreach (op in ::g_ww_global_status_type.ACTIVE_OPERATIONS.getList())
    op.resetCache()
  foreach (q in ::g_ww_global_status_type.QUEUE.getList())
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
  if (!canRefreshData(refreshDelay))
    return

  if (isDeveloperMode.value) // Full global status includes all data from short and queue statuses
    return actionWithGlobalStatusRequest("cln_ww_global_status")

  let requestBlk = DataBlock()
  if (::is_in_clan())
    requestBlk.clanId = clan_get_my_clan_id()
  if (::g_world_war.lastPlayedOperationId != null)
    requestBlk.operationId = ::g_world_war.lastPlayedOperationId
  actionWithGlobalStatusRequest("cln_ww_global_status_short", requestBlk)
  if (handlersManager.findHandlerClassInScene(gui_handlers.WwOperationsMapsHandler) != null)
    actionWithGlobalStatusRequest("cln_ww_queue_status")
}

return {
  refreshGlobalStatusData
  actionWithGlobalStatusRequest
  getValidGlobalStatusListMask = @() validListsMask.value
  setValidGlobalStatusListMask = @(mask) validListsMask(mask)
  getGlobalStatusData = @() curData.value
  setDeveloperMode = @(p) isDeveloperMode(p)
}
