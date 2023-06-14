import "%sqstd/ecs.nut" as ecs
let { EventWindowActivated, EventWindowDeactivated } = require("os.window")
let { send } = require("eventbus")

ecs.register_es("os_window_activation_tracker",
  {
    [EventWindowActivated] = @(...) send("onWindowActivated", {}),
    [EventWindowDeactivated] = @(...) send("onWindowDeactivated", {}),
  })
