let {eventbus_send, eventbus_subscribe} = require("eventbus")
let logX = require("%sqstd/log.nut")().with_prefix("[XBOX_USER] ")
let {init_default_user, init_user_with_ui, shutdown_user} = require("%xboxLib/impl/user.nut")

let userInitEventName = "XBOX_USER_INIT_EVENT"
let userShutdownEventName = "XBOX_USER_SHUTDOWN_EVENT"


function subscribe_to_user_init(callback) {
  eventbus_subscribe(userInitEventName, function(res) {
    let withUi = res?.with_ui
    let xuid = res?.xuid
    callback?(xuid, withUi)
  })
}


function subscribe_to_user_shutdown(callback) {
  eventbus_subscribe(userShutdownEventName, function(_res) {
    callback?()
  })
}


function init_user(with_ui, callback) {
  let func = with_ui ? init_user_with_ui : init_default_user
  func(function(xuid) {
    eventbus_send(userInitEventName, {xuid = xuid, with_ui = with_ui})
    callback?(xuid)
  })
}


function init_default(callback) {
  logX("init_default")
  init_user(false, callback)
}


function init_with_ui(callback) {
  logX("init_with_ui")
  init_user(true, callback)
}


function shutdown() {
  logX("shutdown")
  shutdown_user(function() {
    logX("shutdown completed")
    eventbus_send(userShutdownEventName, {})
  })
}


return {
  shutdown
  init_default
  init_with_ui
  subscribe_to_user_init
  subscribe_to_user_shutdown
}