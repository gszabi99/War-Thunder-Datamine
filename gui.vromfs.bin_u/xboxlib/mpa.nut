let mpa = require("%xboxLib/impl/mpa.nut")

let crossPlatformActivities = persist("crossPlatformActivities", @() { allowed = true })


let function set_activity(connection_string, join_restrictions, max_players, players, group_id, callback) {
  mpa.set_activity(connection_string, join_restrictions,
    max_players, players, group_id, crossPlatformActivities.allowed, callback)
}


let function send_invitations(connection_string, xuids, callback) {
  mpa.send_invitations(connection_string, xuids, crossPlatformActivities.allowed, callback)
}


return {
  JoinRestriction = mpa.JoinRestriction

  set_activity
  send_invitations
  clear_activity = mpa.clear_activity
  allow_crossplatform_activities = @(value) crossPlatformActivities.allowed = value
}
