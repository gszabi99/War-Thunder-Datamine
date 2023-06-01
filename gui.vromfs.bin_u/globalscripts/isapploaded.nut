let { Watched } = require("frp")
let { subscribe } = require("eventbus")
let { is_app_loaded } = require("app")

let isAppLoaded = Watched(is_app_loaded())

subscribe("isAppLoaded", @(_) isAppLoaded(true))

return isAppLoaded