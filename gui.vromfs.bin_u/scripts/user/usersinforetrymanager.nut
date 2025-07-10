from "%scripts/dagui_library.nut" import *
let { get_time_msec } = require("dagor.time")
let { setTimeout, clearTimer } = require("dagor.workcycle")

const TIMER_PREVENT_JITTER_OFFSET_MS = 100


let UsersInfoRetryManager = class {
  retryDelaysSec = null        
  maxRetries = null
  nextRetryTime = null
  requestFunc = null
  pendingRetries = null        
  retriesExhaustedUsers = null 
  timerId = null

  constructor(retryDelaysSec, requestFunc) {
    this.retryDelaysSec = retryDelaysSec
    this.maxRetries = retryDelaysSec.len()
    this.requestFunc = requestFunc
    this.pendingRetries = {}
    this.retriesExhaustedUsers = {}
  }

  function handleFailedUsers(userIds) {
    let now = get_time_msec()
    local hasNewRetries = false

    foreach (uid in userIds) {
      let info = this.pendingRetries?[uid]
      if (info == null) {
        this.pendingRetries[uid] <- {
          attempt = 0
          nextTimeMsec = now + this.retryDelaysSec[0] * 1000
        }
        hasNewRetries = true
      } else {
        info.attempt++
        if (info.attempt >= this.maxRetries) {
          this.pendingRetries.$rawdelete(uid)
          this.retriesExhaustedUsers[uid] <- true
        } else {
          let delaySec = this.retryDelaysSec?[info.attempt] ?? this.retryDelaysSec.top()
          info.nextTimeMsec = now + delaySec * 1000
          hasNewRetries = true
        }
      }
    }

    if (hasNewRetries)
      this.scheduleNextRetry()
  }

  function scheduleNextRetry() {
    if (this.pendingRetries.len() == 0)
      return

    let nextRetryTime = this.getNextRetryTime()

    if (this.timerId != null) {
      if (nextRetryTime >= this.nextRetryTime)
        return

      clearTimer(this.timerId)
      this.timerId = null
      this.nextRetryTime = null
    }

    let cb = Callback(function () {
      this.timerId = null
      this.nextRetryTime = null
      this.processPendingRetries()
    }, this)

    let delayMsec = max(nextRetryTime - get_time_msec(), 0) + TIMER_PREVENT_JITTER_OFFSET_MS
    let delaySec = delayMsec / 1000.0

    this.timerId = setTimeout(delaySec, @() cb())
    this.nextRetryTime = nextRetryTime
  }

  function processPendingRetries() {
    let now = get_time_msec()
    let readyForRetry = []

    foreach(uid, info in this.pendingRetries)
      if (now >= info.nextTimeMsec)
        readyForRetry.append(uid)

    if (readyForRetry.len() == 0) {
      this.scheduleNextRetry()
      return
    }

    this.requestFunc(readyForRetry)
  }

  function isRetriesExceed(uid) {
    return uid in this.retriesExhaustedUsers
  }

  function isRetryPending(uid) {
    return uid in this.pendingRetries
  }

  function getNextRetryTime() {
    if (this.pendingRetries.len() == 0)
      return 0

    local nearest = null
    foreach(_, info in this.pendingRetries)
      nearest = nearest == null
        ? info.nextTimeMsec
        : min(info.nextTimeMsec, nearest)

    return nearest
  }

  function resetRetryStatus(uid) {
    if (uid in this.pendingRetries)
      this.pendingRetries.$rawdelete(uid)
    if (uid in this.retriesExhaustedUsers)
      this.retriesExhaustedUsers.$rawdelete(uid)
  }
}

return { UsersInfoRetryManager }