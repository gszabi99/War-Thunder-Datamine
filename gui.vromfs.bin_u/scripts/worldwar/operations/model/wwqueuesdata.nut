local { secondsToMilliseconds } = require("scripts/time.nut")

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
      ::dagor.getCurTime() - lastUpdateTimeMsec < getRefreshMinTimeMsec())
  }

  function canRequestByTime()
  {
    local refreshMinTime = getRefreshMinTimeMsec()
    local checkTime = isInUpdate
      ? refreshMinTime * MULTIPLY_REQUEST_TIMEOUT_BY_REFRESH
      : refreshMinTime
    return  ::dagor.getCurTime() - lastRequestTimeMsec >= checkTime
  }

  function canRequest()
  {
    return !isNewest() && canRequestByTime()
  }

  function isDataValid()
  {
    return (::dagor.getCurTime() - lastUpdateTimeMsec < WW_QUEUES_DATA_TIME_OUT)
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
    lastRequestTimeMsec = ::dagor.getCurTime()

    local cb = ::Callback(requestDataCb, this)
    local errorCb = ::Callback(requestError, this)

    ::queues.updateQueueInfoByType(::g_queue_type.WW_BATTLE, cb, errorCb, true)
    return true
  }

  /* ********************************************************************************
     ******************************* PRIVATE FUNCTIONS ******************************
     ******************************************************************************** */

  function requestDataCb(queuesData)
  {
    isInUpdate = false
    lastUpdateTimeMsec = ::dagor.getCurTime()
    data = queuesData

    ::ww_event("UpdateWWQueues")
  }

  function requestError(taskResult)
  {
    isInUpdate = false
  }

  function getRefreshMinTimeMsec() {
    refreshMinTimeSec = ::g_world_war.getWWConfigurableValue("refreshQueueInfoTimeSec", refreshMinTimeSec)
    return secondsToMilliseconds(refreshMinTimeSec)
  }
}

return WwQueuesData()
