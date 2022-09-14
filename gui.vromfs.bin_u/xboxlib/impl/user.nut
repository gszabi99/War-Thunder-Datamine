let user = require("xbox.user")
let {subscribe, subscribe_onehit} = require("eventbus")


local function init_default_user(callback) {
  let eventName = "xbox_user_init_default_user"
  subscribe_onehit(eventName, function(result) {
    let xuid = result?.xuid ?? 0
    callback?(xuid)
  })
  user.init_default_user(eventName)
}


local function init_user_with_ui(callback) {
  let eventName = "xbox_user_init_user_with_ui"
  subscribe_onehit(eventName, function(result) {
    let xuid = result?.xuid ?? 0
    callback?(xuid)
  })
  user.init_user_with_ui(eventName)
}


local function retrieve_achievements_list(callback) {
  let eventName = "xbox_user_retrieve_achievements_list"
  subscribe_onehit(eventName, function(result) {
    let success = result?.success
    let achievements = result?.achievements
    callback?(success, achievements)
  })
  user.get_achievements(eventName)
}


local function show_profile_card(xuid, callback) {
  let eventName = "xbox_user_show_profile_card"
  subscribe_onehit(eventName, function(result) {
    let success = result?.success
    callback?(success)
  })
  user.show_profile_card(xuid, eventName)
}


local function register_for_user_change_event(callback) {
  subscribe(user.user_change_event_name, function(result) {
    callback?(result?.event)
  })
}


return {
  AchievementStatus = user.AchievementStatus
  EventType = user.EventType

  init_default_user
  init_user_with_ui
  shutdown_user = user.shutdown_user
  register_for_user_change_event

  retrieve_achievements_list
  set_achievement_progress = user.set_achievement_progress

  show_profile_card
  get_xuid = user.get_xuid
  is_any_user_active = user.is_any_user_active
}