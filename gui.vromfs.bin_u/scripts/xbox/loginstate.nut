from "%scripts/dagui_natives.nut" import xbox_on_login
from "%scripts/dagui_library.nut" import *
let logX = require("%sqstd/log.nut")().with_prefix("[XBOX_LOGIN] ")
let {register_constrain_callback} = require("%xboxLib/impl/app.nut")
let {is_any_user_active} = require("%xboxLib/impl/user.nut")
let {on_xbox_logout} = require("%scripts/xbox/events.nut")
let user = require("%scripts/xbox/user.nut")
let achievements = require("%xboxLib/impl/achievements.nut")
let store = require("%xboxLib/impl/store.nut")
let presence = require("%xboxLib/impl/presence.nut")
let crossnetwork = require("%xboxLib/impl/crossnetwork.nut")
let relationships = require("%xboxLib/impl/relationships.nut")


let function update_relationships(fire_events, callback) {
  if (!is_any_user_active()) {
    logX("There is no active user, skipping relationships update")
    return
  }
  relationships.update_friends_list(fire_events, function(fsucc) {
    logX($"Updated friends list: {fsucc}")
    relationships.update_avoid_list(fire_events, function(asucc) {
      logX($"Updated avoid list: {asucc}")
      callback?()
    })
  })
}


let function do_login(callback) {
  achievements.synchronize(function(asucc) {
    logX($"Achievements synchromized: {asucc}")
    presence.subscribe_to_changes()
    store.initialize(function(ssucc) {
      logX($"Store initialized: {ssucc}")
      relationships.cleanup()
      update_relationships(false, function() {
        logX("Relationships updated")
        relationships.subscribe_to_changes()
        crossnetwork.update_state()
        callback?()
      })
    })
  })
}


let function do_logout(callback) {
  store.shutdown()
  relationships.unsubscribe_from_changes()
  presence.unsubscribe_from_changes()
  user.shutdown(function() {
    callback?()
  })
}


let function login(callback) {
  logX("Login")
  xbox_on_login(true, function(result) {
    let success = result == 0 // YU2_OK
    logX($"Login succeeded: {success}")
    do_login(function() {
      logX("Login to live services completed")
      callback?(result)
    })
  })
}


let function logout(callback) {
  logX("Logout")
  on_xbox_logout()
  do_logout(function() {
    logX("Logout from live completed")
    callback?()
  })
}


let function update_states_if_logged_in() {
  if (!is_any_user_active())
    return

  crossnetwork.update_state()
  update_relationships(true, function() {
    logX("Relationships updated")
  })
}


let function application_constrain_event_handler(active) {
  if (!active)
    return

  update_states_if_logged_in()
}

register_constrain_callback(application_constrain_event_handler)

update_states_if_logged_in()


return {
  login
  logout
}