const WW_QUEUES_REFRESH_MIN_TIME = 1000 //ms
const WW_QUEUES_REQUEST_TIME_OUT = 15000 //ms
const WW_QUEUES_DATA_TIME_OUT = 10000 //ms


local WwQueuesData = class
{
  data = {}
  lastUpdateTimeMsec = -WW_QUEUES_DATA_TIME_OUT
  lastRequestTimeMsec = -WW_QUEUES_REQUEST_TIME_OUT
  isInUpdate = false

  /* ********************************************************************************
     ******************************* PUBLIC FUNCTIONS *******************************
     ******************************************************************************** */

  function isNewest()
  {
    return (!isInUpdate &&
      ::dagor.getCurTime() - lastUpdateTimeMsec < WW_QUEUES_REFRESH_MIN_TIME)
  }

  function canRequestByTime()
  {
    local checkTime = isInUpdate
      ? WW_QUEUES_REQUEST_TIME_OUT
      : WW_QUEUES_REFRESH_MIN_TIME
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
}

return WwQueuesData()
