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
  return getTblValue(roomId, chatThreadsInfo)
}

function canCreateThreads() {
  // it can be useful in China to disallow creating threads for ordinary users
  // only moderators allowed to do so
  return is_myself_anyof_moderators() || hasFeature("ChatThreadCreate")
}


return {
  chatRooms = rooms
  chatThreadsInfo
  getMaxRoomMsgAmount
  getThreadInfo
  MAX_ROOM_MSGS
  MAX_ROOM_MSGS_FOR_MODERATOR
  canCreateThreads
}