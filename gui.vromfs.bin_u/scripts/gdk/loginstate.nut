from "%scripts/dagui_natives.nut" import xbox_on_login
from "%scripts/dagui_library.nut" import *
let logX = require("%sqstd/log.nut")().with_prefix("[XBOX_LOGIN] ")
let {is_any_user_active} = require("%gdkLib/impl/user.nut")
let relationships = require("%gdkLib/impl/relationships.nut")
let {init_crossnetwork} = require("%gdkLib/crossnetwork.nut")
let {eventbus_subscribe_onehit} = require("eventbus")


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
  relationships.cleanup_relationships()
  update_relationships(false, function() {
    logX("Relationships updated")
    relationships.subscribe_to_changes()
    callback?()
  })
}


function native_login(send_statsd, event_name, callback) {
  eventbus_subscribe_onehit(event_name, function(data) {
    let status = data?.status ?? YU2_FAIL
    callback(status)
  })
  xbox_on_login(send_statsd, event_name)
}


function login(callback) {
  logX("Login")
  native_login(true, "xbox_login_event", function(result) {
    let success = result == YU2_OK
    logX($"Login succeeded: {success}")
    do_login(function() {
      logX("Login to live services completed")
      callback?(result)
    })
  })
}


return {
  native_login
  login
}