from "%scripts/dagui_library.nut" import *

let { format } = require("string")
let { matchingRpcSubscribe } = require("%scripts/matching/api.nut")
let { isInMenu } = require("%scripts/clientState/clientStates.nut")
let { isLoggedIn } = require("%appGlobals/login/loginState.nut")
let { roomState, cleanupRoomState, isNotifyForCurrentRoom, connectToHost,
  mergeAttribs, updateMemberAttributes, addRoomMember, removeRoomMember
} = require("%scripts/matching/serviceNotifications/mroomsState.nut")
let { onSettingsChanged, onMemberInfoUpdate, onMemberJoin
} = require("%scripts/matchingRooms/sessionLobbyManager.nut")
let { joinSessionRoom, onMemberLeave } = require("%scripts/matchingRooms/sessionLobbyActions.nut")
let { addSessionRoomInvite } = require("%scripts/invites/invites.nut")


function notify_room_invite(params) {
  log("notify_room_invite")
  

  if (!isInMenu.get() && isLoggedIn.get()) {
    log("Invite rejected: player is already in flight or in loading level or in unloading level");
    return false;
  }

  let senderId = ("senderId" in params) ? params.senderId : null
  let password = getTblValue("password", params, null)
  if (!senderId) 
    joinSessionRoom(params.roomId, senderId, password)
  else
    addSessionRoomInvite(params.roomId, senderId.tostring(), params.senderName, password)
  return true
}

function notify_room_member_joined(params) {
  log("notify_room_member_joined")
  
  onMemberJoin(params)
}

function notify_room_member_leaved(params) {
  log("notify_room_member_leaved")
  onMemberLeave(params)
}

function notify_room_member_kicked(params) {
  log("notify_room_member_kicked")
  onMemberLeave(params, true)
}

function notify_room_member_attribs_changed(params) {
  log("notify_room_member_attribs_changed")
  onMemberInfoUpdate(params)
}

function notify_room_attribs_changed(params) {
  log("notify_room_attribs_changed")
  

  onSettingsChanged(params)
}


function onRoomInvite(notify, sendResp) {
  local inviteData = notify.invite_data
  if (type(inviteData) != "table")
    inviteData = {}
  inviteData.roomId <- notify.roomId

  if (notify_room_invite(inviteData))
    sendResp({ accept = true })
  else
    sendResp({ accept = false })
}

function onRoomMemberJoined(member) {
  if (!isNotifyForCurrentRoom(member))
    return

  log(format("%s (%s) joined to room", member.name, member.userId.tostring()))
  addRoomMember(member)

  notify_room_member_joined(member)
}

function onRoomMemberLeft(member) {
  if (!isNotifyForCurrentRoom(member))
    return

  log(format("%s (%s) left from room", member.name, member.userId.tostring()))
  removeRoomMember(member.userId)
  notify_room_member_leaved(member)
}

function onRoomMemberKicked(member) {
  if (!isNotifyForCurrentRoom(member))
    return

  log(format("%s (%s) kicked from room", member.name, member.userId.tostring()))
  removeRoomMember(member.userId)
  notify_room_member_kicked(member)
}

function onRoomAttrChanged(notify) {
  if (!isNotifyForCurrentRoom(notify))
    return

  mergeAttribs(notify, roomState.room)
  notify_room_attribs_changed(notify)
}

function onRoomMemberAttrChanged(notify) {
  if (!isNotifyForCurrentRoom(notify))
    return

  updateMemberAttributes(notify)
  notify_room_member_attribs_changed(notify)
}

function onRoomDestroyed(notify) {
  if (!isNotifyForCurrentRoom(notify))
    return
  cleanupRoomState()
}

function onHostNotify(notify) {
  debugTableData(notify)
  if (!isNotifyForCurrentRoom(notify))
    return

  if (notify.hostId != roomState.hostId) {
    log("warning: got host notify from host that is not in current room")
    return
  }

  if (notify.roomId != roomState.roomId) {
    log("warning: got host notify for wrong room")
    return
  }

  if (notify.message == "connect-allowed") {
    roomState.isConnectAllowed = true
    connectToHost()
  }
}

matchingRpcSubscribe("*.on_room_invite", onRoomInvite)
matchingRpcSubscribe("mrooms.on_host_notify", onHostNotify)
matchingRpcSubscribe("mrooms.on_room_member_joined", onRoomMemberJoined)
matchingRpcSubscribe("mrooms.on_room_member_leaved", onRoomMemberLeft)
matchingRpcSubscribe("mrooms.on_room_attributes_changed", onRoomAttrChanged)
matchingRpcSubscribe("mrooms.on_room_member_attributes_changed", onRoomMemberAttrChanged)
matchingRpcSubscribe("mrooms.on_room_destroyed", onRoomDestroyed)
matchingRpcSubscribe("mrooms.on_room_member_kicked", onRoomMemberKicked)
