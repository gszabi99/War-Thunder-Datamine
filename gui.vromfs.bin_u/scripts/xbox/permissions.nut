let logX = require("%sqstd/log.nut")().with_prefix("[PERMISSIONS] ")
let {Privilege, State, retrieve_current_state, resolve_with_ui} = require("%xboxLib/impl/privileges.nut")
let {communicationsPrivilege, crossnetworkPrivilege, textWithAnonUser} = require("%scripts/xbox/crossnetwork.nut")
let {CommunicationState, retrieve_text_chat_permissions} = require("%xboxLib/impl/crossnetwork.nut")


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
  if (!(communicationsPrivilege.value && crossnetworkPrivilege.value))
    return CommunicationState.Blocked
  return textWithAnonUser.value
}


function check_multiplayer_sessions_privilege(try_resolve, callback) {
  check_privilege_with_resolution(Privilege.Multiplayer, try_resolve, function(success, state) {
    let result = success && (state == State.Allowed)
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
  retrieve_text_chat_permissions(xuid, function(_perm_success, perm_state) {
    callback?(perm_state)
  })
}


return {
  CommunicationState
  check_crossnetwork_play_privilege
  check_multiplayer_sessions_privilege
  check_crossnetwork_communications_permission
  check_communications_privilege
  can_we_text_user
}
