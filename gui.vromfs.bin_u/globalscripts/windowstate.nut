import "%sqstd/ecs.nut" as ecs
let {EventWindowActivated, EventWindowDeactivated} = require("os.window")
let mkWatched = require("mkWatched.nut")

let windowActive = mkWatched(persist, "windowActive", true)

ecs.register_es("os_window_activation_tracker",
  {
    [EventWindowActivated] = @(...) windowActive(true),
    [EventWindowDeactivated] = @(...) windowActive(false)
  })

return {
  windowActive
}
