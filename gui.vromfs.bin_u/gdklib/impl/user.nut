let user = require("gdk.user")
let {eventbus_subscribe, eventbus_subscribe_onehit} = require("eventbus")


function init_default_user(callback) {
  let eventName = "xbox_user_init_default_user"
  eventbus_subscribe_onehit(eventName, function(result) {
    let xuid = result?.xuid ?? 0
    callback?(xuid)
  })
  user.init_default_user(eventName)
}


function init_user_with_ui(callback) {
  let eventName = "xbox_user_init_user_with_ui"
  eventbus_subscribe_onehit(eventName, function(result) {
    let xuid = result?.xuid ?? 0
    callback?(xuid)
  })
  user.init_user_with_ui(eventName)
}


function shutdown_user(callback) {
  let eventName = "xbox_user_shutdown_user"
  eventbus_subscribe_onehit(eventName, function(_) {
    callback?()
  })
  user.shutdown_user(eventName)
}


function retrieve_auth_token(url, method, callback) {
  let eventName = "xbox_user_get_auth_token"
  eventbus_subscribe_onehit(eventName, function(result) {
    callback?(result?.success, result?.token, result?.signature)
  })
  user.get_auth_token(url, method, eventName)
}


function show_profile_card(xuid, callback) {
  let eventName = "xbox_user_show_profile_card"
  eventbus_subscribe_onehit(eventName, function(result) {
    let success = result?.success
    callback?(success)
  })
  user.show_profile_card(xuid, eventName)
}


function register_for_user_change_event(callback) {
  user.install_user_change_event_handler()
  eventbus_subscribe(user.user_change_event_name, function(result) {
    callback?(result?.event)
  })
}


return {
  EventType = user.EventType

  init_default_user
  init_user_with_ui
  retrieve_auth_token
  shutdown_user
  register_for_user_change_event

  show_profile_card
  get_xuid = user.get_xuid
  get_gamertag = user.get_gamertag
  is_any_user_active = user.is_any_user_active
}