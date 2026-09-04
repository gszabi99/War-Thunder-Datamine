from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent
from "string" import format
from "%scripts/dagui_natives.nut" import gchat_raw_command, gchat_escape_target
from "%scripts/dagui_library.nut" import *

let { g_chat_room_type } = require("%scripts/chat/chatRoomType.nut")
let { chatRooms, isRoomJoined } = require("%scripts/chat/chatStorage.nut")
let { systemMessage, checkChatConnected } = require("%scripts/chat/chatHelper.nut")
let { userName } = require("%scripts/user/profileStates.nut")

local _roomJoinedIdx = 0

function isRoomSquad(roomId) {
  return g_chat_room_type.SQUAD.checkRoomId(roomId)
}

function isRoomClan(roomId) {
  return g_chat_room_type.CLAN.checkRoomId(roomId)
}

function isNotUsersClanRoom(roomId) {
  if (!isRoomClan(roomId))
    return false
  return g_chat_room_type.CLAN.canBeClosed(roomId)
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

function generateInviteMenu(playerName) {
  let menu = []
  if (userName.get() == playerName)
    return menu
  foreach (room in chatRooms) {
    if (!room.type.canInviteToRoom)
      continue

    if (room.type.havePlayersList) {
      local isMyRoom = false
      local isPlayerInRoom = false
      foreach (member in room.users) {
        if (member.isOwner && member.name == userName.get())
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
      if (member.name == userName.get())
        return member.isOwner
  return false
}

return {
  joinThread
  addRoom
  generateInviteMenu
  isRoomSquad
  isRoomClan
  isNotUsersClanRoom
  isImRoomOwner
}