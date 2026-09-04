import "%sqstd/ecs.nut" as ecs
from "os.window" import EventWindowActivated, EventWindowDeactivated
from "eventbus" import eventbus_send

ecs.register_es("os_window_activation_tracker",
  {
    [EventWindowActivated] = @(...) eventbus_send("onWindowActivated", {}),
    [EventWindowDeactivated] = @(...) eventbus_send("onWindowDeactivated", {}),
  })
