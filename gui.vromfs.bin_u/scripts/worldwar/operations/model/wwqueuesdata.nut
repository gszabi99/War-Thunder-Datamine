from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

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
    return (!this.isInUpdate &&
      get_time_msec() - this.lastUpdateTimeMsec < this.getRefreshMinTimeMsec())
  }

  function canRequestByTime()
  {
    let refreshMinTime = this.getRefreshMinTimeMsec()
    let checkTime = this.isInUpdate
      ? refreshMinTime * MULTIPLY_REQUEST_TIMEOUT_BY_REFRESH
      : refreshMinTime
    return  get_time_msec() - this.lastRequestTimeMsec >= checkTime
  }

  function canRequest()
  {
    return !this.isNewest() && this.canRequestByTime()
  }

  function isDataValid()
  {
    return (get_time_msec() - this.lastUpdateTimeMsec < WW_QUEUES_DATA_TIME_OUT)
  }

  function validateData()
  {
    if (!this.isDataValid())
      this.data = {}
  }

  function getData()
  {
    return this.data
  }

  function requestData()
  {
    if (!this.canRequest())
      return false

    this.isInUpdate = true
    this.lastRequestTimeMsec = get_time_msec()

    let cb = Callback(this.requestDataCb, this)
    let errorCb = Callback(this.requestError, this)

    ::queues.updateQueueInfoByType(::g_queue_type.WW_BATTLE, cb, errorCb, true)
    return true
  }

  /* ********************************************************************************
     ******************************* PRIVATE FUNCTIONS ******************************
     ******************************************************************************** */

  function requestDataCb(queuesData)
  {
    this.isInUpdate = false
    this.lastUpdateTimeMsec = get_time_msec()
    this.data = queuesData

    ::ww_event("UpdateWWQueues", { queuesData })
  }

  function requestError(_taskResult)
  {
    this.isInUpdate = false
  }

  function getRefreshMinTimeMsec() {
    refreshMinTimeSec = ::g_world_war.getWWConfigurableValue("refreshQueueInfoTimeSec", refreshMinTimeSec)
    return secondsToMilliseconds(refreshMinTimeSec)
  }
}

return WwQueuesData()
