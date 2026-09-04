import "%sqStdLibs/helpers/u.nut" as u
from "%scripts/dagui_library.nut" import *
from "%scripts/utils_sa.nut" import is_myself_anyof_moderators

let rooms = persist("rooms", @() [])
let chatThreadsInfo = persist("chatThreadsInfo", @() {})

const MAX_ROOM_MSGS = 50
const MAX_ROOM_MSGS_FOR_MODERATOR = 250

function getMaxRoomMsgAmount() {
  return is_myself_anyof_moderators() ? MAX_ROOM_MSGS_FOR_MODERATOR : MAX_ROOM_MSGS
}

function getThreadInfo(roomId) {
  return chatThreadsInfo?[roomId]
}

function getRoomById(id) {
  return u.search(rooms, function (room) { return room.id == id })
}

function isRoomJoined(roomId) {
  let room = getRoomById(roomId)
  return room != null && room.joined
}

function canCreateThreads() {
  
  
  return is_myself_anyof_moderators() || hasFeature("ChatThreadCreate")
}


return {
  chatRooms = rooms
  chatThreadsInfo
  getMaxRoomMsgAmount
  getThreadInfo
  getRoomById
  isRoomJoined
  MAX_ROOM_MSGS
  MAX_ROOM_MSGS_FOR_MODERATOR
  canCreateThreads
}