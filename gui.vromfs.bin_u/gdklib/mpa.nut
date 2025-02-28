let {is_any_user_active} = require("%gdkLib/impl/user.nut")
let mpa = require("%gdkLib/impl/mpa.nut")
let logX = require("%sqstd/log.nut")().with_prefix("[MPA] ")

let function set_activity(connection_string, join_restrictions, max_players, players, group_id, crossplatform, callback) {
  if (is_any_user_active()) {
    mpa.set_activity(connection_string, join_restrictions, max_players, players, group_id, crossplatform, callback)
  } else {
    logX("Activity wasn't set because there is no active user")
    callback?(false)
  }
}


let function send_invitations(connection_string, xuids, crossplatform, callback) {
  if (is_any_user_active()) {
    mpa.send_invitations(connection_string, xuids, crossplatform, callback)
  } else {
    logX("Invitations weren't sent because there is no active user")
    callback?(false)
  }
}


let function clear_activity(callback) {
  if (is_any_user_active()) {
    mpa.clear_activity(callback)
  } else {
    logX("Activity wasn't cleared because there is no active user")
    callback?(false)
  }
}


return {
  JoinRestriction = mpa.JoinRestriction

  set_activity
  send_invitations
  clear_activity
}
