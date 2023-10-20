from "%scripts/dagui_library.nut" import *
let { hardPersistWatched } = require("%sqstd/globalState.nut")
let lobbyStates = require("%scripts/matchingRooms/lobbyStates.nut")

let sessionLobbyStatus = hardPersistWatched("sessionLobby.status", lobbyStates.NOT_IN_ROOM)
let isInSessionLobbyEventRoom = hardPersistWatched("sessionLobby.isInEventRoom", false)
let isMeSessionLobbyRoomOwner = hardPersistWatched("sessionLobby.isMeRoomOwner", false)
let isRoomInSession = hardPersistWatched("sessionLobby.isRoomInSession", false)

let notInJoiningGameStatuses = [
  lobbyStates.NOT_IN_ROOM
  lobbyStates.IN_LOBBY
  lobbyStates.IN_SESSION
  lobbyStates.IN_DEBRIEFING
]

let notInRoomStatuses = [
  lobbyStates.NOT_IN_ROOM
  lobbyStates.WAIT_FOR_QUEUE_ROOM
  lobbyStates.CREATING_ROOM
  lobbyStates.JOINING_ROOM
]

return {
  sessionLobbyStatus
  isInSessionLobbyEventRoom
  isMeSessionLobbyRoomOwner
  isRoomInSession
  isInJoiningGame = Computed(@() !notInJoiningGameStatuses.contains(sessionLobbyStatus.get()))
  isInSessionRoom = Computed(@() !notInRoomStatuses.contains(sessionLobbyStatus.get()))
  isWaitForQueueRoom = Computed(@() sessionLobbyStatus.get() == lobbyStates.WAIT_FOR_QUEUE_ROOM)
}