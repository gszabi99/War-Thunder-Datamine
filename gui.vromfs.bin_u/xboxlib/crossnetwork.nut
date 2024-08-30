let { Watched } = require("frp")
let logX = require("%sqstd/log.nut")().with_prefix("[CROSSNET] ")
let {eventbus_subscribe, eventbus_unsubscribe} = require("eventbus")

let {retrieve_current_state} = require("%xboxLib/impl/privileges.nut")
let {check_anonymous} = require("%xboxLib/impl/permissions.nut")
let {track_privilege, stop_tracking_privilege, Privilege, State, STATE_CHANGE_EVENT_NAME} = require("xbox.privileges")
let {track_permission, stop_tracking_permission, Permission, AnonUserType, ANON_PERMISSION_STATE_CHANGE_EVENT_NAME} = require("xbox.permissions")

let CommunicationsState = {
  Allowed = 0
  Blocked = 1
  Muted = 2
  FriendsOnly = 3
}

let multiplayerPrivilege = Watched(false)
let communicationsPrivilege = Watched(false)
let crossnetworkPrivilege = Watched(false)
let textAnonUser = Watched(false)
let voiceAnonUser = Watched(false)
let textAnonFriend = Watched(false)
let voiceAnonFriend = Watched(false)
let textWithAnonUser = Watched(false)
let voiceWithAnonUser = Watched(false)


function dump_whole_state() {
  logX("FullState:")
  logX($"Multiplayer privilege: {multiplayerPrivilege.value}")
  logX($"Communications privilege: {communicationsPrivilege.value}")
  logX($"Crossnetwork privilege: {crossnetworkPrivilege.value}")
  logX($"Text with anonymous user: {textAnonUser.value}")
  logX($"Voice with anonymous user: {voiceAnonUser.value}")
}


function update_or_trigger(what, new_value) {
  let updated = what.value != new_value
  if (updated)
    what.update(new_value)
  else
    what.trigger()
}


function compute_state(user, friend) {
  if (user)
    return CommunicationsState.Allowed
  else if (friend)
    return CommunicationsState.FriendsOnly
  return CommunicationsState.Blocked
}


function update_text_state() {
  let new_state = compute_state(textAnonUser.value, textAnonFriend.value)
  update_or_trigger(textWithAnonUser, new_state)
  dump_whole_state()
}


function update_voice_state() {
  let new_state = compute_state(voiceAnonUser.value, voiceAnonFriend.value)
  update_or_trigger(voiceWithAnonUser, new_state)
  dump_whole_state()
}


textAnonUser.subscribe(@(_) update_text_state())
textAnonFriend.subscribe(@(_) update_text_state())
voiceAnonUser.subscribe(@(_) update_voice_state())
voiceAnonFriend.subscribe(@(_) update_voice_state())


function on_privilege_state_change(data) {
  let privilege = data?.privilege
  let state = data?.state
  let allowed = state == State.Allowed
  logX($"Privilege state change: {privilege} {state}")
  if (privilege == Privilege.Multiplayer)
    update_or_trigger(multiplayerPrivilege, allowed)
  else if (privilege == Privilege.Communications)
    update_or_trigger(communicationsPrivilege, allowed)
  else if (privilege == Privilege.CrossPlay)
    update_or_trigger(crossnetworkPrivilege, allowed)
  dump_whole_state()
}


function on_permission_state_change(data) {
  let userType = data?.userType
  let permission = data?.permission
  let allowed = data?.allowed
  logX($"Permission state change: {userType} {permission} {allowed}")
  if (userType == AnonUserType.CrossNetworkUser) {
    if (permission == Permission.CommunicateUsingText)
      update_or_trigger(textAnonUser, allowed)
    else if (permission == Permission.CommunicateUsingVoice)
      update_or_trigger(voiceAnonUser, allowed)
  }
  else if (userType == AnonUserType.CrossNetworkFriend) {
    if (permission == Permission.CommunicateUsingText)
      update_or_trigger(textAnonFriend, allowed)
    else if (permission == Permission.CommunicateUsingVoice)
      update_or_trigger(voiceAnonFriend, allowed)
  }
}


function start_privilege_tracking(privilege, watch) {
  retrieve_current_state(privilege, function(success, state) {
    if (success)
      update_or_trigger(watch, state == State.Allowed)
    track_privilege(privilege)
  })
}


function start_permission_tracking(permission, anon_user_type, watch) {
  check_anonymous(permission, anon_user_type, function(success, allowed, _) {
    if (success)
      update_or_trigger(watch, allowed)
    track_permission(permission, anon_user_type)
  })
}


function init_crossnetwork() {
  eventbus_subscribe(STATE_CHANGE_EVENT_NAME, on_privilege_state_change)
  eventbus_subscribe(ANON_PERMISSION_STATE_CHANGE_EVENT_NAME, on_permission_state_change)
  start_privilege_tracking(Privilege.Multiplayer, multiplayerPrivilege)
  start_privilege_tracking(Privilege.Communications, communicationsPrivilege)
  start_privilege_tracking(Privilege.CrossPlay, crossnetworkPrivilege)
  start_permission_tracking(Permission.CommunicateUsingText, AnonUserType.CrossNetworkUser, textAnonUser)
  start_permission_tracking(Permission.CommunicateUsingVoice, AnonUserType.CrossNetworkUser, voiceAnonUser)
  start_permission_tracking(Permission.CommunicateUsingText, AnonUserType.CrossNetworkFriend, textAnonFriend)
  start_permission_tracking(Permission.CommunicateUsingVoice, AnonUserType.CrossNetworkFriend, voiceAnonFriend)
  logX("Crossnetwork initialized")
}


function shutdown_crossnetwork() {
  stop_tracking_permission(Permission.CommunicateUsingText, AnonUserType.CrossNetworkUser)
  stop_tracking_permission(Permission.CommunicateUsingVoice, AnonUserType.CrossNetworkUser)
  stop_tracking_permission(Permission.CommunicateUsingText, AnonUserType.CrossNetworkFriend)
  stop_tracking_permission(Permission.CommunicateUsingVoice, AnonUserType.CrossNetworkFriend)
  stop_tracking_privilege(Privilege.Multiplayer)
  stop_tracking_privilege(Privilege.Communications)
  stop_tracking_privilege(Privilege.CrossPlay)
  eventbus_unsubscribe(ANON_PERMISSION_STATE_CHANGE_EVENT_NAME, on_permission_state_change)
  eventbus_unsubscribe(STATE_CHANGE_EVENT_NAME, on_privilege_state_change)
  logX("Crossnetwork shutdown")
}


return {
  init_crossnetwork
  shutdown_crossnetwork

  CommunicationsState

  multiplayerPrivilege
  communicationsPrivilege
  crossnetworkPrivilege
  textWithAnonUser
  voiceWithAnonUser
}