let { Computed } = require("frp")
let { hardPersistWatched } = require("%sqstd/globalState.nut")
let { subscribe } = require("eventbus")
let logW = require("logs.nut").log_with_prefix("[WINDOW] ")
let { is_mobile } = require("%appGlobals/clientState/platform.nut")


let windowInactiveFlags = hardPersistWatched("globals.windowInactiveFlags", {})
let windowActive = Computed(@() windowInactiveFlags.value.len() == 0)
local needDebug = false

let function blockWindow(flag) {
  if (flag in windowInactiveFlags.value)
    return
  if (needDebug)
    logW($"block by {flag}. {windowActive.value ? "Set window to inactive" : ""}")
  windowInactiveFlags.mutate(@(v) v[flag] <- true)
}

let function unblockWindow(flag) {
  if (flag not in windowInactiveFlags.value)
    return
  if (needDebug)
    logW($"unblock by {flag}. {windowInactiveFlags.value.len() == 1 ? "Set window to active" : ""}")
  windowInactiveFlags.mutate(@(v) v.$rawdelete(flag))
}

if (is_mobile)
  subscribe("mobile.onAppFocus",
    @(params) params.focus ? unblockWindow("mobileAppFocus") : blockWindow("mobileAppFocus"))

subscribe("onWindowActivated", @(_) unblockWindow("EventWindowActivated"))
subscribe("onWindowDeactivated", @(_) blockWindow("EventWindowActivated"))

return {
  windowActive
  allowDebug = function(value) { needDebug = value }
  blockWindow
  unblockWindow
}
