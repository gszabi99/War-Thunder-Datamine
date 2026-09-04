from "%globalScripts/guiBehaviourConsts.nut" import *
from "%scripts/sqDagui/daguiNativeApi.nut" import *
from "types" import Table

let Timer = class {
  function onTimer(obj, dt) {
    let ud = obj.getUserData()
    if (type(ud) == "instance" || ud instanceof Table)
      ud[obj?.timer_handler_func ?? "onTimer"](obj, dt)
  }

  eventMask = EV_TIMER
}

replace_script_gui_behaviour("Timer", Timer)

return {Timer}