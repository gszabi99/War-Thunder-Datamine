#explicit-this
#no-root-fallback

import "%sqstd/ecs.nut" as ecs
let { EventWindowActivated, EventWindowDeactivated } = require("os.window")
let { Computed } = require("frp")
let mkHardWatched = require("mkHardWatched.nut")
let eventbus = require("eventbus")
let logW = require("logs.nut").log_with_prefix("[WINDOW] ")
let { is_android } = require("%appGlobals/clientState/platform.nut")


let windowInactiveFlags = mkHardWatched("globals.windowInactiveFlags", {})
let windowActive = Computed(@() windowInactiveFlags.value.len() == 0)

let function blockWindow(flag) {
  if (flag in windowInactiveFlags.value)
    return
  logW($"block by {flag}. {windowActive.value ? "Set window to inactive" : ""}")
  windowInactiveFlags.mutate(@(v) v[flag] <- true)
}

let function unblockWindow(flag) {
  if (flag not in windowInactiveFlags.value)
    return
  logW($"unblock by {flag}. {windowInactiveFlags.value.len() == 1 ? "Set window to active" : ""}")
  windowInactiveFlags.mutate(@(v) delete v[flag])
}

if (is_android)
  eventbus.subscribe("mobile.onAppFocus",
    @(params) params.focus ? unblockWindow("androidAppFocus") : blockWindow("androidAppFocus"))

ecs.register_es("os_window_activation_tracker",
  {
    [EventWindowActivated] = @(...) unblockWindow("EventWindowActivated"),
    [EventWindowDeactivated] = @(...) blockWindow("EventWindowActivated"),
  })

return {
  windowActive
  blockWindow
  unblockWindow
}
