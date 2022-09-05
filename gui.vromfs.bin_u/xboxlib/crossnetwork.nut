let { register_for_user_change_event, EventType } = require("%xboxLib/impl/user.nut")
let { Watched } = require("frp")
let logX = require("%sqstd/log.nut")().with_prefix("[CROSSNET] ")
let cn = require("%xboxLib/impl/crossnetwork.nut")


let multiplayerPrivilege = Watched(false)
let communicationsPrivilege = Watched(false)
let crossnetworkPrivilege = Watched(false)
let textWithAnonUser = Watched(cn.CommunicationState.Blocked)
let voiceWithAnonUser = Watched(cn.CommunicationState.Blocked)


cn.register_state_change_callback(function(success) {
  logX($"Crossnetwork state updated: {success}")
  multiplayerPrivilege.update(success && cn.has_multiplayer_sessions_privilege())
  communicationsPrivilege.update(success && cn.has_communications_privilege())
  crossnetworkPrivilege.update(success && cn.has_crossnetwork_privilege())

  cn.retrieve_text_chat_permissions(0, function(tc_succ, tc_state) {
    logX($"Anonymous text chat permissions result: {tc_succ}, {tc_state}")
    textWithAnonUser.update(tc_succ ? tc_state : cn.CommunicationState.Blocked)
  })

  cn.retrieve_voice_chat_permissions(0, function(vc_succ, vc_state) {
    logX($"Anonymous voice chat permissions result: {vc_succ}, {vc_state}")
    voiceWithAnonUser.update(vc_succ ? vc_state : cn.CommunicationState.Blocked)
  })
})


register_for_user_change_event(function(event) {
  if (event == EventType.Privileges) {
    cn.update_state()
  }
})


return {
  multiplayerPrivilege
  communicationsPrivilege
  crossnetworkPrivilege
  textWithAnonUser
  voiceWithAnonUser
}