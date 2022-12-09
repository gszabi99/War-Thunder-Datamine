let voice = require("xbox.voice")
let {subscribe} = require("eventbus")
let logX = require("%sqstd/log.nut")().with_prefix("[XBOX_VOICE] ")

let voiceChatMembers = persist("voiceChatMembers", @() {})


let function _add_voice_chat_member(uid, is_friend) {
  voiceChatMembers[uid] <- { is_friend = is_friend, is_muted = false }
}


let function _remove_voice_chat_member(uid) {
  if (uid in voiceChatMembers) {
    delete voiceChatMembers[uid]
  }
}


let function _update_voice_chat_members_mute(results) {
  foreach (state in results) {
    let uid = state?.uid.tostring()
    let muted = state.is_muted ?? false
    if (uid in voiceChatMembers) {
      voiceChatMembers[uid].is_muted = muted
    }
  }
}


let function subscribe_to_state_update(callback) {
  subscribe(voice.status_update_event_name, function(result) {
    let results = result.results ?? []
    _update_voice_chat_members_mute(results)
    callback?(results)
  })
}


let function add_voice_chat_member(uid, xuid, is_friend) {
  logX($"Add voice chat member. Uid: {uid}, XUID: {xuid}, isFriend: {is_friend}")
  let uidstr = uid.tostring()
  _add_voice_chat_member(uidstr, is_friend)
  if (xuid != 0 && xuid != null)
    voice.add_xbox_player(uidstr, xuid.tointeger(), is_friend)
  else
    voice.add_external_player(uidstr, is_friend)
}


let function remove_voice_chat_member(uid) {
  logX($"Remove voice chat member. {uid}")
  let uidstr = uid.tostring()
  _remove_voice_chat_member(uidstr)
  voice.remove_player(uidstr)
}


let function update_voice_chat_member_friendship(uid, is_friend) {
  let uidstr = uid.tostring()
  let updated = voiceChatMembers[uidstr].is_friend != is_friend
  if (updated) {
    voiceChatMembers[uidstr].is_friend = is_friend
    voice.set_ingame_friend_status(uidstr, is_friend)
  }
}


let function is_voice_chat_member_muted(uid) {
  let uidstr = uid.tostring()
  if (uidstr in voiceChatMembers) {
    return voiceChatMembers[uidstr].is_muted
  }
  return false
}


return {
  subscribe_to_state_update

  add_voice_chat_member
  remove_voice_chat_member
  update_voice_chat_member_friendship
  is_voice_chat_member_muted

  voiceChatMembers
}