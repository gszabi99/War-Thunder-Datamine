import "%sqstd/ecs.nut" as ecs
let { EventWindowActivated, EventWindowDeactivated } = require("os.window")
let { eventbus_send } = require("eventbus")

ecs.register_es("os_window_activation_tracker",
  {
    [EventWindowActivated] = @(...) eventbus_send("onWindowActivated", {}),
    [EventWindowDeactivated] = @(...) eventbus_send("onWindowDeactivated", {}),
  })
