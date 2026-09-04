from "dagor.workcycle" import setTimeout, clearTimer
from "dagor.random" import frnd
import "math" as math











function debounce(func, delay_s: number, delay_s_max: number|null = null): function {
  let storage = { func = @() null }
  let action = @() storage.func()
  function debounced(...) {
    storage.func <- @() func.acall([null].extend(vargv))
    clearTimer(action)
    let time = delay_s_max == null
      ? delay_s
      : math.min(delay_s, delay_s_max) + frnd() * math.abs(delay_s_max - delay_s)
    setTimeout(time, action)
  }
  return debounced
}





function debounceImmediate(func, delay_s: number): function {
  local isActionAllowed = true
  function allowAction() { isActionAllowed = true }
  function debounced(...) {
    if (!isActionAllowed)
      return
    isActionAllowed = false
    func.acall([null].extend(vargv))
    setTimeout(delay_s, allowAction)
  }
  return debounced
}








let defThrottleOptions = {leading = true, trailing=false}
function throttle(func, delay_s: number, options=defThrottleOptions): function {
  let leading = options?.leading ?? defThrottleOptions.leading
  let trailing = options?.trailing ?? defThrottleOptions.trailing
  assert(leading || trailing, "throttle should be called with at least one front call leading or trailing")
  local isWaiting = false
  local pendingAction = null
  function onWindowEnd(){
    if (trailing && pendingAction != null) {
      let action = pendingAction
      pendingAction = null
      setTimeout(delay_s, onWindowEnd)
      action()
      return
    }
    pendingAction = null
    isWaiting = false
  }
  function throttled(...){
    let action = @() func.acall([null].extend(vargv))
    if (isWaiting) {
      pendingAction = action
      return
    }
    isWaiting = true
    setTimeout(delay_s, onWindowEnd)
    if (leading)
      action()
    else
      pendingAction = action
  }
  return throttled
}

return {
  throttle
  debounce
  debounceImmediate
}