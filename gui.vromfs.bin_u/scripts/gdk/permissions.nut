let logX = require("%sqstd/log.nut")().with_prefix("[PERMISSIONS] ")
let {is_retail_environment} = require("gdk.app")
let {Privilege, State, retrieve_current_state, resolve_with_ui} = require("%gdkLib/impl/privileges.nut")
let {check_for_user, check_deny_reason, Permission, DenyReason} = require("%gdkLib/impl/permissions.nut")
let {communicationsPrivilege, crossnetworkPrivilege, textWithAnonUser, CommunicationsState} = require("%gdkLib/crossnetwork.nut")


function check_privilege_with_resolution(privilege, attempt_resolution, callback) {
  retrieve_current_state(privilege, function(success, state) {
    if (state == State.ResolutionRequired && attempt_resolution) {
      resolve_with_ui(privilege, function(success_, state_) {
        callback?(success_, state_);
      });
    }
    else {
      callback?(success, state);
    }
  })
}


function check_crossnetwork_play_privilege(try_resolve, callback) {
  logX($"check_crossnetwork_play_privilege: {try_resolve}")
  check_privilege_with_resolution(Privilege.CrossPlay, try_resolve, function(success, state) {
    let result = success && (state == State.Allowed)
    callback?(result)
  })
}


function check_crossnetwork_communications_permission() {
  if (!(communicationsPrivilege.get() && crossnetworkPrivilege.get()))
    return CommunicationsState.Blocked
  return textWithAnonUser.get()
}


function check_multiplayer_sessions_privilege(try_resolve, callback) {
  check_privilege_with_resolution(Privilege.Multiplayer, try_resolve, function(success, state) {
    local result = success && (state == State.Allowed)
    
    
    
    
    if (!try_resolve && !is_retail_environment() && state == State.ResolutionRequired) {
      result = true
    }
    callback?(result)
  })
}


function check_ugc_privilege(try_resolve, callback) {
  check_privilege_with_resolution(Privilege.UserGeneratedContent, try_resolve, function(success, state) {
    local result = success && (state == State.Allowed)
    callback?(result)
  })
}


function check_communications_privilege(try_resolve, callback) {
  check_privilege_with_resolution(Privilege.Communications, try_resolve, function(success, state) {
    let result = success && (state == State.Allowed)
    callback?(result)
  })
}


function can_we_text_user(xuid, callback) {
  check_for_user(Permission.CommunicateUsingText, xuid, function(success, _, allowed, reasons) {
    local result = CommunicationsState.Blocked
    let isMuted = check_deny_reason(reasons, DenyReason.MuteListRestrictsTarget)
    if (success && allowed) {
      result = isMuted ? CommunicationsState.Muted : CommunicationsState.Allowed
    }
    callback(result)
  })
}


function can_see_user_content(xuid, callback) {
  check_for_user(Permission.ViewTargetUserCreatedContent, xuid, function(success, _, allowed, _) {
    callback?(success && allowed)
  })
}


return {
  CommunicationState = CommunicationsState
  check_crossnetwork_play_privilege
  check_multiplayer_sessions_privilege
  check_crossnetwork_communications_permission
  check_communications_privilege
  check_ugc_privilege
  can_we_text_user
  can_see_user_content
}
