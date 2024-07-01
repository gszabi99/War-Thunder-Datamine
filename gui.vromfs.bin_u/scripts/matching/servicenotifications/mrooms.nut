from "%scripts/dagui_natives.nut" import send_error_log, script_net_assert, get_dyncampaign_b64blk, connect_to_host_list
from "%scripts/dagui_library.nut" import *

let { INVALID_ROOM_ID } = require("matching.errors")
let crossplayModule = require("%scripts/social/crossplay.nut")
let { isPlatformSony, isPlatformXboxOne } = require("%scripts/clientState/platform.nut")
let { format } = require("string")
let { checkMatchingError, matchingApiFunc, matchingRpcSubscribe } = require("%scripts/matching/api.nut")
let { userIdStr, userIdInt64 } = require("%scripts/user/profileStates.nut")
let { isInMenu } = require("%scripts/baseGuiHandlerManagerWT.nut")

// rooms notifications
function notify_room_invite(params) {
  log("notify_room_invite")
  //debugTableData(params)

  if (!isInMenu() && ::g_login.isLoggedIn()) {
    log("Invite rejected: player is already in flight or in loading level or in unloading level");
    return false;
  }

  let senderId = ("senderId" in params) ? params.senderId : null
  let password = getTblValue("password", params, null)
  if (!senderId) //querry room
    ::SessionLobby.joinRoom(params.roomId, senderId, password)
  else
    ::g_invites.addSessionRoomInvite(params.roomId, senderId.tostring(), params.senderName, password)
  return true
}

function notify_room_destroyed(params) {
  log("notify_room_destroyed")
  //debugTableData(params)

  ::SessionLobby.afterLeaveRoom(params)
}

function notify_room_member_joined(params) {
  log("notify_room_member_joined")
  //debugTableData(params)
  ::SessionLobby.onMemberJoin(params)
}

function notify_room_member_leaved(params) {
  log("notify_room_member_leaved")
  ::SessionLobby.onMemberLeave(params)
}

function notify_room_member_kicked(params) {
  log("notify_room_member_kicked")
  ::SessionLobby.onMemberLeave(params, true)
}

function notify_room_member_attribs_changed(params) {
  log("notify_room_member_attribs_changed")
  ::SessionLobby.onMemberInfoUpdate(params)
}

function notify_room_attribs_changed(params) {
  log("notify_room_attribs_changed")
  //debugTableData(params)

  ::SessionLobby.onSettingsChanged(params)
}

