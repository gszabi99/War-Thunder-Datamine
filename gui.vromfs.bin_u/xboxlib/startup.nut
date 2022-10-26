let logX = require("%sqstd/log.nut")().with_prefix("[XBOX_STARTUP] ")
let {register_constrain_callback} = require("%xboxLib/impl/app.nut")
let {shutdown_user, register_for_user_change_event, EventType} = require("%xboxLib/impl/user.nut")
let {logout, subscribe_to_login, subscribe_to_logout, is_logged_in} = require("%xboxLib/loginState.nut")
let {initialize_relationships, shutdown_relationships, update_relationships} = require("%xboxLib/relationships.nut")
let {populate_achievements_list} = require("%xboxLib/achievements.nut")
let store = require("%xboxLib/store.nut")
let presence = require("%xboxLib/impl/presence.nut")
let crossnetwork = require("%xboxLib/impl/crossnetwork.nut")


let function user_change_event_handler(event) {
  if (event == EventType.SignedOut) {
    logout()
  }
}


let function on_login() {
  populate_achievements_list()
  presence.subscribe_to_changes()
  store.initialize(function(success) {
    logX($"Store initialized: {success}")
  })
  initialize_relationships()
  crossnetwork.update_state()
}


let function on_logout() {
  store.shutdown()
  shutdown_relationships()
  presence.unsubscribe_from_changes()
  shutdown_user()
}


let function application_constrain_event_handler(active) {
  if (active && is_logged_in()) {
    crossnetwork.update_state()
    update_relationships()
    populate_achievements_list()
  }
}


subscribe_to_login(on_login)
subscribe_to_logout(on_logout)

register_constrain_callback(application_constrain_event_handler)
register_for_user_change_event(user_change_event_handler)