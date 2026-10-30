import "%sqStdLibs/helpers/subscriptions.nut" as subscriptions
import "%scripts/worldWar/wwEvent.nut" as wwEvent
import "DataBlock" as DataBlock
from "%scripts/sqDagui/framework/gui_handlers.nut" import get_gui_handler
from "%scripts/time.nut" import secondsToMilliseconds
from "%scripts/tasker.nut" import charRequestJson
from "%scripts/worldWar/worldWarCfgState.nut" import getWWConfigurableValue, getLastPlayedOperationId
from "dagor.time" import get_time_msec
from "%scripts/dagui_natives.nut" import clan_get_my_clan_id
from "%scripts/dagui_library.nut" import *
from "%scripts/clans/clanState.nut" import is_in_clan

let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")

local refreshMinTimeSec = 180
const MULTIPLY_REQUEST_TIMEOUT_BY_REFRESH = 2  

let curData = Watched(null)
let validListsMask = Watched(0)
let lastUpdatetTime = Watched(-1)
let lastRequestTime = Watched(-1)
let isDeveloperMode = Watched(false)

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


function actionWithGlobalStatusRequest(actionName, requestBlk = null, taskOptions = null, onSuccessCb = null) {
  if (isDeveloperMode.get()) { 
    actionName = "cln_ww_global_status"
    requestBlk = null
  }

  lastRequestTime.set(get_time_msec())
  let cb = Callback(function(data) {
    lastUpdatetTime.set(get_time_msec())
    wwEvent("RawGlobalStatusReceived", { data })
    if (onSuccessCb)
      onSuccessCb()
  }, this)

  if (requestBlk == null)
    requestBlk = DataBlock()

  charRequestJson(actionName, requestBlk, taskOptions, cb)
}

subscriptions.addListenersWithoutEnv({
  SignOut = @(_p) reset()
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
  if (handlersManager.findHandlerClassInScene(get_gui_handler("WwOperationsMapsHandler")) != null)
    actionWithGlobalStatusRequest("cln_ww_queue_status")
}

return freeze({
  refreshGlobalStatusData
  actionWithGlobalStatusRequest
  getValidGlobalStatusListMask = @() validListsMask.get()
  setValidGlobalStatusListMask = @(mask) validListsMask.set(mask)
  getGlobalStatusData = @() curData.get()
  setDeveloperMode = @(p) isDeveloperMode.set(p)
  updateCurData
  pushStatusChangedEvent
})
