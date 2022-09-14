let mpa = require("xbox.mpa")
let { subscribe_onehit } = require("eventbus")


let function clear_activity(callback) {
  let eventName = "xbox_mpa_clear_activity"
  subscribe_onehit(eventName, function(result) {
    let success = result?.success
    callback?(success)
  })
  mpa.clear_activity(eventName)
}


let function set_activity(connection_string, join_restrictions, max_players, players, group_id, crossplatform, callback) {
  let eventName = "xbox_mpa_set_activity"
  subscribe_onehit(eventName, function(result) {
    let success = result?.success
    callback?(success)
  })
  mpa.set_activity(eventName, connection_string, join_restrictions, max_players, players, group_id, crossplatform)
}

//xuids - array of uints
let function send_invitations(connection_string, xuids, crossplatform, callback) {
  let eventName = "xbox_mpa_send_invitations"
  subscribe_onehit(eventName, function(result) {
    let success = result?.success
    callback?(success)
  })
  mpa.send_invites(eventName, connection_string, xuids, crossplatform)
}


let function update_encounters(encounters, callback) {
  let eventName = "xbox_mpa_update_encounters"
  subscribe_onehit(eventName, function(result) {
    let success = result?.success
    callback?(success)
  })
  mpa.update_encounters(eventName, encounters)
}


return {
  JoinRestriction = mpa.JoinRestriction
  EncounterType = mpa.EncounterType

  is_available = mpa.is_available
  set_activity
  clear_activity
  send_invitations
  update_encounters
}
