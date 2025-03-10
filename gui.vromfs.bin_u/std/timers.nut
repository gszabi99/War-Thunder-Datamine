from "dagor.workcycle" import setTimeout, clearTimer
from "dagor.random" import frnd
let math = require("math")











function debounce(func, delay_s, delay_s_max = null){
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





function debounceImmediate(func, delay_s){
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
function throttle(func, delay_s, options=defThrottleOptions){
  let leading = options?.leading ?? defThrottleOptions.leading
  let trailing = options?.trailing ?? defThrottleOptions.trailing
  local needCallByTimer = false 
  assert(leading || trailing, "throttle should be called with at least one front call leading or trailing")
  local curAction = null
  function throttled(...){
    let doWait = curAction != null
    curAction = @() func.acall([null].extend(vargv))
    if (doWait) {
      needCallByTimer = !trailing
      return
    }
    function clearThrottled(){
      if (trailing)
        curAction()
      else if (needCallByTimer) {
        needCallByTimer = false
        curAction()
        setTimeout(delay_s, clearThrottled)
        return
      }
      curAction = null
    }
    if (leading){
      curAction()
    }
    setTimeout(delay_s, clearThrottled)
  }
  return throttled
}

return {
  throttle
  debounce
  debounceImmediate
}