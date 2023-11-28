let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")

return @(name, params = {}) broadcastEvent($"WW{name}", params)