let roomState = persist("roomState", @() {
  hostId = null // user host id
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

  notify_room_destroyed({})
}

let hasSession = @() roomState.hostId != null
let isHostInRoom = @() hasSession()

function isMyUserId(userId) {
  if (type(userId) == "string")
    return userId == userIdStr.value
  return userId == userIdInt64.value
}

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
    let mePub = toString(me?.public, 3)          // warning disable: -declared-never-used
    let mePrivate = toString(me?.private, 3)     // warning disable: -declared-never-used
    let meStr = toString(me, 3)                  // warning disable: -declared-never-used
    let roomStr = toString(roomPub, 3)           // warning disable: -declared-never-used
    let roomMission = toString(roomPub?.mission) // warning disable: -declared-never-used
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
  // ignore all room notifcations after leave has been called
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

// notifications
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

function onRoomJoinCb(resp) {
  cleanupRoomState()

  roomState.room = resp
  roomState.roomId = roomState.room.roomId
  foreach (member in roomState.room.members)
    addRoomMember(member)

  if (getTblValue("connect_on_join", roomState.room.public)) {
    log("room with auto-connect feature")
    roomState.isSelfReady = true
    onSelfReady()
  }
}

function onRoomLeaveCb() {
  cleanupRoomState()
}

matchingRpcSubscribe("*.on_room_invite", onRoomInvite)
matchingRpcSubscribe("mrooms.on_host_notify", onHostNotify)
matchingRpcSubscribe("mrooms.on_room_member_joined", onRoomMemberJoined)
matchingRpcSubscribe("mrooms.on_room_member_leaved", onRoomMemberLeft)
matchingRpcSubscribe("mrooms.on_room_attributes_changed", onRoomAttrChanged)
matchingRpcSubscribe("mrooms.on_room_member_attributes_changed", onRoomMemberAttrChanged)
matchingRpcSubscribe("mrooms.on_room_destroyed", onRoomDestroyed)
matchingRpcSubscribe("mrooms.on_room_member_kicked", onRoomMemberKicked)

// mrooms API

function requestCreateRoom(params, cb) {
  if ((isPlatformXboxOne || isPlatformSony)
      && !crossplayModule.isCrossPlayEnabled()) {
    params["crossplayRestricted"] <- true
  }

  matchingApiFunc("mrooms.create_room",
    function(resp) {
      if (checkMatchingError(resp, false))
        onRoomJoinCb(resp)
      cb(resp)
    },
    params)
}

function requestDestroyRoom(params, cb) {
  matchingApiFunc("mrooms.destroy_room", cb, params)
}

function requestJoinRoom(params, cb) {
  matchingApiFunc("mrooms.join_room",
    function(resp) {
      if (checkMatchingError(resp, false))
        onRoomJoinCb(resp)
      else {
        resp.roomId <- params?.roomId
        resp.password <- params?.password
      }
      cb(resp)
    },
    params)
}

function requestLeaveRoom(params, cb) {
  let oldRoomId = roomState.roomId
  roomState.isLeaving = true

  matchingApiFunc("mrooms.leave_room",
    function(resp) {
      if (roomState.roomId == oldRoomId)
        onRoomLeaveCb()
      cb(resp)
    },
    params)
}

function setMemberAttributes(params, cb) {
  matchingApiFunc("mrooms.set_member_attributes", cb, params)
}

function setRoomAttributes(params, cb) {
  log($"[PSMT] setting room attributes: {params?.public?.psnMatchId}")
  matchingApiFunc("mrooms.set_attributes", cb, params)
}

function kickMember(params, cb) {
  matchingApiFunc("mrooms.kick_from_room", cb, params)
}

function roomStartSession(params, cb) {
  matchingApiFunc("mrooms.start_session", cb, params)
}

function roomSetPassword(params, cb) {
  matchingApiFunc("mrooms.set_password", cb, params)
}

function roomSetReadyState(params, cb) {
  matchingApiFunc("mrooms.set_ready_state", cb, params)
}

function invitePlayerToRoom(params, cb) {
  matchingApiFunc("mrooms.invite_player", cb, params)
}

function fetchRoomsList(params, cb) {
  matchingApiFunc("mrooms.fetch_rooms_digest2",
    function (resp) {
      if (checkMatchingError(resp, false)) {
        foreach (room in getTblValue("digest", resp, [])) {
          let hasPassword = room?.public.hasPassword
          if (hasPassword != null)
            room.hasPassword <- hasPassword
        }
      }
      cb(resp)
    },
    params)
}

function serializeDyncampaign(cb) {
  let priv = {
    dyncamp = {
      data = get_dyncampaign_b64blk()
    }
  }

  matchingApiFunc("mrooms.set_attributes", cb, { private = priv })
}

// funcs called from native code
::get_current_room <- function get_current_room() {
  return roomState.roomId
}

::is_player_room_operator <- function is_player_room_operator(user_id) {
  return (user_id in roomState.roomOps)
}

return {
  isMyUserId
  isHostInRoom
  requestCreateRoom
  requestDestroyRoom
  requestJoinRoom
  requestLeaveRoom
  setMemberAttributes
  setRoomAttributes
  kickMember
  roomStartSession
  roomSetPassword
  roomSetReadyState
  invitePlayerToRoom
  fetchRoomsList
  serializeDyncampaign
}
