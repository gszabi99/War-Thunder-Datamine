from "frp" import Watched
from "eventbus" import eventbus_subscribe
from "app" import is_app_loaded

let isAppLoaded = Watched(is_app_loaded())

eventbus_subscribe("isAppLoaded", @(_) isAppLoaded.set(true))

return isAppLoaded