let logX = require("%sqstd/log.nut")().with_prefix("[CROSSNET] ")
let {eventbus_subscribe, eventbus_unsubscribe} = require("eventbus")

let {retrieve_current_state} = require("%gdkLib/impl/privileges.nut")
let {check_anonymous} = require("%gdkLib/impl/permissions.nut")
let {track_privilege, stop_tracking_privilege, Privilege, State, STATE_CHANGE_EVENT_NAME} = require("gdk.privileges")
let {track_permission, stop_tracking_permission, Permission, AnonUserType, ANON_PERMISSION_STATE_CHANGE_EVENT_NAME} = require("gdk.permissions")
let {get_arg_value_by_name} = require("dagor.system")
let {hardPersistWatched} = require("%sqstd/globalState.nut")

let CommunicationsState = {
  Allowed = 0
  Blocked = 1
  Muted = 2
  FriendsOnly = 3
}

let multiplayerPrivilege = hardPersistWatched("xbox_xp_mp_priv", false)
let communicationsPrivilege = hardPersistWatched("xbox_xp_comm_priv", false)
let crossnetworkPrivilege = hardPersistWatched("xbox_xp_xp_priv", false)
let textAnonUser = hardPersistWatched("xbox_xp_text_au", false)
let voiceAnonUser = hardPersistWatched("xbox_xp_voice_au", false)
let textAnonFriend = hardPersistWatched("xbox_xp_text_af", false)
let voiceAnonFriend = hardPersistWatched("xbox_xp_voice_af", false)
let textWithAnonUser = hardPersistWatched("xbox_xp_text_anon", CommunicationsState.Blocked)
let voiceWithAnonUser = hardPersistWatched("xbox_xp_voice_anon", CommunicationsState.Blocked)

let debug_crossplay_state = get_arg_value_by_name("debug-crossnetwork") ?? false


function dump_whole_state() {
  if (debug_crossplay_state) {
    logX("FullState:")
    logX($"Multiplayer privilege: {multiplayerPrivilege.value}")
    logX($"Communications privilege: {communicationsPrivilege.value}")
    logX($"Crossnetwork privilege: {crossnetworkPrivilege.value}")
    logX($"Text with anonymous user: {textAnonUser.value}")
    logX($"Voice with anonymous user: {voiceAnonUser.value}")
  }
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
    dump_whole_state()
    track_privilege(privilege)
  })
}


function start_permission_tracking(permission, anon_user_type, watch) {
  check_anonymous(permission, anon_user_type, function(success, allowed, _) {
    if (success)
      update_or_trigger(watch, allowed)
    dump_whole_state()
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


// dump initial state
dump_whole_state()


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