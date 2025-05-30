from "%scripts/dagui_natives.nut" import send_error_log, script_net_assert, connect_to_host_list
from "%scripts/dagui_library.nut" import *

let { INVALID_ROOM_ID } = require("matching.errors")
let { format } = require("string")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { isMyUserId } = require("%scripts/user/profileStates.nut")

let roomState = persist("roomState", @() {
  hostId = null 
  roomId = INVALID_ROOM_ID
  room = null
  roomMembers = []
  isConnectAllowed = false
  roomOps = {}
  isHostReady = false
  isSelfReady = false
  isLeaving = false
})

function cleanupRoomState() {
  if (roomState.room == null)
    return

  roomState.hostId = null
  roomState.roomId = INVALID_ROOM_ID
  roomState.room = null
  roomState.roomMembers = []
  roomState.roomOps = {}
  roomState.isConnectAllowed = false
  roomState.isHostReady = false
  roomState.isSelfReady = false
  roomState.isLeaving = false

  log("notify_room_destroyed")
  broadcastEvent("SessionRoomLeaved")
}

let hasSession = @() roomState.hostId != null
let isHostInRoom = @() hasSession()

function getRoomMember(userId) {
  foreach (_idx, member in roomState.roomMembers)
    if (member.userId == userId)
      return member
  return null
}

function getMyRoomMember() {
  foreach (_idx, member in roomState.roomMembers)
    if (isMyUserId(member.userId))
      return member
  return null
}

function connectToHost() {
  log("connectToHost")
  if (!hasSession())
    return

  let host = getRoomMember(roomState.hostId)
  if (!host) {
    log("connectToHost failed: host is not in the room")
    return
  }

  let me = getMyRoomMember()
  if (!me) {
    log("connectToHost failed: player is not in the room")
    return
  }

  let hostPub = host.public
  let roomPub = roomState.room.public

  if ("room_key" not in roomPub) {
    let mePub = toString(me?.public, 3)          
    let mePrivate = toString(me?.private, 3)     
    let meStr = toString(me, 3)                  
    let roomStr = toString(roomPub, 3)           
    let roomMission = toString(roomPub?.mission) 
    script_net_assert("missing room_key in room")

    send_error_log("missing room_key in room", false, "log")
    return
  }

  local serverUrls = [];
  if ("serverURLs" in hostPub)
    serverUrls = hostPub.serverURLs
  else if ("ip" in hostPub && "port" in hostPub) {
    let ip = hostPub.ip
    let ipStr = format("%u.%u.%u.%u:%d", ip & 255, (ip >> 8) & 255, (ip >> 16) & 255, ip >> 24, hostPub.port)
    serverUrls.append(ipStr)
  }

  connect_to_host_list(serverUrls, roomPub.room_key, me.private.auth_key,
    getTblValue("sessionId", roomPub, roomState.roomId))
}

function isNotifyForCurrentRoom(notify) {
  
  return !roomState.isLeaving
    && roomState.roomId != INVALID_ROOM_ID
    && roomState.roomId == notify.roomId
}

function onHostConnectReady() {
  roomState.isHostReady = true
  if (roomState.isSelfReady)
    connectToHost()
}

function onSelfReady() {
  roomState.isSelfReady = true
  if (roomState.isHostReady)
    connectToHost()
}

function mergeAttribs(attrFrom, attrTo) {
  let updateAttribs = function(updData, attribs) {
    foreach (key, value in updData) {
      if (value == null && (key in attribs))
        attribs.$rawdelete(key)
      else
        attribs[key] <- value
    }
  }

  let pub = getTblValue("public", attrFrom)
  let priv = getTblValue("private", attrFrom)

  if (type(priv) == "table") {
    if ("private" in attrTo)
      updateAttribs(priv, attrTo.private)
    else
      attrTo.private <- priv
  }
  if (type(pub) == "table") {
    if ("public" in attrTo)
      updateAttribs(pub, attrTo.public)
    else
      attrTo.public <- pub
  }
}

function removeRoomMember(userId) {
  foreach (idx, member in roomState.roomMembers) {
    if (member.userId == userId) {
      roomState.roomMembers.remove(idx)
      break
    }
  }

  if (userId == roomState.hostId) {
    roomState.hostId = null
    roomState.isConnectAllowed = false
    roomState.isHostReady = false
  }

  if (userId in roomState.roomOps)
    roomState.roomOps.$rawdelete(userId)

  if (isMyUserId(userId))
    cleanupRoomState()
}

function updateMemberAttributes(member, curMember = null) {
  if (curMember == null)
    curMember = getRoomMember(member.userId)
  if (curMember == null) {
    log(format("failed to update member attributes. member not found in room %s",
      member.userId.tostring()))
    return
  }
  mergeAttribs(member, curMember)

  if (member.userId == roomState.hostId) {
    if (member?.public.connect_ready ?? false)
      onHostConnectReady()
  }
  else if (isMyUserId(member.userId)) {
    let readyStatus = member?.public.ready
    if (readyStatus == true)
      onSelfReady()
    else if (readyStatus == false)
      roomState.isSelfReady = false
  }
}

function addRoomMember(member) {
  if (getTblValue("operator", member.public))
    roomState.roomOps[member.userId] <- true

  if (getTblValue("host", member.public)) {
    log(format("found host %s (%s)", member.name, member.userId.tostring()))
    roomState.hostId = member.userId
  }

  let curMember = getRoomMember(member.userId)
  if (curMember == null)
    roomState.roomMembers.append(member)
  updateMemberAttributes(member, curMember)
}

registerForNativeCall("get_current_room", function get_current_room() {
  return roomState.roomId
})

registerForNativeCall("is_player_room_operator", function is_player_room_operator(user_id) {
  return (user_id in roomState.roomOps)
})

return {
  roomState
  cleanupRoomState
  isHostInRoom
  connectToHost
  isNotifyForCurrentRoom
  onSelfReady
  mergeAttribs
  updateMemberAttributes
  addRoomMember
  removeRoomMember
}
