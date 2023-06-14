let { registerBroadcastEvent } = require("%sqstd/ecs.nut")

let broadcastEvents = {}
foreach (name, payload in {
      EventDedicLogerr = { text = "" } //server to client
      CmdEnableDedicatedLogger = { isEnable = true } //client to server
    })
  broadcastEvents.__update(registerBroadcastEvent(payload, name))

return freeze(broadcastEvents)
