from "%scripts/dagui_library.nut" import *
from "%scripts/teamsConsts.nut" import Team

let { INVALID_ROOM_ID } = require("matching.errors")
let { isInteger } = require("%sqStdLibs/helpers/u.nut")
let { hardPersistWatched } = require("%sqstd/globalState.nut")
let lobbyStates = require("%scripts/matchingRooms/lobbyStates.nut")
let { requestUsersInfo } = require("%scripts/user/usersInfoManager.nut")

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

let isInSessionRoom = Computed(@() !notInRoomStatuses.contains(sessionLobbyStatus.get()))

let SessionLobbyState =  persist("SessionLobbyState", @() {
  roomId = INVALID_ROOM_ID
  settings = {
    connect_on_join = true
    hidden = false
    hasPassword = false
  }
  uploadedMissionId = ""
  isRoomByQueue = false
  roomUpdated = false
  password = ""
  members = []
  memberHostId = -1

  
  spectator = false
  isReady = false
  isInLobbySession = false 
  team = Team.Any
  countryData = null
  myState = PLAYER_IN_LOBBY_NOT_READY
  isSpectatorSelectLocked = false
  crsSetTeamTo = Team.none
  curEdiff = -1
  _syncedMyInfo = null
  needJoinSessionAfterMyInfoApply = false
  isLeavingLobbySession = false

  playersInfo = {}

  isReadyInSetStateRoom = null 
})

local playersInfoByNames = {}

let getSessionLobbyTeam = @() SessionLobbyState.team
let getSessionLobbyRoomId = @() SessionLobbyState.roomId
let getSessionLobbyIsSpectator =  @() SessionLobbyState.spectator
let getSessionLobbyIsReady =  @() SessionLobbyState.isReady
let getSessionLobbyPassword = @() SessionLobbyState.password
let getIsInLobbySession = @() SessionLobbyState.isInLobbySession
let getSessionLobbyMembers = @() SessionLobbyState.members
let getSessionLobbyMyState = @() SessionLobbyState.myState
let getIsSpectatorSelectLocked = @() SessionLobbyState.isSpectatorSelectLocked

function preloadUsersInfoForTooltips() {
  let usersIds = SessionLobbyState.playersInfo.keys()
    .map(@(id) id.tostring())
  requestUsersInfo(usersIds)
}

function updateSessionLobbyPlayersInfo() {
  
  if ("players_info" in SessionLobbyState.settings) {
    SessionLobbyState.playersInfo.clear()
    playersInfoByNames.clear()
    foreach (pinfo in SessionLobbyState.settings.players_info) {
      SessionLobbyState.playersInfo[pinfo.id] <- pinfo
      playersInfoByNames[pinfo.name] <- pinfo
    }
    preloadUsersInfoForTooltips()
    return
  }

  
  foreach (k, pinfo in SessionLobbyState.settings) {
    if (k.indexof("pinfo_") != 0)
      continue
    let uid = k.slice(6).tointeger()
    if (pinfo == null || pinfo.len() == 0) {
      SessionLobbyState.playersInfo?.$rawdelete(uid)
    }
    else {
      SessionLobbyState.playersInfo[uid] <- pinfo
      playersInfoByNames[pinfo.name] <- pinfo
    }
  }
  preloadUsersInfoForTooltips()
}

function resetSessionLobbyPlayersInfo() {
  SessionLobbyState.playersInfo.clear()
  playersInfoByNames.clear()
}

let getSessionLobbyPlayerInfoByName = @(name) playersInfoByNames?[name]

function hasSessionInLobby() {
  return isInSessionLobbyEventRoom.get()
}

function canJoinSession() {
  if (hasSessionInLobby())
    return !SessionLobbyState.isLeavingLobbySession
  return isRoomInSession.get()
}

function isUserCanChangeReadyInLobby() {
  return !hasSessionInLobby()
}

