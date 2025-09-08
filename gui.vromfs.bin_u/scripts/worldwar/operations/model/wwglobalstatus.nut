from "%scripts/dagui_natives.nut" import clan_get_my_clan_id
from "%scripts/dagui_library.nut" import *
from "%scripts/worldWar/worldWarConst.nut" import *
from "%scripts/clans/clanState.nut" import is_in_clan

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { get_time_msec } = require("dagor.time")
let subscriptions = require("%sqStdLibs/helpers/subscriptions.nut")
let { secondsToMilliseconds } = require("%scripts/time.nut")
let DataBlock  = require("DataBlock")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { charRequestJson } = require("%scripts/tasker.nut")
let wwEvent = require("%scripts/worldWar/wwEvent.nut")
let { getWWConfigurableValue, getLastPlayedOperationId } = require("%scripts/worldWar/worldWarStates.nut")

local refreshMinTimeSec = 180
const MULTIPLY_REQUEST_TIMEOUT_BY_REFRESH = 2  

let curData = mkWatched(persist, "curData", null)
let validListsMask = mkWatched(persist, "validListsMask", 0)
let lastUpdatetTime = mkWatched(persist, "lastUpdatetTime", -1)
let lastRequestTime = mkWatched(persist, "lastRequestTime", -1)
let isDeveloperMode = mkWatched(persist, "isDeveloperMode", false)

function reset() {
  curData.set(null)
  validListsMask.set(0)
  lastUpdatetTime.set(-1)
  lastRequestTime.set(-1)
}

function pushStatusChangedEvent(changedListsMask) {
  wwEvent("GlobalStatusChanged", { changedListsMask = changedListsMask })
}

function canRefreshData(refreshDelay = null) {
  if (!hasFeature("WorldWar"))
    return false

  refreshMinTimeSec = getWWConfigurableValue("refreshGlobalStatusTimeSec", refreshMinTimeSec)
  let refreshMinTime = secondsToMilliseconds(refreshMinTimeSec)
  refreshDelay = refreshDelay ?? refreshMinTime
  let requestTimeoutMsec = refreshMinTime * MULTIPLY_REQUEST_TIMEOUT_BY_REFRESH
  if (lastRequestTime.get() > lastUpdatetTime.get()
      && lastRequestTime.get() + requestTimeoutMsec > get_time_msec())
    return false
  if (lastUpdatetTime.get() > 0 && lastUpdatetTime.get() + refreshDelay > get_time_msec())
    return false
  return true
}

function updateCurData(newData) {
  let data = curData.get() ?? {}
  foreach (name, value in newData)
    data[name] <- value

  curData.set(data)
}

function onGlobalStatusReceived(newData) {
  lastUpdatetTime.set(get_time_msec())
  local changedListsMask = 0
  foreach (gsType in ::g_ww_global_status_type.types)
    if (!u.isEqual(gsType.getData(curData.get()), gsType.getData(newData)))
      changedListsMask = changedListsMask | gsType.typeMask

  if (!changedListsMask)
    return

  foreach (gsType in ::g_ww_global_status_type.types)
    if (gsType.invalidateByOtherStatusType & changedListsMask)
      changedListsMask = changedListsMask | gsType.typeMask

  updateCurData(newData)
  validListsMask.set(validListsMask.get() & ~changedListsMask)
  pushStatusChangedEvent(changedListsMask)
}


function actionWithGlobalStatusRequest(actionName, requestBlk = null, taskOptions = null, onSuccessCb = null) {
  if (isDeveloperMode.get()) { 
    actionName = "cln_ww_global_status"
    requestBlk = null
  }

  lastRequestTime.set(get_time_msec())
  let cb = Callback(function(data) {
    onGlobalStatusReceived(data)
    if (onSuccessCb)
      onSuccessCb()
  }, this)

  if (requestBlk == null)
    requestBlk = DataBlock()

  charRequestJson(actionName, requestBlk, taskOptions, cb)
}

function onEventMyClanIdChanged(_p) {
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

function refreshGlobalStatusData(refreshDelay = null) {
  if (!canRefreshData(refreshDelay))
    return

  if (isDeveloperMode.get()) 
    return actionWithGlobalStatusRequest("cln_ww_global_status")

  let requestBlk = DataBlock()
  if (is_in_clan())
    requestBlk.clanId = clan_get_my_clan_id()
  let lastPlayedOperationId = getLastPlayedOperationId()
  if (lastPlayedOperationId != null)
    requestBlk.operationId = lastPlayedOperationId
  actionWithGlobalStatusRequest("cln_ww_global_status_short", requestBlk)
  if (handlersManager.findHandlerClassInScene(gui_handlers.WwOperationsMapsHandler) != null)
    actionWithGlobalStatusRequest("cln_ww_queue_status")
}

return {
  refreshGlobalStatusData
  actionWithGlobalStatusRequest
  getValidGlobalStatusListMask = @() validListsMask.get()
  setValidGlobalStatusListMask = @(mask) validListsMask.set(mask)
  getGlobalStatusData = @() curData.get()
  setDeveloperMode = @(p) isDeveloperMode.set(p)
}
