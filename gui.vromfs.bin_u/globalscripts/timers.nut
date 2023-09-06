let { Watched } = require("frp")
let { resetTimeout } = require("dagor.workcycle")
let { get_time_msec } = require("dagor.time")
let { ceil } = require("math")

let function mkCountdownTimer(endTimeWatch, timeProcess = @(v) v, step = 1.0, curTimeFunc = get_time_msec) {
  let countdownTimer = Watched(0)
  let function updateTimer() {
    let leftTime = max(endTimeWatch.value - curTimeFunc(), 0)
    if (leftTime > 0)
      resetTimeout(step, updateTimer)
    countdownTimer(timeProcess(leftTime))
  }
  endTimeWatch.subscribe(@(_) updateTimer())
  updateTimer()
  return countdownTimer
}

return {
  mkCountdownTimer
  mkCountdownTimerSec = @(endTimeWatch, step = 1.0) mkCountdownTimer(endTimeWatch, @(v) ceil(v / 1000).tointeger(), step)
}