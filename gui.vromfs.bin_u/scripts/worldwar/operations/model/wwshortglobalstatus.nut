from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let subscriptions = require("%sqStdLibs/helpers/subscriptions.nut")
let { secondsToMilliseconds } = require("%scripts/time.nut")

local refreshMinTimeSec = 600
const MULTIPLY_REQUEST_TIMEOUT_BY_REFRESH = 2  //!!!FIX ME: it is better to increase request timeout gradually starting from min request time

let curData = persist("curData", @() Watched(null))
let validListsMask = persist("validListsMask", @() Watched(0))
let lastUpdatetTime = persist("lastUpdatetTime", @() Watched(-1))
let lastRequestTime = persist("lastRequestTime", @() Watched(-1))
let lastRequestUid = persist("lastRequestUid", @() Watched(-1))

let function pushStatusChangedEvent(changedListsMask) {
  ::ww_event("ShortGlobalStatusChanged", { changedListsMask = changedListsMask })
}

let function canRefreshData() {
  if (!hasFeature("WorldWar"))
    return false
  if (lastRequestUid.value != ::my_user_id_int64) //force request if user changed. Instead force request after relogin
    return true

  refreshMinTimeSec = ::g_world_war.getWWConfigurableValue("refreshShortGlobalStatusTimeSec", refreshMinTimeSec)
  let refreshMinTime = secondsToMilliseconds(refreshMinTimeSec)
  let requestTimeoutMsec = refreshMinTime * MULTIPLY_REQUEST_TIMEOUT_BY_REFRESH
  if (lastRequestTime.value > lastUpdatetTime.value
      && lastRequestTime.value + requestTimeoutMsec > ::dagor.getCurTime())
    return false
  if (lastUpdatetTime.value > 0 && lastUpdatetTime.value + refreshMinTime > ::dagor.getCurTime())
    return false
  return true
}

let function onGlobalStatusReceived(newData) {
  lastUpdatetTime(::dagor.getCurTime())
  local changedListsMask = 0
  foreach(gsType in ::g_ww_global_status_type.types)
    if (gsType.isAvailableInShortStatus
        && !::u.isEqual(gsType.getShortData(curData.value), gsType.getShortData(newData)))
      changedListsMask = changedListsMask | gsType.typeMask

  if (!changedListsMask)
    return

  curData(newData)
  validListsMask(validListsMask.value & ~changedListsMask)
  pushStatusChangedEvent(changedListsMask)
}

//special actions with short global status in successCb
let function actionWithGlobalStatusRequest(actionName, requestBlk) {
  lastRequestTime(::dagor.getCurTime())
  lastRequestUid(::my_user_id_int64)
  let cb = Callback(function(data) {
    onGlobalStatusReceived(data)
  }, this)

  ::g_tasker.charRequestJson(actionName, requestBlk, null, cb)
}

let function onEventMyClanIdChanged(p) {
  foreach(op in ::g_ww_global_status_type.ACTIVE_OPERATIONS.getShortStatusList())
    op.resetCache()
  pushStatusChangedEvent(WW_GLOBAL_STATUS_TYPE.ACTIVE_OPERATIONS
                         | WW_GLOBAL_STATUS_TYPE.OPERATIONS_GROUPS
                         | WW_GLOBAL_STATUS_TYPE.MAPS
                         | WW_GLOBAL_STATUS_TYPE.QUEUE)
}

subscriptions.addListenersWithoutEnv({
  MyClanIdChanged = onEventMyClanIdChanged
})

let function refreshShortGlobalStatusData() {
  if (!canRefreshData())
    return

  let requestBlk = ::DataBlock()
  if (::is_in_clan())
    requestBlk.clanId = ::clan_get_my_clan_id()
  if (::g_world_war.lastPlayedOperationId != null)
    requestBlk.operationId = ::g_world_war.lastPlayedOperationId
  actionWithGlobalStatusRequest("cln_ww_global_status_short", requestBlk)
}

return {
  refreshShortGlobalStatusData = refreshShortGlobalStatusData
  getValidShortGlobalStatusListMask = @() validListsMask.value
  setValidShortGlobalStatusListMask = @(mask) validListsMask(mask)
  getShortGlobalStatusData = @() curData.value
}
