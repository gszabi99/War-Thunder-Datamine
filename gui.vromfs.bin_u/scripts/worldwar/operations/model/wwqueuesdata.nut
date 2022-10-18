from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let { get_time_msec } = require("dagor.time")
let { secondsToMilliseconds } = require("%scripts/time.nut")

local refreshMinTimeSec = 2 //sec
const MULTIPLY_REQUEST_TIMEOUT_BY_REFRESH = 2
const WW_QUEUES_DATA_TIME_OUT = 10000 //ms


local WwQueuesData = class
{
  data = {}
  lastUpdateTimeMsec = -WW_QUEUES_DATA_TIME_OUT
  lastRequestTimeMsec = -1
  isInUpdate = false

  /* ********************************************************************************
     ******************************* PUBLIC FUNCTIONS *******************************
     ******************************************************************************** */

  function isNewest()
  {
    return (!isInUpdate &&
      get_time_msec() - lastUpdateTimeMsec < getRefreshMinTimeMsec())
  }

  function canRequestByTime()
  {
    let refreshMinTime = getRefreshMinTimeMsec()
    let checkTime = isInUpdate
      ? refreshMinTime * MULTIPLY_REQUEST_TIMEOUT_BY_REFRESH
      : refreshMinTime
    return  get_time_msec() - lastRequestTimeMsec >= checkTime
  }

  function canRequest()
  {
    return !isNewest() && canRequestByTime()
  }

  function isDataValid()
  {
    return (get_time_msec() - lastUpdateTimeMsec < WW_QUEUES_DATA_TIME_OUT)
  }

  function validateData()
  {
    if (!isDataValid())
      data = {}
  }

  function getData()
  {
    return data
  }

  function requestData()
  {
    if (!canRequest())
      return false

    isInUpdate = true
    lastRequestTimeMsec = get_time_msec()

    let cb = Callback(requestDataCb, this)
    let errorCb = Callback(requestError, this)

    ::queues.updateQueueInfoByType(::g_queue_type.WW_BATTLE, cb, errorCb, true)
    return true
  }

  /* ********************************************************************************
     ******************************* PRIVATE FUNCTIONS ******************************
     ******************************************************************************** */

  function requestDataCb(queuesData)
  {
    isInUpdate = false
    lastUpdateTimeMsec = get_time_msec()
    data = queuesData

    ::ww_event("UpdateWWQueues")
  }

  function requestError(_taskResult)
  {
    isInUpdate = false
  }

  function getRefreshMinTimeMsec() {
    refreshMinTimeSec = ::g_world_war.getWWConfigurableValue("refreshQueueInfoTimeSec", refreshMinTimeSec)
    return secondsToMilliseconds(refreshMinTimeSec)
  }
}

return WwQueuesData()
