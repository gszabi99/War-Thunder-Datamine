import "%scripts/matchingRooms/lobbyStates.nut" as lobbyStates
from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv, DEFAULT_HANDLER, broadcastEvent
from "%sqStdLibs/helpers/u.nut" import search, isEmpty
from "%appGlobals/login/loginState.nut" import isLoggedIn
from "%globalScripts/clientState/initialState.nut" import disableNetwork
from "guiMission" import quit_to_debriefing, interrupt_multiplayer, leave_mp_session
from "penalty" import getPenaltyStatus, BAN
from "dynamicMission" import dynamicMissionPlayed
from "mission" import get_game_mode
from "matching.errors" import INVALID_ROOM_ID, SERVER_ERROR_ROOM_PASSWORD_MISMATCH
from "dagor.workcycle" import deferOnce
from "%globalScripts/externalPlayerListConsts.nut" import *
from "%scripts/dagui_natives.nut" import is_online_available
from "%globalScripts/gameModeNativeConsts.nut" import *
from "%scripts/dagui_library.nut" import *
from "gameplayBinding" import inFlightMenu, isInFlight
from "%scripts/webRPC.nut" import webRpcRegister
from "types" import String

let { g_squad_manager } = require("%scripts/squads/squadManager.nut")
let { events } = require("%scripts/events/eventsManager.nut")
let { isInMenu, isInBattleState } = require("%scripts/clientState/clientStates.nut")
let { SessionLobbyState, isInSessionRoom, isMeSessionLobbyRoomOwner, getRoomCreatorUid, isSessionStartedInRoom, getSessionLobbyMaxMembersCount, getSessionLobbyPlayerInfoByUid, isInSessionLobbyEventRoom, isMemberHost, sessionLobbyStatus } = require("%scripts/matchingRooms/sessionLobbyState.nut")
let { userIdInt64, userName, isMyUserId } = require("%scripts/user/profileStates.nut")
let { matchingApiFunc, checkMatchingError } = require("%scripts/matching/api.nut")
let { requestJoinRoom, serializeDyncampaign, requestCreateRoom } = require("%scripts/matching/serviceNotifications/mroomsApi.nut")
let { leaveSessionRoom, setSessionLobbySettings, switchSessionLobbyStatus, updateMemberHostParams, changeRoomPassword, needCheckReconnect, syncAllSessionLobbyInfo, initMyParamsByMemberInfo, returnStatusToRoom, checkAutoStart, destroyRoom, setLastRound, setRoomInSession, prepareSettings } = require("%scripts/matchingRooms/sessionLobbyManager.nut")
let { needAutoInviteSquadToSessionRoom, getRoomMGameMode, haveLobby, getRoomEvent } = require("%scripts/matchingRooms/sessionLobbyInfo.nut")
let { invitePlayerToSessionRoom, isRoomMemberOperator } = require("%scripts/matchingRooms/sessionLobbyMembersInfo.nut")
let { set_last_session_debug_info } = require("%scripts/matchingRooms/sessionDebugInfo.nut")
let { leaveAllQueuesSilent, notifyQueueLeave } = require("%scripts/queue/queueManager.nut")
let { showMsgboxIfEacInactive } = require("%scripts/penitentiary/antiCheat.nut")
let { showMsgboxIfSoundModsNotAllowed } = require("%scripts/penitentiary/soundMods.nut")
let { checkShowMultiplayerAasWarningMsg } = require("%scripts/user/antiAddictSystem.nut")
let { saveLocalByAccount } = require("%scripts/clientState/localProfileDeprecated.nut")
let { initListLabelsSquad } = require("%scripts/statistics/squadIcon.nut")
let { getContactsGroupUidList } = require("%scripts/contacts/contactsListState.nut")
let openEditBoxDialog = require("%scripts/wndLib/editBoxHandler.nut")
let { getEventEconomicName, isEventWithLobby } = require("%scripts/events/eventInfo.nut")
let { clearMpChatLog } = require("%scripts/chat/mpChatModel.nut")
let { setUserPresence } = require("%scripts/userPresence.nut")
let { updateMyCountryData } = require("%scripts/squads/squadUtils.nut")

local delayedJoinRoomFunc = null
let isReconnectChecking = mkWatched(persist, "isReconnectChecking", false)

