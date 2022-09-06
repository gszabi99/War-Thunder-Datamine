let priv = require("xbox.privileges")
let {subscribe_onehit} = require("eventbus")


let function retrieve_current_state(privilege, allow_resolution, callback) {
  let eventName = "xbox_privilege_get_current_state"
  subscribe_onehit(eventName, function(result) {
    let success = result?.success
    let state = result?.state
    let reason = result?.reason
    callback?(success, state, reason)
  })
  priv.get_current_state(privilege, allow_resolution, eventName)
}


let function resolve_with_ui(privilege, callback) {
  let eventName = "xbox_privilege_resolve_with_ui"
  subscribe_onehit(eventName, function(result) {
    let success = result?.success
    let state = result?.state
    callback?(success, state)
  })
  priv.resolve_with_ui(privilege, eventName)
}


return {
  Privilege = priv.Privilege
  State = priv.State
  DenyReason = priv.DenyReason

  resolve_with_ui
  retrieve_current_state
}
