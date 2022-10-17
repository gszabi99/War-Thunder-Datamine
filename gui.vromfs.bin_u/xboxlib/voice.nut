let {xbox2uid, uid2xbox, friendsUids} = require("%xboxLib/userIds.nut")
let {track_user_chat_permissions, stop_tracking_user_chat_permissions,
  register_chat_state_change_callback, CommunicationState} = require("%xboxLib/impl/crossnetwork.nut")
let {communicationsPrivilege, voiceWithAnonUser} = require("%xboxLib/crossnetwork.nut")
let {mutedXuids, bannedXuids} = require("%xboxLib/relationships.nut")
let voiceState = require("%xboxLib/voiceState.nut")
let logX = require("%sqstd/log.nut")().with_prefix("[XBOX_VOICE] ")


let function change_state_by_xuid(xuid, muted) {
  if (xuid in xbox2uid.value) {
    voiceState.set_member_state(xbox2uid.value[xuid], muted)
  }
}


let function process_updated_permissions(permissions) {
  foreach (permission in permissions) {
    let muted = (permission.voice != CommunicationState.Allowed)
    let xuid = permission.xuid
    change_state_by_xuid(xuid, muted)
  }
  logX("Permissions between users changed, updating")
  voiceState.update()
}


register_chat_state_change_callback(process_updated_permissions)


let function add_member(uid) {
  voiceState.add_member(uid)
  if (uid in uid2xbox.value) {
    track_user_chat_permissions(uid2xbox.value[uid])
  }
  logX("Member added, updating")
  voiceState.update()
}


let function remove_member(uid) {
  if (uid in uid2xbox.value) {
    stop_tracking_user_chat_permissions(uid2xbox.value[uid])
  }
  voiceState.remove_member(uid)
  logX("Member removed, updating")
  voiceState.update()
}


communicationsPrivilege.subscribe(function(_) {
  logX("Communication privilege changed, updating")
  voiceState.update()
})


voiceWithAnonUser.subscribe(function(_) {
  logX("Voice chat permission changed, updating")
  voiceState.update()
})


friendsUids.subscribe(function(_) {
  logX("Friends uids list changed, updating")
  voiceState.update()
})


mutedXuids.subscribe(function(_) {
  logX("Muted xuids list changed, updating")
  voiceState.update()
})


bannedXuids.subscribe(function(_) {
  logX("Banned xuids list changed, updating")
  voiceState.update()
})


return  {
  add_member
  remove_member
}