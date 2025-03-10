from "%scripts/dagui_library.nut" import *
from "%scripts/queue/queueType.nut" import g_queue_type

let { get_time_msec } = require("dagor.time")
let { secondsToMilliseconds } = require("%scripts/time.nut")
let wwEvent = require("%scripts/worldWar/wwEvent.nut")
let { getWWConfigurableValue } = require("%scripts/worldWar/worldWarStates.nut")

local refreshMinTimeSec = 2 
const MULTIPLY_REQUEST_TIMEOUT_BY_REFRESH = 2
const WW_QUEUES_DATA_TIME_OUT = 10000 


let WwQueuesData = class {
  data = {}
  lastUpdateTimeMsec = -WW_QUEUES_DATA_TIME_OUT
  lastRequestTimeMsec = -1
  isInUpdate = false

  



  function isNewest() {
    return (!this.isInUpdate &&
      get_time_msec() - this.lastUpdateTimeMsec < this.getRefreshMinTimeMsec())
  }

  function canRequestByTime() {
    let refreshMinTime = this.getRefreshMinTimeMsec()
    let checkTime = this.isInUpdate
      ? refreshMinTime * MULTIPLY_REQUEST_TIMEOUT_BY_REFRESH
      : refreshMinTime
    return  get_time_msec() - this.lastRequestTimeMsec >= checkTime
  }

  function canRequest() {
    return !this.isNewest() && this.canRequestByTime()
  }

  function isDataValid() {
    return (get_time_msec() - this.lastUpdateTimeMsec < WW_QUEUES_DATA_TIME_OUT)
  }

  function validateData() {
    if (!this.isDataValid())
      this.data = {}
  }

  function getData() {
    return this.data
  }

  function requestData() {
    if (!this.canRequest())
      return false

    this.isInUpdate = true
    this.lastRequestTimeMsec = get_time_msec()

    let cb = Callback(this.requestDataCb, this)
    let errorCb = Callback(this.requestError, this)

    ::queues.updateQueueInfoByType(g_queue_type.WW_BATTLE, cb, errorCb, true)
    return true
  }

  



  function requestDataCb(queuesData) {
    this.isInUpdate = false
    this.lastUpdateTimeMsec = get_time_msec()
    this.data = queuesData

    wwEvent("UpdateWWQueues", { queuesData })
  }

  function requestError(_taskResult) {
    this.isInUpdate = false
  }

  function getRefreshMinTimeMsec() {
    refreshMinTimeSec = getWWConfigurableValue("refreshQueueInfoTimeSec", refreshMinTimeSec)
    return secondsToMilliseconds(refreshMinTimeSec)
  }
}

return WwQueuesData()
