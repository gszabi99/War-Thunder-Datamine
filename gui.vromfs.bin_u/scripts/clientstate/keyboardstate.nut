from "%scripts/dagui_library.nut" import *

let { eventbus_subscribe } = require("eventbus")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")

eventbus_subscribe("notify_keyboard_layout_changed", function notify_keyboard_layout_changed(payload) {
  let {layout} = payload
  broadcastEvent("KeyboardLayoutChanged", { layout })
})

eventbus_subscribe("notify_keyboard_locks_changed", function notify_keyboard_locks_changed(payload) {
  let {locks} = payload
  broadcastEvent("KeyboardLocksChanged", { locks })
})
