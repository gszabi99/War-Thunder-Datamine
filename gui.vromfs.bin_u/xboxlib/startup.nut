let logX = require("%sqstd/log.nut")().with_prefix("[XBOX_STARTUP] ")
let {register_constrain_callback} = require("%xboxLib/impl/app.nut")
let {shutdown_user, register_for_user_change_event, EventType, is_any_user_active} = require("%xboxLib/impl/user.nut")
let {logout, subscribe_to_login, subscribe_to_logout} = require("%xboxLib/loginState.nut")
let store = require("%xboxLib/impl/store.nut")
let presence = require("%xboxLib/impl/presence.nut")
let crossnetwork = require("%xboxLib/impl/crossnetwork.nut")
let relationships = require("%xboxLib/impl/relationships.nut")
let {populate_achievements_list} = require("%xboxLib/achievements.nut")


let function user_change_event_handler(event) {
  if (event == EventType.SignedOut) {
    logout()
  }
}


let function update_relationships(fire_events, callback) {
  if (!is_any_user_active()) {
    logX("There is no active user, skipping relationships update")
    return
  }
  relationships.update_friends_list(fire_events, function(fsucc) {
    logX($"Updated friends list: {fsucc}")
    relationships.update_mute_list(fire_events, function(msucc) {
      logX($"Updated mute list: {msucc}")
      relationships.update_avoid_list(fire_events, function(asucc) {
        logX($"Updated avoid list: {asucc}")
        callback?()
      })
    })
  })
}


let function on_login() {
  populate_achievements_list()
  presence.subscribe_to_changes()
  store.initialize(function(success) {
    logX($"Store initialized: {success}")
  })
  relationships.cleanup()
  update_relationships(false, function() {
    relationships.subscribe_to_changes()
  })
  crossnetwork.update_state()
}


let function on_logout() {
  store.shutdown()
  relationships.unsubscribe_from_changes()
  presence.unsubscribe_from_changes()
  shutdown_user()
}


let function application_constrain_event_handler(active) {
  if (active) {
    update_relationships(true, null)
    populate_achievements_list()
  }
}


subscribe_to_login(on_login)
subscribe_to_logout(on_logout)

register_constrain_callback(application_constrain_event_handler)
register_for_user_change_event(user_change_event_handler)