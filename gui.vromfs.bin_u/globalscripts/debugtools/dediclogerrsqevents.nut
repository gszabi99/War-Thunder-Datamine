let { registerBroadcastEvent } = require("%sqstd/ecs.nut")

let broadcastEvents = {}
foreach (name, payload in {
      EventDedicLogerr = { text = "" } 
      CmdEnableDedicatedLogger = { isEnable = true } 
    })
  broadcastEvents.__update(registerBroadcastEvent(payload, name))

return freeze(broadcastEvents)
