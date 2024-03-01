let mpa = require("%xboxLib/impl/mpa.nut")


let ALLOW_CROSSPLATFORM_ACTIVITIES = true


function set_activity(connection_string, join_restrictions, max_players, players, group_id, callback) {
  mpa.set_activity(connection_string, join_restrictions,
    max_players, players, group_id, ALLOW_CROSSPLATFORM_ACTIVITIES, callback)
}


function send_invitations(connection_string, xuids, callback) {
  mpa.send_invitations(connection_string, xuids, ALLOW_CROSSPLATFORM_ACTIVITIES, callback)
}


return {
  JoinRestriction = mpa.JoinRestriction

  set_activity
  send_invitations
  clear_activity = mpa.clear_activity
}
