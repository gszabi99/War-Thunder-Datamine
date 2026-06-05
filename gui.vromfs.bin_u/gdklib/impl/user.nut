import "gdk.user" as user
from "eventbus" import eventbus_subscribe_onehit
function init_default_user(callback) {
  let eventName = "xbox_user_init_default_user"
  eventbus_subscribe_onehit(eventName, function(result) {
    let xuid = result?.xuid ?? 0
    callback?(xuid)
  })
  user.init_default_user(eventName)
}


function shutdown_user(callback) {
  let eventName = "xbox_user_shutdown_user_event"
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


return freeze({
  init_default_user
  retrieve_auth_token
  shutdown_user

  show_profile_card
  get_xuid = user.get_xuid
  get_gamertag = user.get_gamertag
  is_any_user_active = user.is_any_user_active
})