function canChangeSessionLobbySettings() {
  return !isInSessionLobbyEventRoom.get() && isMeSessionLobbyRoomOwner.get()
}

function canStartLobbySession() {
  return !isInSessionLobbyEventRoom.get() && isMeSessionLobbyRoomOwner.get()
}

function canChangeCrewUnits() {
  return !isInSessionLobbyEventRoom.get() || !isRoomInSession.get()
}

function canChangeCountry() {
  return !isInSessionRoom.get() || !isInSessionLobbyEventRoom.get()
}

function isInvalidCrewsAllowed() {
  return !isInSessionRoom.get() || !isInSessionLobbyEventRoom.get()
}


function getRoomMembers(room = null) {
  if (!room)
    return SessionLobbyState.members
  return room?.members ?? []
}

function isPlayerInMyRoom(uid) {
  let roomMembers = getRoomMembers()
  foreach (member in roomMembers)
    if (member.userId == uid.tointeger())
      return true

  return false
}

function getMemberByName(name, room = null) {
  if (name == "")
    return null
  foreach (_key, member in getRoomMembers(room))
    if (member.name == name)
      return member
  return null
}

function getRoomMembersCnt(room) {
  return room?.membersCnt ?? 0
}

function getRoomSize(room) {
  return room?.public.players ?? (room?.size ?? 0)
}

function getRoomCreatorUid(room) {
  return room?.public.creator
}

function isMemberHost(m) {
  return m.memberId == SessionLobbyState.memberHostId || (m?.public.host ?? false)
}

function isMemberSpectator(m) {
  return m?.public.spectator ?? false
}

function getMembersCount(room = null) {
  local res = 0
  foreach (m in getRoomMembers(room))
    if (!isMemberHost(m))
      res++
  return res
}

function getSessionLobbyCurRoomEdiff() {
  return SessionLobbyState.curEdiff
}

function getSessionLobbyMissionParam(name, defValue = "") {
  if (("mission" in SessionLobbyState.settings) && (name in SessionLobbyState.settings.mission))
    return SessionLobbyState.settings.mission[name]
  return defValue
}

function getSessionLobbyPublicParam(name, defValue = "") {
  if (name in SessionLobbyState.settings)
    return SessionLobbyState.settings[name]
  return defValue
}

function getSessionLobbyMissionParams() {
  if (!isInSessionRoom.get())
    return null
  return ("mission" in SessionLobbyState.settings) ? SessionLobbyState.settings.mission : null
}

function getSessionLobbyOperationId() {
  if (!isInSessionRoom.get())
    return -1
  return (getSessionLobbyMissionParams()?.customRules?.operationId ?? -1).tointeger()
}

function getSessionLobbyWwBattleId() {
  if (!isInSessionRoom.get())
    return ""
  return (getSessionLobbyMissionParams()?.customRules?.battleId ?? "")
}

function getSessionInfo() {
  return SessionLobbyState.settings
}

function isSessionLobbyCoop() {
  return SessionLobbyState.settings?.coop ?? false
}

function getSessionLobbyPublicData(room = null) {
  return room ? (room?.public ?? room) : SessionLobbyState.settings
}

function getSessionLobbyMissionData(room = null) {
  return getSessionLobbyPublicData(room)?.mission
}

function getSessionLobbyGameMode(room = null) {
  return getSessionLobbyMissionData(room)?._gameMode ?? GM_DOMINATION
}

function canInviteIntoSession() {
  return isInSessionRoom.get() && getSessionLobbyGameMode() == GM_SKIRMISH
}

function isMpSquadChatAllowed() {
  return getSessionLobbyGameMode() != GM_SKIRMISH
}

function getSessionLobbyGameType(room = null) {
  let res = getSessionLobbyMissionData(room)?._gameType ?? 0
  return isInteger(res) ? res : 0
}

function getSessionLobbyMGameModeId(room = null) { 
  return getSessionLobbyPublicData(room)?.game_mode_id
}