function checkSquadAutoInviteToRoom() {
  if (!g_squad_manager.isSquadLeader() || !needAutoInviteSquadToSessionRoom())
    return

  let sMembers = g_squad_manager.getMembers()
  foreach (uid, member in sMembers)
    if (member.online
        && member.isReady
        && !member.isMe()
        && !search(SessionLobbyState.members, @(m) m.userId == uid)) {
      invitePlayerToSessionRoom(uid)
    }
}

function setIngamePresence(roomPublic, roomId) {
  local team = 0
  let myPinfo = getSessionLobbyPlayerInfoByUid(userIdInt64.get())
  if (myPinfo != null)
    team = myPinfo.team

  let inGamePresence = {
    gameModeId = roomPublic?.game_mode_id
    gameQueueId = roomPublic?.game_queue_id
    mission    = roomPublic?.mission
    roomId     = roomId
    team       = team
  }
  setUserPresence({ in_game_ex = inGamePresence })
}

function sendJoinRoomRequest(join_params, _cb = function(...) {}) {
  if (isInSessionRoom.get())
    leaveSessionRoom() 

  leave_mp_session()

  if (!isMeSessionLobbyRoomOwner.get()) {
    setSessionLobbySettings({})
    SessionLobbyState.members = []
  }

  set_last_session_debug_info(
    ("roomId" in join_params) ? ($"room:{join_params.roomId}") :
    ("battleId" in join_params) ? ($"battle:{join_params.battleId}") :
    ""
  )

  switchSessionLobbyStatus(lobbyStates.JOINING_ROOM)
  requestJoinRoom(join_params, @(p) broadcastEvent("JoinedToSessionRoom", p))
}

function joinBattle(battleId) {
  leaveAllQueuesSilent()
  notifyQueueLeave({})
  isMeSessionLobbyRoomOwner.set(false)
  SessionLobbyState.isRoomByQueue = false
  sendJoinRoomRequest({ battleId = battleId })
}

function joinSessionRoom(v_roomId, senderId = "", v_password = null,
                                cb = function(...) {}) { 
  if (SessionLobbyState.roomId == v_roomId && isInSessionRoom.get())
    return

  if (!isLoggedIn.get() || isInSessionRoom.get()) {
    let self = callee()
    delayedJoinRoomFunc =  @() self(v_roomId, senderId, v_password, cb)

    if (isInSessionRoom.get())
      leaveSessionRoom()
    return
  }

  isMeSessionLobbyRoomOwner.set(isMyUserId(senderId))
  SessionLobbyState.isRoomByQueue = senderId == null

  if (SessionLobbyState.isRoomByQueue)
    notifyQueueLeave({})
  else
    leaveAllQueuesSilent()

  if (v_password && v_password.len())
    changeRoomPassword(v_password)

  let joinParams = { roomId = v_roomId }
  if (SessionLobbyState.password != "")
    joinParams.password <- SessionLobbyState.password

  sendJoinRoomRequest(joinParams, cb)
}

function reconnect(roomId, gameModeName) {
  let event = events.getEvent(gameModeName)
  if (!showMsgboxIfEacInactive(event) || !showMsgboxIfSoundModsNotAllowed(event))
    return

  if (event != null) {
    checkShowMultiplayerAasWarningMsg(@() joinSessionRoom(roomId))
    return
  }

  joinSessionRoom(roomId)
}

function onCheckReconnect(response) {
  isReconnectChecking.set(false)

  let roomId = response?.roomId
  let gameModeName = response?.game_mode_name
  if (!roomId || !gameModeName)
    return

  scene_msg_box("backToBattle_dialog", null, loc("msgbox/return_to_battle_session"), [
    ["yes", @() reconnect(roomId, gameModeName)],
    ["no"]], "yes")
}

function isMeBanned() {
  return getPenaltyStatus().status == BAN
}

function checkReconnect() {
  if (disableNetwork || isReconnectChecking.get() || !isLoggedIn.get() || isInBattleState.get() || isMeBanned())
    return

  isReconnectChecking.set(true)
  matchingApiFunc("match.check_reconnect", onCheckReconnect)
}

