#explicit-this
#no-root-fallback

import "%sqstd/ecs.nut" as ecs
let { EventWindowActivated, EventWindowDeactivated } = require("os.window")
let mkWatched = require("mkWatched.nut")
let eventbus = require("eventbus")
let { is_android } = require("%appGlobals/clientState/platform.nut")

let windowActive = mkWatched(persist, "windowActive", true)

if (is_android)
  eventbus.subscribe("mobile.onAppFocus", @(params) windowActive(params.focus))

ecs.register_es("os_window_activation_tracker",
  {
    [EventWindowActivated] = @(...) windowActive(true),
    [EventWindowDeactivated] = @(...) windowActive(false)
  })

return {
  windowActive
}
