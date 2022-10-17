let {subscribe, send} = require("eventbus")
let logX = require("%sqstd/log.nut")().with_prefix("[XBOX_PRESENCE] ")
let {subscribe_to_device_change_events, subscribe_to_title_change_events,
  retrieve_presences_for_users, start_monitoring, stop_monitoring} = require("%xboxLib/impl/presence.nut")
let {friendsXuids, mutedXuids, bannedXuids} = require("%xboxLib/relationships.nut")

let eventName = "XBOX_PRESENCE_UPDATE_EVENT"


let function subscribe_to_presences_update(callback) {
  subscribe(eventName, function(res) {
    callback?(res?.success, res?.presences)
  })
}


let function on_presences_update(success, presences) {
  send(eventName, {success = success, presences = presences})
}


let function update_presences_for_users(xuids) {
  retrieve_presences_for_users(xuids, on_presences_update)
}


let function on_device_change_event(xuid, dev_type, logged_in) {
  logX($"on_device_change_event: {xuid}, {dev_type}, {logged_in}")
  update_presences_for_users([xuid])
}


let function on_title_change_event(xuid, title_id, title_state) {
  logX($"on_title_change_event: {xuid}, {title_id}, {title_state}")
  update_presences_for_users([xuid])
}


subscribe_to_device_change_events(on_device_change_event)
subscribe_to_title_change_events(on_title_change_event)


friendsXuids.subscribe(function(v) {
  if (v.len() > 0) {
    update_presences_for_users(v)
    start_monitoring(v)
  }
})


mutedXuids.subscribe(function(v) {
  if (v.len() > 0) {
    stop_monitoring(v)
  }
})


bannedXuids.subscribe(function(v) {
  if (v.len() > 0) {
    stop_monitoring(v)
  }
})


return {
  subscribe_to_presences_update
  update_presences_for_users
}