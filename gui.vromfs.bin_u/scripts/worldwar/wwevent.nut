let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { eventbus_subscribe } = require("eventbus")

eventbus_subscribe("wwEvent", @(p) broadcastEvent($"WW{p.eventName}", p))

return @(name, params = {}) broadcastEvent($"WW{name}", params)