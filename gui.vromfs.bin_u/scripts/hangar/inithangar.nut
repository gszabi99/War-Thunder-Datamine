from "%scripts/dagui_library.nut" import *
from "dagor.workcycle" import resetTimeout, clearTimer
from "hangar" import activate_downloadable_hangar, get_current_downloadable_hangar
from "auth_wt" import setLoginHangarDelayed
from "console" import register_command
from "%sqstd/globalState.nut" import hardPersistWatched
let { isLoginStarted, isProfileReceived, isLoginRequired, isOnlineBinariesInited
} = require("%appGlobals/login/loginState.nut")
let { WatchedImmediate } = require("%sqstd/frp.nut")

const MAX_HANGAR_DELAY_TIME = 60

let debugHangar = hardPersistWatched("debugHangar")
let selectedHangar = hardPersistWatched("selectedHangar")

let needDelayHangarRaw = keepref(Computed(@() isLoginRequired.get() && isLoginStarted.get()
  && isOnlineBinariesInited.get() && (!isProfileReceived.get() || selectedHangar.get() == null)))
let needDelayHangar = keepref(WatchedImmediate(needDelayHangarRaw.get())) 

let undelayHangar = @() needDelayHangar.set(false)
needDelayHangarRaw.subscribe(function(v) {
  needDelayHangar.set(v)
  if (v)
    resetTimeout(MAX_HANGAR_DELAY_TIME, undelayHangar)
  else
    clearTimer(undelayHangar)
})

setLoginHangarDelayed(needDelayHangar.get())
needDelayHangar.subscribe(setLoginHangarDelayed)

let curHangar = keepref(Computed(@() debugHangar.get() ?? selectedHangar.get() ?? ""))

function activateHangar(h) {
  if (h == get_current_downloadable_hangar())
    return
  log($"[HANGAR] activate_downloadable_hangar '{h}'")
  activate_downloadable_hangar(h, "")
}
activateHangar(curHangar.get())
curHangar.subscribe(activateHangar)

function debugHangarToggle(id) {
  debugHangar.set(debugHangar.get() == id ? null : id)
  console_print($"Current hangar: {curHangar.get() == "" ? "hangar.blk" : curHangar.get()}") 
}

register_command(@() debugHangarToggle("config/hangar_xboxone.blk"), "hangar.activate_event")
register_command(@() debugHangarToggle(""), "hangar.activate_common")

return {
  selectedHangar
}
