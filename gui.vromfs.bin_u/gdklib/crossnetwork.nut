from "eventbus" import eventbus_subscribe, eventbus_unsubscribe
from "gdk.privileges" import track_privilege, stop_tracking_privilege, Privilege, State, STATE_CHANGE_EVENT_NAME
from "gdk.permissions" import track_permission, stop_tracking_permission, Permission, AnonUserType, ANON_PERMISSION_STATE_CHANGE_EVENT_NAME
from "dagor.system" import get_arg_value_by_name
from "nestdb" import ndbRead, ndbWrite, ndbExists
from "%sqstd/frp.nut" import Watched
from "%gdkLib/impl/privileges.nut" import retrieve_current_state
from "%gdkLib/impl/permissions.nut" import check_anonymous

let logX = require("%sqstd/log.nut")().with_prefix("[CROSSNET] ")

function getGlobalState(key, def=null){
  local curval = def
  if (ndbExists(key))
    curval = ndbRead(key)
  else
    ndbWrite(key, curval)
  let res = Watched(curval)
  function set(val) {
    ndbWrite(key, val)
    res.set(val)
  }
  return [ res, set ]
}

let CommunicationsState = {
  Allowed = 0
  Blocked = 1
  Muted = 2
  FriendsOnly = 3
}

let [ multiplayerPrivilege, multiplayerPrivilegeSet ] = getGlobalState("xbox_xp_mp_priv", false)
let [ communicationsPrivilege, communicationsPrivilegeSet ] = getGlobalState("xbox_xp_comm_priv", false)
let [ crossnetworkPrivilege, crossnetworkPrivilegeSet ] = getGlobalState("xbox_xp_xp_priv", false)
let [ textAnonUser, textAnonUserSet ] = getGlobalState("xbox_xp_text_au", false)
let [ voiceAnonUser, voiceAnonUserSet ] = getGlobalState("xbox_xp_voice_au", false)
let [ textAnonFriend, textAnonFriendSet ] = getGlobalState("xbox_xp_text_af", false)
let [ voiceAnonFriend, voiceAnonFriendSet ] = getGlobalState("xbox_xp_voice_af", false)
let [ textWithAnonUser, textWithAnonUserSet ] = getGlobalState("xbox_xp_text_anon", CommunicationsState.Blocked)
let [ voiceWithAnonUser, voiceWithAnonUserSet ] = getGlobalState("xbox_xp_voice_anon", CommunicationsState.Blocked)

let debug_crossplay_state = get_arg_value_by_name("debug-crossnetwork") ?? false


function dump_whole_state() {
  if (debug_crossplay_state) {
    logX("FullState:")
    logX($"Multiplayer privilege: {multiplayerPrivilege.get()}")
    logX($"Communications privilege: {communicationsPrivilege.get()}")
    logX($"Crossnetwork privilege: {crossnetworkPrivilege.get()}")
    logX($"Text with anonymous user: {textAnonUser.get()}")
    logX($"Voice with anonymous user: {voiceAnonUser.get()}")
  }
}


function update_or_trigger(what, new_value, setter) {
  let updated = what.get() != new_value
  if (updated)
    setter(new_value)
  else
    what.trigger()
}


function compute_state(user, friend) {
  return user ? CommunicationsState.Allowed
    : friend ? CommunicationsState.FriendsOnly
    : CommunicationsState.Blocked
}


function update_text_state() {
  let new_state = compute_state(textAnonUser.get(), textAnonFriend.get())
  update_or_trigger(textWithAnonUser, new_state, textWithAnonUserSet)
  dump_whole_state()
}


function update_voice_state() {
  let new_state = compute_state(voiceAnonUser.get(), voiceAnonFriend.get())
  update_or_trigger(voiceWithAnonUser, new_state, voiceWithAnonUserSet)
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
    update_or_trigger(multiplayerPrivilege, allowed, multiplayerPrivilegeSet)
  else if (privilege == Privilege.Communications)
    update_or_trigger(communicationsPrivilege, allowed, communicationsPrivilegeSet)
  else if (privilege == Privilege.CrossPlay)
    update_or_trigger(crossnetworkPrivilege, allowed, crossnetworkPrivilege)
  dump_whole_state()
}


function on_permission_state_change(data) {
  let userType = data?.userType
  let permission = data?.permission
  let allowed = data?.allowed
  logX($"Permission state change: {userType} {permission} {allowed}")
  if (userType == AnonUserType.CrossNetworkUser) {
    if (permission == Permission.CommunicateUsingText)
      update_or_trigger(textAnonUser, allowed, textAnonUserSet)
    else if (permission == Permission.CommunicateUsingVoice)
      update_or_trigger(voiceAnonUser, allowed, voiceAnonUserSet)
  }
  else if (userType == AnonUserType.CrossNetworkFriend) {
    if (permission == Permission.CommunicateUsingText)
      update_or_trigger(textAnonFriend, allowed, textAnonFriendSet)
    else if (permission == Permission.CommunicateUsingVoice)
      update_or_trigger(voiceAnonFriend, allowed, voiceAnonFriendSet)
  }
}


function start_privilege_tracking(privilege, watch, watchSetter) {
  retrieve_current_state(privilege, function(success, state) {
    if (success)
      update_or_trigger(watch, state == State.Allowed, watchSetter)
    dump_whole_state()
    track_privilege(privilege)
  })
}


function start_permission_tracking(permission, anon_user_type, watch, watchSetter) {
  check_anonymous(permission, anon_user_type, function(success, allowed, _) {
    if (success)
      update_or_trigger(watch, allowed, watchSetter)
    dump_whole_state()
    track_permission(permission, anon_user_type)
  })
}


function init_crossnetwork() {
  eventbus_subscribe(STATE_CHANGE_EVENT_NAME, on_privilege_state_change)
  eventbus_subscribe(ANON_PERMISSION_STATE_CHANGE_EVENT_NAME, on_permission_state_change)
  start_privilege_tracking(Privilege.Multiplayer, multiplayerPrivilege, multiplayerPrivilegeSet)
  start_privilege_tracking(Privilege.Communications, communicationsPrivilege, communicationsPrivilegeSet)
  start_privilege_tracking(Privilege.CrossPlay, crossnetworkPrivilege, crossnetworkPrivilegeSet)
  start_permission_tracking(Permission.CommunicateUsingText, AnonUserType.CrossNetworkUser, textAnonUser, textAnonUserSet)
  start_permission_tracking(Permission.CommunicateUsingVoice, AnonUserType.CrossNetworkUser, voiceAnonUser, voiceAnonUserSet)
  start_permission_tracking(Permission.CommunicateUsingText, AnonUserType.CrossNetworkFriend, textAnonFriend, textAnonFriendSet)
  start_permission_tracking(Permission.CommunicateUsingVoice, AnonUserType.CrossNetworkFriend, voiceAnonFriend, voiceAnonFriendSet)
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



dump_whole_state()


return freeze({
  init_crossnetwork
  shutdown_crossnetwork

  CommunicationsState

  multiplayerPrivilege
  communicationsPrivilege
  crossnetworkPrivilege
  textWithAnonUser
  voiceWithAnonUser
})