function afterLeaveRoom() {
  if (delayedJoinRoomFunc != null) {
    deferOnce(delayedJoinRoomFunc)
    delayedJoinRoomFunc = null
  }
  SessionLobbyState.roomId = INVALID_ROOM_ID
  switchSessionLobbyStatus(lobbyStates.NOT_IN_ROOM)

  if (needCheckReconnect.get()) {
    needCheckReconnect.set(false)
    deferOnce(checkReconnect) 
  }
}

function joinSessionRoomWithPassword(joinRoomId, prevPass = "", wasEntered = false) {
  if (joinRoomId == "") {
    assert(false, "SessionLobby Error: try to join room with password with empty room id")
    return
  }

  openEditBoxDialog({
    value = prevPass
    title = loc("mainmenu/password")
    label = wasEntered ? loc("matching/SERVER_ERROR_ROOM_PASSWORD_MISMATCH") : ""
    isPassword = true
    allowEmpty = false
    okFunc = @(pass) joinSessionRoom(joinRoomId, "", pass)
  })
}

function joinSessionLobbyFoundRoom(room) { 
  if (("hasPassword" in room) && room.hasPassword && getRoomCreatorUid(room) != userName.get())
    joinSessionRoomWithPassword(room.roomId)
  else
    joinSessionRoom(room.roomId)
}

function afterRoomJoining(params) {
  if (params.error == SERVER_ERROR_ROOM_PASSWORD_MISMATCH) {
    let joinRoomId = params.roomId 
    let oldPass = params.password
    switchSessionLobbyStatus(lobbyStates.NOT_IN_ROOM)
    joinSessionRoomWithPassword(joinRoomId, oldPass, oldPass != "")
    return
  }

  if (!checkMatchingError(params))
    return switchSessionLobbyStatus(lobbyStates.NOT_IN_ROOM)

  SessionLobbyState.roomId = params.roomId
  SessionLobbyState.roomUpdated = true
  SessionLobbyState.members = (params?.members ?? [])
  initMyParamsByMemberInfo()
  clearMpChatLog()
  updateMyCountryData()

  let public = (params?.public ?? SessionLobbyState.settings)
  if (!isMeSessionLobbyRoomOwner.get() || isEmpty(SessionLobbyState.settings)) {
    setSessionLobbySettings(public)

    let mGameMode = getRoomMGameMode()
    if (mGameMode) {
      setIngamePresence(public, SessionLobbyState.roomId)
      isInSessionLobbyEventRoom.set(isEventWithLobby(mGameMode))
    }
    log($"Joined room: isInSessionLobbyEventRoom {isInSessionLobbyEventRoom.get()}")

    if (SessionLobbyState.isRoomByQueue && !isSessionStartedInRoom())
      SessionLobbyState.isRoomByQueue = false
    if (isInSessionLobbyEventRoom.get() && !SessionLobbyState.isRoomByQueue && haveLobby())
      SessionLobbyState.needJoinSessionAfterMyInfoApply = true
  }

  for (local i = SessionLobbyState.members.len() - 1; i >= 0; i--)
    if (isMemberHost(SessionLobbyState.members[i])) {
      updateMemberHostParams(SessionLobbyState.members[i])
      SessionLobbyState.members.remove(i)
    }
    else if (isMyUserId(SessionLobbyState.members[i].userId))
      isMeSessionLobbyRoomOwner.set(isRoomMemberOperator(SessionLobbyState.members[i]))

  returnStatusToRoom()
  syncAllSessionLobbyInfo()

  checkSquadAutoInviteToRoom()

  let event = getRoomEvent()
  if (event) {
    if (events.isEventVisibleInEventsWindow(event))
      saveLocalByAccount("lastPlayedEvent", {
        eventName = event.name
        economicName = getEventEconomicName(event)
      })

    broadcastEvent("AfterJoinEventRoom", event)
  }

  if (isMeSessionLobbyRoomOwner.get() && get_game_mode() == GM_DYNAMIC && !dynamicMissionPlayed()) {
    serializeDyncampaign(
      function(p) {
        if (checkMatchingError(p))
          checkAutoStart()
        else
          destroyRoom()
      })
  }
  else
    checkAutoStart()
  initListLabelsSquad()

  setLastRound(public?.last_round ?? true)
  setRoomInSession(isSessionStartedInRoom())
  broadcastEvent("RoomJoined", params)
}

