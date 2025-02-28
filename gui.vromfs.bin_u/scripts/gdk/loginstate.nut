from "%scripts/dagui_natives.nut" import xbox_on_login
from "%scripts/dagui_library.nut" import *
let logX = require("%sqstd/log.nut")().with_prefix("[XBOX_LOGIN] ")
let {register_constrain_callback} = require("%gdkLib/impl/app.nut")
let {is_any_user_active} = require("%gdkLib/impl/user.nut")
let {on_xbox_logout} = require("%scripts/gdk/events.nut")
let user = require("%scripts/gdk/user.nut")
let achievements = require("%gdkLib/impl/achievements.nut")
let store = require("%gdkLib/impl/store.nut")
let presence = require("%gdkLib/impl/presence.nut")
let relationships = require("%gdkLib/impl/relationships.nut")
let {init_crossnetwork, shutdown_crossnetwork} = require("%gdkLib/crossnetwork.nut")
let {loading_is_in_progress} = require("loading")
let { debounce } = require("%sqstd/timers.nut")


function update_relationships(fire_events, callback) {
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


function do_login(callback) {
  init_crossnetwork()
  achievements.synchronize(function(asucc) {
    logX($"Achievements synchromized: {asucc}")
    presence.subscribe_to_changes()
    store.initialize(function(ssucc) {
      logX($"Store initialized: {ssucc}")
      relationships.cleanup()
      update_relationships(false, function() {
        logX("Relationships updated")
        relationships.subscribe_to_changes()
        callback?()
      })
    })
  })
}


function do_logout(callback) {
  store.shutdown()
  relationships.unsubscribe_from_changes()
  presence.unsubscribe_from_changes()
  shutdown_crossnetwork()
  user.shutdown(function() {
    callback?()
  })
}


function login(callback) {
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


function callback_after_loading_finish(callback) {
  let debounced = debounce(callback_after_loading_finish, 0.1)
  if (loading_is_in_progress()) {
    debounced(callback)
  } else {
    callback?()
  }
}


function logout(callback) {
  logX("Logout")
  on_xbox_logout()
  do_logout(function() {
    logX("Logout from live completed")
    callback_after_loading_finish(callback)
  })
}


function update_states_if_logged_in() {
  if (!is_any_user_active())
    return

  update_relationships(true, function() {
    logX("Relationships updated")
  })
}


function application_constrain_event_handler(active) {
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