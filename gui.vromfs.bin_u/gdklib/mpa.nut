import "%gdkLib/impl/mpa.nut" as mpa
from "%gdkLib/impl/user.nut" import is_any_user_active

let logX = require("%sqstd/log.nut")().with_prefix("[MPA] ")

function set_activity(connection_string, join_restrictions, max_players, players, group_id, crossplatform, callback) {
  if (is_any_user_active()) {
    mpa.set_activity(connection_string, join_restrictions, max_players, players, group_id, crossplatform, callback)
  } else {
    logX("Activity wasn't set because there is no active user")
    callback?(false)
  }
}


function send_invitations(connection_string, xuids, crossplatform, callback) {
  if (is_any_user_active()) {
    mpa.send_invitations(connection_string, xuids, crossplatform, callback)
  } else {
    logX("Invitations weren't sent because there is no active user")
    callback?(false)
  }
}


function clear_activity(callback) {
  if (is_any_user_active()) {
    mpa.clear_activity(callback)
  } else {
    logX("Activity wasn't cleared because there is no active user")
    callback?(false)
  }
}


return freeze({
  JoinRestriction = mpa.JoinRestriction

  set_activity
  send_invitations
  clear_activity
})