function afterRoomCreation(params) {
  if (!checkMatchingError(params))
    return switchSessionLobbyStatus(lobbyStates.NOT_IN_ROOM)

  isMeSessionLobbyRoomOwner.set(true)
  SessionLobbyState.isRoomByQueue = false
  afterRoomJoining(params)
}

function onMemberLeave(params, kicked = false) {
  if (isMemberHost(params))
    return updateMemberHostParams(null)

  foreach (idx, m in SessionLobbyState.members)
    if (params.memberId == m.memberId) {
      SessionLobbyState.members.remove(idx)
      if (isMyUserId(m.userId)) {
        afterLeaveRoom()
        if (kicked) {
          if (!isInMenu.get()) {
            quit_to_debriefing()
            interrupt_multiplayer(true)
            inFlightMenu(false)
          }
          scene_msg_box("you_kicked_out_of_battle", null, loc("matching/msg_kicked"),
                          [["ok", function () {}]], "ok",
                          { saved = true })
        }
      }
      broadcastEvent("LobbyMembersChanged")
      break
    }
}

function startCoopBySquad(missionSettings) {
  if (sessionLobbyStatus.get() != lobbyStates.NOT_IN_ROOM)
    return false

  prepareSettings(missionSettings)

  requestCreateRoom({ size = 4, public = SessionLobbyState.settings }, afterRoomCreation)
  switchSessionLobbyStatus(lobbyStates.CREATING_ROOM)
  return true
}

function createSessionLobbyRoom(missionSettings) {
  if (sessionLobbyStatus.get() != lobbyStates.NOT_IN_ROOM)
    return false

  prepareSettings(missionSettings)

  let initParams = {
    size = getSessionLobbyMaxMembersCount()
    public = SessionLobbyState.settings
  }
  if (SessionLobbyState.password && SessionLobbyState.password != "")
    initParams.password <- SessionLobbyState.password
  let blacklist = getContactsGroupUidList(EPL_BLOCKLIST)
  if (blacklist.len())
    initParams.blacklist <- blacklist

  requestCreateRoom(initParams, afterRoomCreation)
  switchSessionLobbyStatus(lobbyStates.CREATING_ROOM)
  return true
}

function createSessionLobbyEventRoom(mGameMode, lobbyParams) {
  if (sessionLobbyStatus.get() != lobbyStates.NOT_IN_ROOM)
    return false

  let params = {
    public = {
      game_mode_id = mGameMode.gameModeId
    }
    custom_matching_lobby = lobbyParams
  }

  isInSessionLobbyEventRoom.set(true)
  requestCreateRoom(params, afterRoomCreation)
  switchSessionLobbyStatus(lobbyStates.CREATING_ROOM)
  return true
}

function rpcJoinBattle(params) {
  if (!is_online_available())
    return "client not ready"
  let battleId = params.battleId
  if (!(battleId instanceof String))
    return "bad battleId type"
  if (g_squad_manager.getSquadSize() > 1)
    return "player is in squad"
  if (isInSessionRoom.get())
    return "already in room"
  if (isInFlight())
    return "already in session"
  if (!showMsgboxIfEacInactive({ enableEAC = true }))
    return "EAC is not active"
  if (!showMsgboxIfSoundModsNotAllowed({ allowSoundMods = false }))
    return "sound mods not allowed"

  checkShowMultiplayerAasWarningMsg(function() {
    log($"join to battle with id {battleId}")
    joinBattle(battleId)
  })
  return "ok"
}

webRpcRegister("join_battle", rpcJoinBattle)

addListenersWithoutEnv({
  MatchingDisconnect         = @(_) leaveSessionRoom()
  function MatchingConnect(_) {
    leaveSessionRoom()
    checkReconnect()
  }
  SessionRoomLeaved          = @(_) afterLeaveRoom()
  JoinedToSessionRoom        = @(p) afterRoomJoining(p)
  SquadStatusChanged         = @(_) checkSquadAutoInviteToRoom()
}, DEFAULT_HANDLER)

return {
  joinBattle
  joinSessionRoom
  checkReconnect
  joinSessionLobbyFoundRoom
  onMemberLeave
  startCoopBySquad
  createSessionLobbyRoom
  createSessionLobbyEventRoom
}