function getSessionLobbyClusterName(room = null) {
  return room?.cluster ?? getSessionLobbyPublicData(room)?.cluster ?? ""
}

function getSessionLobbyMaxRespawns(room = null) {
  return getSessionLobbyMissionData(room)?.maxRespawns ?? 0
}

function getRoomSessionStartTime(room = null) {
  return getSessionLobbyPublicData(room)?.matchStartTime ?? 0
}

function isUserMission(v_settings = null) {
  return (v_settings ?? SessionLobbyState.settings)?.userMissionName != null
}

function getMissionUrl(room = null) {
  return getSessionLobbyPublicData(room)?.missionURL ?? ""
}

function isUrlMissionByRoom(room = null) {
  return getMissionUrl(room) != ""
}

function getSessionLobbyChatRoomPassword() {
  return getSessionLobbyPublicParam("chatPassword", "")
}

function isSessionStartedInRoom(room = null) {
  return getSessionLobbyPublicData(room)?.hasSession ?? false
}

function getSessionLobbyMaxMembersCount(room = null) {
  if (room)
    return getRoomSize(room)
  return SessionLobbyState.settings?.players ?? 0
}

function getSessionLobbyPlayerInfoByUid(uid) {
  return SessionLobbyState.playersInfo?[uid.tointeger()]
}

function getSessionLobbyPlayersInfo() {
  return SessionLobbyState.playersInfo
}

function getExternalSessionId() {
  return SessionLobbyState.settings?.externalSessionId
}

return {
  sessionLobbyStatus
  isInSessionLobbyEventRoom
  isMeSessionLobbyRoomOwner
  isRoomInSession
  isInJoiningGame = Computed(@() !notInJoiningGameStatuses.contains(sessionLobbyStatus.get()))
  isInSessionRoom
  isWaitForQueueRoom = Computed(@() sessionLobbyStatus.get() == lobbyStates.WAIT_FOR_QUEUE_ROOM)
  SessionLobbyState
  getSessionLobbyTeam
  getSessionLobbyRoomId
  getSessionLobbyIsSpectator
  getSessionLobbyIsReady
  getSessionLobbyPassword
  getIsInLobbySession
  getSessionLobbyMembers
  getSessionLobbyMyState
  getIsSpectatorSelectLocked
  updateSessionLobbyPlayersInfo
  resetSessionLobbyPlayersInfo
  hasSessionInLobby
  canJoinSession
  isUserCanChangeReadyInLobby
  canChangeSessionLobbySettings
  canStartLobbySession
  canChangeCrewUnits
  canChangeCountry
  canInviteIntoSession
  isInvalidCrewsAllowed
  getRoomMembers
  isPlayerInMyRoom
  getMemberByName
  getRoomMembersCnt
  getRoomSize
  getRoomCreatorUid
  isMemberHost
  isMemberSpectator
  getMembersCount
  getSessionLobbyCurRoomEdiff
  getSessionLobbyMissionParam
  getSessionLobbyPublicParam
  getSessionLobbyMissionParams
  getSessionLobbyOperationId
  getSessionLobbyWwBattleId
  getSessionInfo
  isSessionLobbyCoop
  getSessionLobbyPublicData
  getSessionLobbyMissionData
  getSessionLobbyGameMode
  isMpSquadChatAllowed
  getSessionLobbyGameType
  getSessionLobbyMGameModeId
  getSessionLobbyClusterName
  getSessionLobbyMaxRespawns
  getRoomSessionStartTime
  isUserMission
  getMissionUrl
  isUrlMissionByRoom
  getSessionLobbyChatRoomPassword
  isSessionStartedInRoom
  getSessionLobbyMaxMembersCount
  getSessionLobbyPlayerInfoByName
  getSessionLobbyPlayerInfoByUid
  getSessionLobbyPlayersInfo
  getExternalSessionId
}