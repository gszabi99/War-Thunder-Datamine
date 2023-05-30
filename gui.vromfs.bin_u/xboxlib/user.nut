let {send, subscribe} = require("eventbus")
let {init_default_user, init_user_with_ui, shutdown_user} = require("%xboxLib/impl/user.nut")

let userInitEventName = "XBOX_USER_INIT_EVENT"
let userShutdownEventName = "XBOX_USER_SHUTDOWN_EVENT"


let function subscribe_to_user_init(callback) {
  subscribe(userInitEventName, function(res) {
    let withUi = res?.with_ui
    let xuid = res?.xuid
    callback?(xuid, withUi)
  })
}


let function subscribe_to_user_shutdown(callback) {
  subscribe(userShutdownEventName, function(_res) {
    callback?()
  })
}


let function init_user(with_ui, callback) {
  let func = with_ui ? init_user_with_ui : init_default_user
  func(function(xuid) {
    send(userInitEventName, {xuid = xuid, with_ui = with_ui})
    callback?(xuid)
  })
}


let function init_default(callback) {
  init_user(false, callback)
}


let function init_with_ui(callback) {
  init_user(true, callback)
}


let function shutdown() {
  shutdown_user()
  send(userShutdownEventName, {})
}


return {
  shutdown
  init_default
  init_with_ui
  subscribe_to_user_init
  subscribe_to_user_shutdown
}