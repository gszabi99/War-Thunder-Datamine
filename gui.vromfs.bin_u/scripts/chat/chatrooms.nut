from "%scripts/dagui_natives.nut" import gchat_raw_command, gchat_escape_target
from "%scripts/dagui_library.nut" import *

let { g_chat_room_type } = require("%scripts/chat/chatRoomType.nut")
let { chatRooms } = require("%scripts/chat/chatStorage.nut")
let { systemMessage, checkChatConnected } = require("%scripts/chat/chatHelper.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { userName } = require("%scripts/user/profileStates.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { format } = require("string")

local _roomJoinedIdx = 0

function isRoomSquad(roomId) {
  return g_chat_room_type.SQUAD.checkRoomId(roomId)
}

function isRoomClan(roomId) {
  return g_chat_room_type.CLAN.checkRoomId(roomId)
}

function getRoomById(id) {
  return u.search(chatRooms, function (room) { return room.id == id })
}

function isRoomJoined(roomId) {
  let room = getRoomById(roomId)
  return room != null && room.joined
}

function addRoom(room) {
  room.roomJoinedIdx = _roomJoinedIdx++
  chatRooms.append(room)

  chatRooms.sort(function(a, b) {
    if (a.type.tabOrder != b.type.tabOrder)
      return a.type.tabOrder < b.type.tabOrder ? -1 : 1
    if (a.roomJoinedIdx != b.roomJoinedIdx)
      return a.roomJoinedIdx < b.roomJoinedIdx ? -1 : 1
    return 0
  })
}

function joinThread(roomId) {
  if (!checkChatConnected())
    return
  if (!g_chat_room_type.THREAD.checkRoomId(roomId))
    return systemMessage(loc(this.CHAT_ERROR_NO_CHANNEL))

  if (!isRoomJoined(roomId))
    gchat_raw_command($"xtjoin {roomId}")
  else
    broadcastEvent("ChatSwitchCurRoom", { roomId })
}

function isSquadRoomJoined() {
  let roomId = g_chat_room_type.getMySquadRoomId()
  if (roomId == null)
    return false

  return isRoomJoined(roomId)
}

function openChatRoom(roomId, ownerHandler = null) {
  if (!::openChatScene(ownerHandler))
    return

  broadcastEvent("ChatSwitchCurRoom", { roomId })
}

function generateInviteMenu(playerName) {
  let menu = []
  if (userName.value == playerName)
    return menu
  foreach (room in chatRooms) {
    if (!room.type.canInviteToRoom)
      continue

    if (room.type.havePlayersList) {
      local isMyRoom = false
      local isPlayerInRoom = false
      foreach (member in room.users) {
        if (member.isOwner && member.name == userName.value)
          isMyRoom = true
        if (member.name == playerName)
          isPlayerInRoom = true
      }
      if (isPlayerInRoom || (!isMyRoom && room.type.onlyOwnerCanInvite))
        continue
    }

    let roomId = room.id
    menu.append({
      text = room.getRoomName()
      show = true
      action = function () {
          gchat_raw_command(format("INVITE %s %s",
            gchat_escape_target(playerName),
            gchat_escape_target(roomId)))
          }
    })
  }
  return menu
}

function isImRoomOwner(roomData) {
  if (roomData)
    foreach (member in roomData.users)
      if (member.name == userName.value)
        return member.isOwner
  return false
}

function openWWOperationChatRoomById(operationId) {
  foreach (room in chatRooms) {
    if (room.type.typeName != "WW_OPERATION")
      continue
    if (room.type.getOperationId(room.id) != operationId)
      continue

    openChatRoom(room.id)
    return
  }
}


return {
  joinThread
  addRoom
  isRoomJoined
  getRoomById
  isSquadRoomJoined
  generateInviteMenu
  isRoomSquad
  isRoomClan
  isImRoomOwner
  openChatRoom
  openWWOperationChatRoomById
}