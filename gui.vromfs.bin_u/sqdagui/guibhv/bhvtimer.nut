from "%sqDagui/daguiNativeApi.nut" import *

let Timer = class {
  function onTimer(obj, dt) {
    let ud = obj.getUserData()
    if (type(ud) == "instance" || type(ud) == "table")
      ud[obj?.timer_handler_func ?? "onTimer"](obj, dt)
  }

  eventMask = EV_TIMER
}

replace_script_gui_behaviour("Timer", Timer)

return {Timer}