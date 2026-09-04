import "%sqStdLibs/helpers/u.nut" as u
from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent

let { CHAT_JOIN_ROOM, CHAT_LEAVE_SQUAD_ROOM } = require("%scripts/crossModuleEvents.nut")
let { sendLocalizedMessage } = require("%scripts/chat/localizedMessages.nut")
let { isRoomJoined } = require("%scripts/chat/chatStorage.nut")



const SQUAD_ROOM_PREFIX = "#_msquad_"

let mkSquadRoomId = @(squadRoomName) u.isEmpty(squadRoomName) ? null
  : $"{SQUAD_ROOM_PREFIX}{squadRoomName}"

function isSquadRoomJoined(squadRoomName) {
  let id = mkSquadRoomId(squadRoomName)
  return id != null && isRoomJoined(id)
}

function joinSquadRoom(squadRoomName, password, onJoinFunc) {
  let id = mkSquadRoomId(squadRoomName)
  if (id == null || u.isEmpty(password))
    return
  broadcastEvent(CHAT_JOIN_ROOM, { id, password, onJoinFunc })
}

let leaveSquadRoom = @() broadcastEvent(CHAT_LEAVE_SQUAD_ROOM)

function sendLocalizedMessageToSquadRoom(squadRoomName, langConfig) {
  let id = mkSquadRoomId(squadRoomName)
  if (id != null)
    sendLocalizedMessage(id, langConfig)
}

return {
  SQUAD_ROOM_PREFIX
  mkSquadRoomId
  isSquadRoomJoined
  joinSquadRoom
  leaveSquadRoom
  sendLocalizedMessageToSquadRoom
}
