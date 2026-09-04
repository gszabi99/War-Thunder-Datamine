from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent
from "eventbus" import eventbus_subscribe

eventbus_subscribe("wwEvent", @(p) broadcastEvent($"WW{p.eventName}", p))

return @(name, params = {}) broadcastEvent($"WW{name}", params)