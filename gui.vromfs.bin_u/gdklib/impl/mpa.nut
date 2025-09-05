import "gdk.mpa" as mpa
from "eventbus" import eventbus_subscribe_onehit

function clear_activity(callback) {
  let eventName = "xbox_mpa_clear_activity"
  eventbus_subscribe_onehit(eventName, function(result) {
    let success = result?.success
    callback?(success)
  })
  mpa.clear_activity(eventName)
}


function set_activity(connection_string, join_restrictions, max_players, players, group_id, crossplatform, callback) {
  let eventName = "xbox_mpa_set_activity"
  eventbus_subscribe_onehit(eventName, function(result) {
    let success = result?.success
    callback?(success)
  })
  mpa.set_activity(eventName, connection_string, join_restrictions, max_players, players, group_id, crossplatform)
}


function send_invitations(connection_string, xuids, crossplatform, callback) {
  let eventName = "xbox_mpa_send_invitations"
  eventbus_subscribe_onehit(eventName, function(result) {
    let success = result?.success
    callback?(success)
  })
  mpa.send_invites(eventName, connection_string, xuids, crossplatform)
}


function update_encounters(encounters, callback) {
  let eventName = "xbox_mpa_update_encounters"
  eventbus_subscribe_onehit(eventName, function(result) {
    let success = result?.success
    callback?(success)
  })
  mpa.update_encounters(eventName, encounters)
}


return freeze({
  JoinRestriction = mpa.JoinRestriction
  EncounterType = mpa.EncounterType

  is_available = @() true
  set_activity
  clear_activity
  send_invitations
  update_encounters
})
