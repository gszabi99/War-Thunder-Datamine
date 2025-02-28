let priv = require("gdk.privileges")
let {eventbus_subscribe_onehit} = require("eventbus")


function retrieve_current_state(privilege, callback) {
  let eventName = "xbox_privilege_get_current_state"
  eventbus_subscribe_onehit(eventName, function(result) {
    let success = result?.success
    let state = result?.state
    callback?(success, state)
  })
  priv.get_current_state(privilege, eventName)
}


function resolve_with_ui(privilege, callback) {
  let eventName = "xbox_privilege_resolve_with_ui"
  eventbus_subscribe_onehit(eventName, function(result) {
    let success = result?.success
    let state = result?.state
    callback?(success, state)
  })
  priv.resolve_with_ui(privilege, eventName)
}


return {
  Privilege = priv.Privilege
  State = priv.State

  resolve_with_ui
  retrieve_current_state
}
