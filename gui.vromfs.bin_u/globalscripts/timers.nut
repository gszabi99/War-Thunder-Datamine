from "frp" import Watched
from "dagor.workcycle" import resetTimeout
from "dagor.time" import get_time_msec
from "math" import ceil, max

function mkCountdownTimer(endTimeWatch, timeProcess = @(v) v, step = 1.0, curTimeFunc = get_time_msec) {
  let countdownTimer = Watched(0)
  function updateTimer() {
    let leftTime = max(endTimeWatch.get() - curTimeFunc(), 0)
    if (leftTime > 0)
      resetTimeout(step, updateTimer)
    countdownTimer.set(timeProcess(leftTime))
  }
  endTimeWatch.subscribe(@(_) updateTimer())
  updateTimer()
  return countdownTimer
}

return {
  mkCountdownTimer
  mkCountdownTimerSec = @(endTimeWatch, step = 1.0) mkCountdownTimer(endTimeWatch, @(v) ceil(0.001 * v).tointeger(), step)
}