let { Watched } = require("frp")
let { eventbus_subscribe } = require("eventbus")
let { is_app_loaded } = require("app")

let isAppLoaded = Watched(is_app_loaded())

eventbus_subscribe("isAppLoaded", @(_) isAppLoaded.set(true))

return isAppLoaded