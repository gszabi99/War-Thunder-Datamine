let {subscribe, send} = require("eventbus")
let {uid2xbox, friendsUids} = require("%xboxLib/userIds.nut")
let {communicationsPrivilege, voiceWithAnonUser} = require("%xboxLib/crossnetwork.nut")
let {CommunicationState} = require("%xboxLib/impl/crossnetwork.nut")
let {mutedXuids, bannedXuids} = require("%xboxLib/relationships.nut")
let logX = require("%sqstd/log.nut")().with_prefix("[XBOX_VOICE] ")

let eventName = "XBOX_VOICE_CHAT_STATE_CHANGE"
let voiceChatMembers = persist("voiceChatMembers", @() {})


let function subscribe_to_state_change(callback) {
  subscribe(eventName, function(res) {
    callback?(res?.uid, res?.muted)
  })
}


let function notify_state_change(uid, muted) {
  logX($"State changed: UID: {uid} muted: {muted}")
  send(eventName, {uid = uid, muted = muted})
}


let function add_member(uid) {
  let member = {
    uid = uid,
    xuid = uid2xbox?[uid],
    muted = false
  }
  voiceChatMembers[uid] <- member
}


let function remove_member(uid) {
  delete voiceChatMembers[uid]
}


let function set_member_state(uid, muted) {
  local member = voiceChatMembers?[uid]
  if (member) {
    member.muted = muted
  }
}


let function is_muted_by_permissions(is_friend) {
  let communicationsAllowed = communicationsPrivilege.value
  let chatWithFriendsAllowed = (voiceWithAnonUser.value == CommunicationState.FriendsOnly)
    || (voiceWithAnonUser.value == CommunicationState.Allowed)
  let chatWithAllAllowed = voiceWithAnonUser.value == CommunicationState.Allowed
  if (!communicationsAllowed)
    return true
  if (!chatWithAllAllowed && chatWithFriendsAllowed) {
    if (!is_friend)
      return true
  }
  return false
}


let function is_muted_by_lists(xuid) {
  return xuid in mutedXuids.value || xuid in bannedXuids.value
}


let function update() {
  foreach (uid, member in voiceChatMembers) {
    member.xuid = uid2xbox?[uid]
    let foreign = member.xuid == null
    let friend = uid in friendsUids.value
    let mutedByPerms = is_muted_by_permissions(friend)
    let mutedByLists = foreign ? false : is_muted_by_lists(member.xuid)
    member.muted = mutedByLists || mutedByPerms
    logX($"<{uid}> muted by lists: {mutedByLists}, muted by permissions: {mutedByPerms} -> {member.muted}")
  }

  foreach (uid, member in voiceChatMembers) {
    notify_state_change(uid, member.muted)
  }
}


return {
  subscribe_to_state_change

  add_member
  remove_member
  set_member_state

  update
}