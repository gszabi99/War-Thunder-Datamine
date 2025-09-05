import "gdk.presence" as pres
from "eventbus" import eventbus_subscribe, eventbus_subscribe_onehit

function set_presence(presence, callback) {
  let eventName = "xbox_set_presence"
  eventbus_subscribe_onehit(eventName, function(result) {
    let success = result?.success
    callback?(success)
  })
  pres.set_presence(presence, eventName)
}


function subscribe_to_presence_update_events(callback) {
  pres.install_presence_update_callback()
  eventbus_subscribe(pres.presence_update_event_name, function(res) {
    let success = res?.success
    let presences = res?.presences
    callback?(success, presences)
  })
}


function subscribe_to_device_change_events(callback) {
  pres.install_device_change_callback()
  eventbus_subscribe(pres.device_change_event_name, function(res) {
    let xuid = res?.xuid
    let devType = res?.dev_type
    let loggedIn = res?.logged_in
    callback?(xuid, devType, loggedIn)
  })
}


function subscribe_to_title_change_events(callback) {
  pres.install_title_change_callback()
  eventbus_subscribe(pres.title_change_event_name, function(res) {
    let xuid = res?.xuid
    let titleId = res?.title_id
    let titleState = res?.title_state
    callback?(xuid, titleId, titleState)
  })
}


return freeze({
  UserPresence = pres.UserPresence
  DeviceType = pres.DeviceType
  TitleState = pres.TitleState

  subscribe_to_changes = pres.subscribe_to_changes
  unsubscribe_from_changes = pres.unsubscribe_from_changes
  set_update_call_interval = pres.set_update_call_interval

  set_presence
  retrieve_presences_for_users = pres.get_presences_for_users

  subscribe_to_presence_update_events
  subscribe_to_device_change_events
  subscribe_to_title_change_events

  start_monitoring = pres.start_monitoring
  stop_monitoring = pres.stop_monitoring
})