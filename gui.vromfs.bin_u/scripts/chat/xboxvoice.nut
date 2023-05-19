//checked for plus_string
from "%scripts/dagui_library.nut" import *
let { subscribe_to_state_update, add_voice_chat_member, remove_voice_chat_member,
  update_voice_chat_member_friendship, is_voice_chat_member_muted, voiceChatMembers } = require("%xboxLib/voice.nut")
let { reqPlayerExternalIDsByUserId } = require("%scripts/user/externalIdsService.nut")
let { add_event_listener } = require("%sqStdLibs/helpers/subscriptions.nut")

let requestedIds = persist("requestedIds", @() {})


let function is_muted(uid) {
  if (!is_platform_xbox)
    return false
  return is_voice_chat_member_muted(uid)
}


let function force_update_state_for_uid(uid) {
  if (uid) {
    let muted_by_platform = is_muted(uid)
    let muted_by_game = ::isPlayerInContacts(uid, EPL_BLOCKLIST)
    let muted_result = muted_by_platform || muted_by_game
    log($"Mute state change for <{uid}>: {muted_by_platform} + {muted_by_game} -> {muted_result}")
    ::gchat_voice_mute_peer_by_uid(muted_result, uid.tointeger())
  }
}


let function on_state_update(results) {
  foreach (state in results) {
    force_update_state_for_uid(state?.uid)
  }
}


let function add_user(uid) {
  if (!is_platform_xbox)
    return
  // no need to track self
  if (uid == ::my_user_id_str)
    return

  requestedIds[uid] <- true
  reqPlayerExternalIDsByUserId(uid, { showProgressBox = false }, null, true)
}


let function on_external_ids_update(params) {
  log("requestedIds:")
  debugTableData(requestedIds)
  log("params:")
  debugTableData(params)

  let reqUid = params?.request?.uid
  if (!(reqUid in requestedIds))
    return

  delete requestedIds[reqUid]
  let xuid = params?.externalIds?.xboxId
  let isFriend = ::isPlayerInFriendsGroup(reqUid)
  add_voice_chat_member(reqUid, xuid, isFriend)
}


let function remove_user(uid) {
  if (!is_platform_xbox)
    return
  remove_voice_chat_member(uid)
}


let function on_contacts_update() {
  if (!is_platform_xbox)
    return

  foreach (uid, _ in voiceChatMembers) {
    let isFriend = ::isPlayerInFriendsGroup(uid)
    update_voice_chat_member_friendship(uid, isFriend)
  }
}


let function on_contacts_group_update(params) {
  if (params?.groupName == EPL_BLOCKLIST) {
    foreach (uid, _ in voiceChatMembers) {
      force_update_state_for_uid(uid)
    }
  }
}


add_event_listener("ContactsUpdated", @(_) on_contacts_update())
add_event_listener("ContactsGroupUpdate", @(p) on_contacts_group_update(p))
add_event_listener("UpdateExternalsIDs", @(p) on_external_ids_update(p))
subscribe_to_state_update(on_state_update)


return {
  add_user
  remove_user
  is_muted
}