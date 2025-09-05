from "%scripts/dagui_library.nut" import *
from "%scripts/teamsConsts.nut" import Team
import "%scripts/matchingRooms/lobbyStates.nut" as lobbyStates
from "%scripts/options/optionsConsts.nut" import misCountries
from "%scripts/controls/controlsConsts.nut" import optionControlType

let { addListenersWithoutEnv, DEFAULT_HANDLER, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { search, isEqual, isArray, isDataBlock, isEmpty } = require("%sqStdLibs/helpers/u.nut")
let { convertBlk } = require("%sqstd/datablock.nut")
let { INVALID_SQUAD_ID } = require("matching.errors")
let { set_game_mode, get_game_mode, get_game_type } = require("mission")
let { deferOnce } = require("dagor.workcycle")
let { eventbus_send, eventbus_subscribe } = require("eventbus")
let { isInFlight } = require("gameplayBinding")
let { getCdBaseDifficulty, get_cd_preset } = require("guiOptions")
let { get_mp_session_id_str } = require("multiplayer")
let { isDynamicWon } = require("dynamicMission")
let DataBlock = require("DataBlock")
let base64 = require("base64")
let { getGlobalModule } = require("%scripts/global_modules.nut")
let g_squad_manager = getGlobalModule("g_squad_manager")
let events = getGlobalModule("events")
let { isInMenu } = require("%scripts/clientState/clientStates.nut")
let { loadHandler, handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let ecs = require("%sqstd/ecs.nut")
let { EventOnConnectedToServer } = require("net")
let { MatchingRoomExtraParams = null } = require_optional("dasevents")
let { set_last_session_debug_info } = require("%scripts/matchingRooms/sessionDebugInfo.nut")
let { sendBqEvent } = require("%scripts/bqQueue/bqQueue.nut")
let { matchingApiFunc, matchingRpcSubscribe, checkMatchingError } = require("%scripts/matching/api.nut")
let { gen_rnd_password, get_array_by_bit_value } = require("%scripts/utils_sa.nut")
let { SessionLobbyState, sessionLobbyStatus, getSessionLobbyGameMode, isInSessionRoom, getSessionInfo,
  getSessionLobbyMissionData, updateSessionLobbyPlayersInfo, isMeSessionLobbyRoomOwner, isInSessionLobbyEventRoom,
  resetSessionLobbyPlayersInfo, isInJoiningGame, hasSessionInLobby, getSessionLobbyMyState, isWaitForQueueRoom,
  getSessionLobbyChatRoomPassword, canJoinSession, isRoomInSession, isSessionStartedInRoom, getMembersCount,
  isMemberHost, isUserMission, getSessionLobbyPublicParam, getSessionLobbyPassword
} = require("%scripts/matchingRooms/sessionLobbyState.nut")
let { haveLobby, getAvailableTeamOfRoom, getRoomTeamData,
  canSetReadyInLobby, canChangeTeamInLobby, canBeSpectator, getRoomUnitTypesMask, getRoomEvent,
} = require("%scripts/matchingRooms/sessionLobbyInfo.nut")
let { getRoomMemberPublicParam, isRoomMemberOperator, isRoomMemberInSession
} = require("%scripts/matchingRooms/sessionLobbyMembersInfo.nut")
let { setMemberAttributes, roomSetReadyState, setRoomAttributes, roomSetPassword,
  requestLeaveRoom, roomStartSession, requestDestroyRoom
} = require("%scripts/matching/serviceNotifications/mroomsApi.nut")
let { getProfileInfo } = require("%scripts/user/userInfoStats.nut")
let { getStats, getMissionsComplete } = require("%scripts/myStats.nut")
let { switchProfileCountry, profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { userIdInt64, userName, isMyUserId } = require("%scripts/user/profileStates.nut")
let { addDelayedAction } = require("%scripts/utils/delayedActions.nut")
let { g_difficulty } = require("%scripts/difficulty.nut")
let { updateIconPlayersInfo } = require("%scripts/statistics/squadIcon.nut")
let { debug_dump_stack } = require("dagor.debug")
let { getSessionLobbyMissionName, getUrlOrFileMissionMetaInfo
} = require("%scripts/missions/missionsUtilsModule.nut")
let { updateOverrideSlotbar, resetSlotbarOverrided, getSlotbarOverrideCountriesByMissionName
} = require("%scripts/slotbar/slotbarOverride.nut")
let { addRecentContacts } = require("%scripts/contacts/contactsManager.nut")
let { addPopup } = require("%scripts/popups/popups.nut")
let { isGameModeCoop } = require("%scripts/matchingRooms/matchingGameModesUtils.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { gui_start_mainmenu } = require("%scripts/mainmenu/guiStartMainmenu.nut")
let { isRemoteMissionVar, is_user_mission } = require("%scripts/missions/missionsStates.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { getMaxEconomicRank } = require("%appGlobals/ranks_common_shared.nut")
let { setUserPresence } = require("%scripts/userPresence.nut")
let { USEROPT_SESSION_PASSWORD } = require("%scripts/options/optionsExtNames.nut")
let { registerOption } = require("%scripts/options/optionsExt.nut")
let { showErrorMessageBox } = require("%scripts/utils/errorMsgBox.nut")

let destroySessionScripted = require("%scripts/matchingRooms/destroySessionScripted.nut")























const NET_SERVER_LOST = 0x82220002  
const NET_SERVER_QUIT_FROM_GAME = 0x82220003

local last_round = true

let needCheckReconnect = Watched(false)

let allowed_mission_settings = { 
                              
  name = null
  missionURL = null
  players = 12
  hidden = false  

  creator = ""
  hasPassword = false
  cluster = ""
  allowJIP = true
  coop = true
  friendOnly = false
  country_allies = ["country_ussr"]
  country_axis = ["country_germany"]

  mission = {
    name = "stalingrad_GSn"
    loc_name = ""
    postfix = ""
    _gameMode = 12
    _gameType = 0
    difficulty = "arcade"
    custDifficulty = "0"
    environment = "Day"
    weather = "cloudy"

    maxRespawns = -1
    timeLimit = 0
    killLimit = 0

    raceLaps = 1
    raceWinners = 1
    raceForceCannotShoot = false

    isBotsAllowed = true
    useTankBots = false
    ranks = {}
    useShipBots = false
    keepDead = true
    isLimitedAmmo = false
    isLimitedFuel = false
    optionalTakeOff = false
    dedicatedReplay = false
    allowWebUi = -1
    useKillStreaks = false
    disableAirfields = false
    spawnAiTankOnTankMaps = true
    allowEmptyTeams = false

    isHelicoptersAllowed = false
    isAirplanesAllowed = false
    isTanksAllowed = false
    isShipsAllowed = false
    



    takeoffMode = 0
    currentMissionIdx = -1
    allowedTagsPreset = ""

    locName = ""
    locDesc = ""
  }
}

function updateMyState() {
  local newState = PLAYER_IN_LOBBY_NOT_READY
  if (sessionLobbyStatus.get() == lobbyStates.IN_LOBBY || sessionLobbyStatus.get() == lobbyStates.START_SESSION)
    newState = SessionLobbyState.isReady ? PLAYER_IN_LOBBY_READY : PLAYER_IN_LOBBY_NOT_READY
  else if (sessionLobbyStatus.get() == lobbyStates.IN_LOBBY_HIDDEN)
    newState = PLAYER_IN_LOBBY_READY
  else if (sessionLobbyStatus.get() == lobbyStates.IN_SESSION)
    newState = PLAYER_IN_FLIGHT
  else if (sessionLobbyStatus.get() == lobbyStates.IN_DEBRIEFING)
    newState = PLAYER_IN_STATISTICS_BEFORE_LOBBY

  SessionLobbyState.myState = newState
  return SessionLobbyState.myState
}

function syncMyInfo(newInfo, cb = @(_) null) {
  if (isInArray(sessionLobbyStatus.get(), [lobbyStates.NOT_IN_ROOM, lobbyStates.WAIT_FOR_QUEUE_ROOM, lobbyStates.CREATING_ROOM, lobbyStates.JOINING_ROOM])
      || !haveLobby()
      || SessionLobbyState.isLeavingLobbySession)
    return

  local syncData = newInfo
  if (!SessionLobbyState._syncedMyInfo)
    SessionLobbyState._syncedMyInfo = newInfo
  else {
    syncData = {}
    foreach (key, value in newInfo) {
      if (key in SessionLobbyState._syncedMyInfo) {
        if (SessionLobbyState._syncedMyInfo[key] == value)
          continue
        if (type(value) == "array" || type(value) == "table")
          if (isEqual(SessionLobbyState._syncedMyInfo[key], value))
            continue
      }
      syncData[key] <- value
      SessionLobbyState._syncedMyInfo[key] <- value
    }
  }

  
  
  if (newInfo?.state == lobbyStates.IN_ROOM)
    syncData.spectator <- SessionLobbyState._syncedMyInfo?.spectator ?? false

  let info = {
    roomId = SessionLobbyState.roomId
    public = syncData
  }

  
  setMemberAttributes(info, cb)
  broadcastEvent("LobbyMyInfoChanged", syncData)
}

function updateReadyAndSyncMyInfo(ready) {
  SessionLobbyState.isReady = ready
  syncMyInfo({ state = updateMyState() })
  broadcastEvent("LobbyReadyChanged")
}

function updateMemberHostParams(member = null) { 
  SessionLobbyState.memberHostId = member ? member.memberId : -1
}

function syncAllInfo() {
  let myInfo = getProfileInfo()
  let myStats = getStats()
  let squadId = g_squad_manager.getSquadData().id
  syncMyInfo({
    team = SessionLobbyState.team
    squad = getSessionLobbyGameMode() == GM_SKIRMISH && squadId != "" ? squadId.tointeger() : INVALID_SQUAD_ID
    country = SessionLobbyState.countryData?.country
    selAirs = SessionLobbyState.countryData?.selAirs
    slots = SessionLobbyState.countryData?.slots
    spectator = SessionLobbyState.spectator
    clanTag = myInfo.clanTag
    title = myStats ? myStats.title : ""
    state = updateMyState()
  })
}

function setMyTeamInRoom(newTeam, silent = false) { 
  local _team = newTeam
  let canPlayTeam = getAvailableTeamOfRoom()

  if (canPlayTeam == Team.A || canPlayTeam == Team.B)
    _team = canPlayTeam

  if (SessionLobbyState.team == _team)
    return false

  SessionLobbyState.team = _team

  if (!silent)
    syncMyInfo({ team = SessionLobbyState.team }, @(_) broadcastEvent("MySessionLobbyInfoSynced"))

  return true
}

function setSessionLobbyReady(ready, silent = false, forceRequest = false) { 
  if (!forceRequest && SessionLobbyState.isReady == ready)
    return false
  if (ready && !canSetReadyInLobby(silent)) {
    if (SessionLobbyState.isReady)
      ready = false
    else
      return false
  }

  if (!isInSessionRoom.get()) {
    SessionLobbyState.isReady = false
    return ready
  }

  SessionLobbyState.isReadyInSetStateRoom = ready
  roomSetReadyState(
    { state = ready, roomId = SessionLobbyState.roomId },
    function(p) {
      SessionLobbyState.isReadyInSetStateRoom = null
      if (!isInSessionRoom.get()) {
        SessionLobbyState.isReady = false
        return
      }

      let wasReady = SessionLobbyState.isReady
      local needUpdateState = !silent
      SessionLobbyState.isReady = ready

      
      if (!checkMatchingError(p, !silent)) {
        SessionLobbyState.isReady = false
        needUpdateState = true
      }

      if (SessionLobbyState.isReady == wasReady)
        return

      if (needUpdateState)
        syncMyInfo({ state = updateMyState() })
      broadcastEvent("LobbyReadyChanged")
    })
  return true
}

function checkMyTeamInRoom() { 
  let data = {}

  if (!haveLobby())
    return data

  local setTeamTo = SessionLobbyState.team
  if (getAvailableTeamOfRoom() == Team.none) {
    if (setSessionLobbyReady(false, true))
      data.state <- updateMyState()
    setTeamTo = SessionLobbyState.crsSetTeamTo
  }

  if (setTeamTo != Team.none && setMyTeamInRoom(setTeamTo, true)) {
    data.team <- SessionLobbyState.team
    let myCountry = profileCountrySq.get()
    let availableCountries = getRoomTeamData(SessionLobbyState.team)?.countries ?? []
    if (availableCountries.len() > 0 && !isInArray(myCountry, availableCountries))
      switchProfileCountry(availableCountries[0])
  }
  return data
}

function switchMyTeamInRoom(skipTeamAny = false) {
  if (!canChangeTeamInLobby())
    return false

  local newTeam = SessionLobbyState.team + 1
  if (newTeam >= Team.none)
    newTeam = skipTeamAny ? 1 : 0
  return setMyTeamInRoom(newTeam)
}

function setSessionLobbyCountryData(data) { 
  local changed = !SessionLobbyState.countryData || !isEqual(SessionLobbyState.countryData, data)
  SessionLobbyState.countryData = data
  let teamDataChanges = checkMyTeamInRoom()
  changed = changed || teamDataChanges.len() > 0
  if (!changed)
    return false

  foreach (i, v in teamDataChanges)
    data[i] <- v
  syncMyInfo(data, @(_) broadcastEvent("MySessionLobbyInfoSynced"))
  return true
}

function setSpectator(newSpectator) { 
  if (!canBeSpectator())
    newSpectator = false
  if (SessionLobbyState.spectator == newSpectator)
    return false

  SessionLobbyState.spectator = newSpectator
  syncMyInfo({ spectator = SessionLobbyState.spectator }, @(_) broadcastEvent("MySessionLobbyInfoSynced"))
  return true
}

function switchSpectator() {
  if (!canBeSpectator() && !SessionLobbyState.spectator)
    return false

  local newSpectator = !SessionLobbyState.spectator
  return setSpectator(newSpectator)
}

function validateTeamAndReady() {
  let teamDataChanges = checkMyTeamInRoom()
  if (!teamDataChanges.len()) {
    if (SessionLobbyState.isReady && !canSetReadyInLobby(true))
      setSessionLobbyReady(false)
    return
  }
  syncMyInfo(teamDataChanges, @(_) broadcastEvent("MySessionLobbyInfoSynced"))
}

function userInUidsList(list_name) {
  let ids = getSessionInfo()?[list_name]
  if (isArray(ids))
    return isInArray(userIdInt64.get(), ids)
  return false
}

function updateCrsSettings() {
  SessionLobbyState.isSpectatorSelectLocked = false

  if (userInUidsList("referees") || userInUidsList("spectators")) {
    SessionLobbyState.isSpectatorSelectLocked = true
    setSpectator(SessionLobbyState.isSpectatorSelectLocked)
  }

  SessionLobbyState.crsSetTeamTo = Team.none
  foreach (team in events.getSidesList()) {
    let players = getSessionInfo()?[events.getTeamName(team)].players
    if (!isArray(players))
      continue

    foreach (uid in players)
      if (isMyUserId(uid)) {
        SessionLobbyState.crsSetTeamTo = team
        break
      }

    if (SessionLobbyState.crsSetTeamTo != Team.none)
      break
  }
}

function initMyParamsByMemberInfo(me = null) {
  if (!me)
    me = search(SessionLobbyState.members, function(m) { return isMyUserId(m.userId) })
  if (!me)
    return

  let myTeam = getRoomMemberPublicParam(me, "team")
  if (myTeam != Team.Any && myTeam != SessionLobbyState.team)
    SessionLobbyState.team = myTeam

  if (myTeam == Team.Any)
    validateTeamAndReady()
}

function addTeamsInfoToSettings(v_settings, teamDataA, teamDataB) {
  v_settings[events.getTeamName(Team.A)] <- teamDataA
  v_settings[events.getTeamName(Team.B)] <- teamDataB
}

function fillTeamsInfo(v_settings, _misBlk) {
  
  let teamData = {}
  teamData.allowedCrafts <- []

  foreach (unitType in unitTypes.types)
    if (unitType.isAvailableByMissionSettings(v_settings.mission) && unitType.isPresentOnMatching) {
      let rule = { ["class"] = unitType.getMissionAllowedCraftsClassName() }
      if (v_settings?.mranks)
        rule.mranks <- v_settings.mranks
      teamData.allowedCrafts.append(rule)
    }

  
  let teamDataA = teamData
  local teamDataB = clone teamData

  
  teamDataA.countries <- v_settings.country_allies
  teamDataB.countries <- v_settings.country_axis

  addTeamsInfoToSettings(v_settings, teamDataA, teamDataB)
}

function leaveEventSessionWithRetry() {
  SessionLobbyState.isLeavingLobbySession = true
  let self = callee()
  matchingApiFunc("mrooms.leave_session",
    function(params) {
      
      
      if (params?.error_id == "MATCH.PLAYER_IN_SESSION")
        addDelayedAction(self, 1000)
      else {
        SessionLobbyState.isLeavingLobbySession = false
        broadcastEvent("LobbyStatusChange")
      }
    })
}

function getDifficulty(room = null) {
  let diffValue = getSessionLobbyMissionData(room)?.difficulty
  let difficulty = (diffValue == "custom")
    ? g_difficulty.getDifficultyByDiffCode(getCdBaseDifficulty())
    : g_difficulty.getDifficultyByName(diffValue)
  return difficulty
}

function calcEdiff(room = null) {
  return getDifficulty(room).getEdiffByUnitMask(getRoomUnitTypesMask(room))
}

function updatePlayersInfo() {
  updateSessionLobbyPlayersInfo()
  updateIconPlayersInfo()
}

function setCustomPlayersInfo(customPlayersInfo) {
  SessionLobbyState.playersInfo = customPlayersInfo
  updateIconPlayersInfo()
}

function setExternalSessionId(extId) {
  if (SessionLobbyState.settings?.externalSessionId == extId)
    return

  SessionLobbyState.settings["externalSessionId"] <- extId
  setRoomAttributes({ roomId = SessionLobbyState.roomId, public = SessionLobbyState.settings }, @(p) broadcastEvent("RoomAttributesUpdated", p))
}

function setSettings(v_settings, notify = false, checkEqual = true) {
  if (type(v_settings) == "array") {
    log("v_settings param, public info, is array, instead of table")
    debug_dump_stack()
    return
  }

  if (checkEqual && isEqual(SessionLobbyState.settings, v_settings))
    return

  
  SessionLobbyState.settings = clone v_settings
  
  SessionLobbyState.settings.connect_on_join <- !haveLobby()

  updateCrsSettings()
  updatePlayersInfo()
  updateOverrideSlotbar(getSessionLobbyMissionName(true))

  SessionLobbyState.curEdiff = calcEdiff(SessionLobbyState.settings)

  SessionLobbyState.roomUpdated = notify || !isMeSessionLobbyRoomOwner.get() || !isInSessionRoom.get() || isInSessionLobbyEventRoom.get()
  if (!SessionLobbyState.roomUpdated)
    setRoomAttributes({ roomId = SessionLobbyState.roomId, public = SessionLobbyState.settings }, @(p) broadcastEvent("RoomAttributesUpdated", p))

  if (isInSessionRoom.get())
    validateTeamAndReady()

  let newGm = getSessionLobbyGameMode()
  if (newGm >= 0)
    set_game_mode(newGm)

  broadcastEvent("LobbySettingsChange")
}

function checkDynamicSettings(silent = false, v_settings = null) {
  if (!isMeSessionLobbyRoomOwner.get() && isInSessionRoom.get())
    return

  if (!v_settings) {
    if (!SessionLobbyState.settings || !SessionLobbyState.settings.len())
      return 
    v_settings = SessionLobbyState.settings
  }
  else
    silent = true 

  local changed = false
  let wasHidden = getTblValue("hidden", v_settings, false)
  v_settings.hidden <- getTblValue("coop", v_settings, false)
    || (isRoomInSession.get() && !getTblValue("allowJIP", v_settings, true))
  changed = changed || (wasHidden != v_settings.hidden) 

  let wasPassword = getTblValue("hasPassword", v_settings, false)
  v_settings.hasPassword <- SessionLobbyState.password != ""
  changed = changed || (wasPassword != v_settings.hasPassword)

  if (changed && !silent)
    setSettings(SessionLobbyState.settings, false, false)
}

function changeRoomPassword(v_password) {
  if (type(v_password) != "string" || SessionLobbyState.password == v_password)
    return

  if (isMeSessionLobbyRoomOwner.get() && sessionLobbyStatus.get() != lobbyStates.NOT_IN_ROOM && sessionLobbyStatus.get() != lobbyStates.CREATING_ROOM) {
    let prevPass = SessionLobbyState.password
    roomSetPassword({ roomId = SessionLobbyState.roomId, password = v_password },
      function(p) {
        if (!checkMatchingError(p)) {
          SessionLobbyState.password = prevPass
          checkDynamicSettings()
        }
      })
  }
  SessionLobbyState.password = v_password
}

function resetParams() {
  SessionLobbyState.settings.clear()
  changeRoomPassword("") 
  updateMemberHostParams(null)
  SessionLobbyState.team = Team.Any
  SessionLobbyState.isRoomByQueue = false
  isInSessionLobbyEventRoom.set(false)
  SessionLobbyState.myState = PLAYER_IN_LOBBY_NOT_READY
  SessionLobbyState.roomUpdated = false
  SessionLobbyState.spectator = false
  SessionLobbyState._syncedMyInfo = null
  SessionLobbyState.needJoinSessionAfterMyInfoApply = false
  SessionLobbyState.isLeavingLobbySession = false
  resetSessionLobbyPlayersInfo()
  resetSlotbarOverrided()
  setUserPresence({ in_game_ex = null })
}

function guiStartMpLobby() {
  if (sessionLobbyStatus.get() != lobbyStates.IN_LOBBY) {
    gui_start_mainmenu()
    return
  }

  local backFromLobby = { eventbusName = "gui_start_mainmenu" }
  if (getSessionLobbyGameMode() == GM_SKIRMISH && !isRemoteMissionVar.get())
    backFromLobby = { eventbusName = "guiStartSkirmish" }
  else {
    let lastEvent = getRoomEvent()
    if (lastEvent && events.eventRequiresTicket(lastEvent) && events.getEventActiveTicket(lastEvent) == null) {
      gui_start_mainmenu()
      return
    }
  }

  isRemoteMissionVar.set(false)
  loadHandler(gui_handlers.MPLobby, { backSceneParams = backFromLobby })
}

let joiningGameWaitBox = @() loadHandler(gui_handlers.JoiningGameWaitBox)

function switchStatus(v_status) {
  if (sessionLobbyStatus.get() == v_status)
    return

  let wasInRoom = isInSessionRoom.get()
  let wasStatus = sessionLobbyStatus.get()
  let wasSessionInLobby = isInSessionLobbyEventRoom.get()
  sessionLobbyStatus.set(v_status)  
  if (isInJoiningGame.get())
    joiningGameWaitBox()
  if (sessionLobbyStatus.get() == lobbyStates.IN_LOBBY) {
    
    deferOnce(guiStartMpLobby)
  }

  if (sessionLobbyStatus.get() == lobbyStates.IN_DEBRIEFING && hasSessionInLobby())
    leaveEventSessionWithRetry()

  if (sessionLobbyStatus.get() == lobbyStates.NOT_IN_ROOM || sessionLobbyStatus.get() == lobbyStates.IN_DEBRIEFING)
    setSessionLobbyReady(false, true)
  if (sessionLobbyStatus.get() == lobbyStates.NOT_IN_ROOM) {
    resetParams()
    if (wasStatus == lobbyStates.JOINING_SESSION)
      destroySessionScripted("on leave room while joining session")
  }
  if (sessionLobbyStatus.get() == lobbyStates.JOINING_SESSION)
    addRecentContacts(g_squad_manager.getSquadMembersDataForContact())

  let curState = getSessionLobbyMyState()
  let newState = updateMyState()
  if (curState != newState)
    syncMyInfo({ state = newState })

  broadcastEvent("LobbyStatusChange")
  eventbus_send("setIsMultiplayerState", { isMultiplayer = isInSessionRoom.get() })
  if (wasInRoom != isInSessionRoom.get())
    broadcastEvent("LobbyIsInRoomChanged", { wasSessionInLobby })
}

function switchStatusChecked(oldStatusList, newStatus) {
  if (isInArray(sessionLobbyStatus.get(), oldStatusList))
    switchStatus(newStatus)
}

function setWaitForQueueRoom(set) {
  if (sessionLobbyStatus.get() == lobbyStates.NOT_IN_ROOM || sessionLobbyStatus.get() == lobbyStates.WAIT_FOR_QUEUE_ROOM)
    switchStatus(set ? lobbyStates.WAIT_FOR_QUEUE_ROOM : lobbyStates.NOT_IN_ROOM)
}

function leaveWaitForQueueRoom() {
  if (!isWaitForQueueRoom.get())
    return

  setWaitForQueueRoom(false)
  addPopup(null, loc("NET_CANNOT_ENTER_SESSION"))
}

function findParam(key, tbl1, tbl2) {
  if (key in tbl1)
    return tbl1[key]
  if (key in tbl2)
    return tbl2[key]
  return null
}

function validateMissionCountry(country, fullCountriesList) {
  if (isInArray(country, fullCountriesList))
    return null
  if (isInArray($"country_{country}", fullCountriesList))
    return $"country_{country}"
  return null
}

function prepareSettings(missionSettings) {
  let _settings = {}
  let mission = missionSettings.mission

  foreach (key, v in allowed_mission_settings) {
    if (key == "mission")
      continue
    local value = findParam(key, missionSettings, mission)
    if (type(v) == "array" && type(value) != "array")
      value = [value]
    _settings[key] <- value 
  }

  _settings.mission <- {}
  foreach (key, _v in allowed_mission_settings.mission) {
    local value = findParam(key, mission, missionSettings)
    if (key == "postfix")
      value = getTblValue(key, missionSettings)
    if (value == null)
      continue

    _settings.mission[key] <- isDataBlock(value) ? convertBlk(value) : value
  }

  _settings.mission.keepOwnUnits <- mission?.editSlotbar.keepOwnUnits ?? true
  _settings.creator <- userName.get()
  _settings.mission.originalMissionName <- getTblValue("name", _settings.mission, "")
  if ("postfix" in _settings.mission && _settings.mission.postfix) {
    let ending = "_tm"
    local nameNoTm = _settings.mission.name
    if (nameNoTm.len() > ending.len() && nameNoTm.slice(nameNoTm.len() - ending.len()) == ending)
      nameNoTm = nameNoTm.slice(0, nameNoTm.len() - ending.len())
    _settings.mission.loc_name = $"{nameNoTm}{_settings.mission.postfix}"
    _settings.mission.name = $"{_settings.mission.name}{_settings.mission.postfix}"
  }
  if (is_user_mission(mission))
    _settings.userMissionName <- loc($"missions/{mission.name}")
  if (!("_gameMode" in _settings.mission))
    _settings.mission._gameMode <- get_game_mode()
  if (!("_gameType" in _settings.mission))
    _settings.mission._gameType <- get_game_type()
  if (getTblValue("coop", _settings) == null)
    _settings.coop <- isGameModeCoop(_settings.mission._gameMode)
  if (("difficulty" in _settings.mission) && _settings.mission.difficulty == "custom")
    _settings.mission.custDifficulty <- get_cd_preset(DIFFICULTY_CUSTOM)

  
  let countriesType = getTblValue("countriesType", missionSettings, misCountries.ALL)
  local fullCountriesList = getSlotbarOverrideCountriesByMissionName(_settings.mission.originalMissionName)
  if (!fullCountriesList.len())
    fullCountriesList = clone shopCountriesList
  foreach (name in ["country_allies", "country_axis"]) {
    local countries = null
    if (countriesType == misCountries.BY_MISSION) {
      countries = getTblValue(name, _settings, [])
      for (local i = countries.len() - 1; i >= 0; i--) {
        countries[i] = validateMissionCountry(countries[i], fullCountriesList)
        if (!countries[i])
          countries.remove(i)
      }
    }
    else if (countriesType == misCountries.SYMMETRIC || countriesType == misCountries.CUSTOM) {
      let bitMaskKey = (countriesType == misCountries.SYMMETRIC) ? "country_allies" : name
      countries = get_array_by_bit_value(getTblValue($"{bitMaskKey}_bitmask", missionSettings, 0), shopCountriesList)
    }
    _settings[name] <- (countries && countries.len()) ? countries : fullCountriesList
  }

  let userAllowedUnitTypesMask = missionSettings?.userAllowedUnitTypesMask ?? 0
  if (userAllowedUnitTypesMask)
    foreach (unitType in unitTypes.types)
      if (unitType.isAvailableByMissionSettings(_settings.mission) && !(userAllowedUnitTypesMask & unitType.bit) && unitType.isPresentOnMatching)
        _settings.mission[unitType.missionSettingsAvailabilityFlag] = false

  local mrankMin = missionSettings?.mrankMin ?? 0
  local mrankMax = missionSettings?.mrankMax ?? getMaxEconomicRank()
  if (mrankMin > mrankMax) {
    let temp = mrankMin
    mrankMin = mrankMax
    mrankMax = temp
  }
  if (mrankMin > 0 || mrankMax < getMaxEconomicRank())
    _settings.mranks <- { min = mrankMin, max = mrankMax }

  _settings.chatPassword <- isInSessionRoom.get() ? getSessionLobbyChatRoomPassword() : gen_rnd_password(16)
  if (!isEmpty(SessionLobbyState.settings?.externalSessionId))
    _settings.externalSessionId <- SessionLobbyState.settings?.externalSessionId
  if (!isEmpty(SessionLobbyState.settings?.psnMatchId))
    _settings.psnMatchId <- SessionLobbyState.settings?.psnMatchId

  fillTeamsInfo(_settings, mission)

  checkDynamicSettings(true, _settings)
  setSettings(_settings)
}

function returnStatusToRoom() {
  local newStatus = lobbyStates.IN_ROOM
  if (haveLobby())
    newStatus = SessionLobbyState.isRoomByQueue ? lobbyStates.IN_LOBBY_HIDDEN : lobbyStates.IN_LOBBY
  switchStatus(newStatus)
}

function updateRoomAttributes(missionSettings) {
  if (!isMeSessionLobbyRoomOwner.get())
    return

  prepareSettings(missionSettings)
}

function continueCoopWithSquad(missionSettings) {
  switchStatus(lobbyStates.IN_ROOM)
  prepareSettings(missionSettings)
}


function goForwardSessionLobbyAfterDebriefing() {
  if (!haveLobby() || !isInSessionRoom.get())
    return false

  SessionLobbyState.isRoomByQueue = false 
  if (sessionLobbyStatus.get() == lobbyStates.IN_LOBBY)
    guiStartMpLobby()
  else
    returnStatusToRoom()
  return true
}

let sendSessionRoomLeavedEvent = @() broadcastEvent("SessionRoomLeaved")

function leaveSessionRoom() {
  if (sessionLobbyStatus.get() == lobbyStates.NOT_IN_ROOM || sessionLobbyStatus.get() == lobbyStates.WAIT_FOR_QUEUE_ROOM) {
    setWaitForQueueRoom(false)
    return
  }

  requestLeaveRoom({}, @(_) sendSessionRoomLeavedEvent())
}

function joinEventSession(needLeaveRoomOnError = false, params = null) {
  matchingApiFunc("mrooms.join_session",
    function(params_) {
      if (!checkMatchingError(params_) && needLeaveRoomOnError)
        leaveSessionRoom()
    },
    params
  )
}


function checkUpdateMatchingSlots() {
  if (hasSessionInLobby()) {
    if (SessionLobbyState.isInLobbySession)
      joinEventSession(false, { update_profile = true })
  }
  else if (SessionLobbyState.isReady && (SessionLobbyState.isReadyInSetStateRoom == null || SessionLobbyState.isReadyInSetStateRoom))
    setSessionLobbyReady(SessionLobbyState.isReady, true, true)
}

function tryJoinSession(needLeaveRoomOnError = false) {
  if (!canJoinSession())
    return false

  if (hasSessionInLobby()) {
    joinEventSession(needLeaveRoomOnError)
    return true
  }
  if (isRoomInSession.get()) {
    setSessionLobbyReady(true)
    return true
  }
  return false
}

function checkLeaveRoomInDebriefing() {
  if (get_game_mode() == GM_DYNAMIC && !isDynamicWon())
    return

  if (!last_round)
    return

  if (isInSessionRoom.get() && !haveLobby())
    leaveSessionRoom()
}

function setRoomInSession(newIsInSession) {
  if (newIsInSession == isRoomInSession.get())
    return

  isRoomInSession.set(newIsInSession)
  if (!isInSessionRoom.get())
    return

  broadcastEvent("LobbyRoomInSession")
  if (isMeSessionLobbyRoomOwner.get())
    checkDynamicSettings()
}

function onSettingsChanged(p) {
  if (SessionLobbyState.roomId != p.roomId)
    return
  let set = getTblValue("public", p)
  if (!set)
    return

  if ("last_round" in set) {
    last_round = set.last_round
    log($"last round {last_round}")
  }

  let newSet = clone SessionLobbyState.settings
  foreach (k, v in set)
    if (v == null) {
      newSet?.$rawdelete(k)
    }
    else
      newSet[k] <- v

  setSettings(newSet, true)
  setRoomInSession(isSessionStartedInRoom())
}

function mergeTblChanges(tblBase, tblNew) {
  if (tblNew == null)
    return tblBase

  foreach (key, value in tblNew)
    if (value != null)
      tblBase[key] <- value
    else if (key in tblBase)
      tblBase.$rawdelete(key)
  return tblBase
}

function onMemberInfoUpdate(params) {
  if (params.roomId != SessionLobbyState.roomId)
    return
  if (isMemberHost(params))
    return updateMemberHostParams(params)

  local member = null
  foreach (m in SessionLobbyState.members)
    if (m.memberId == params.memberId) {
      member = m
      break
    }
  if (!member)
    return

  foreach (tblName in ["public", "private"])
    if (tblName in params)
      if (tblName in member)
        mergeTblChanges(member[tblName], params[tblName])
      else
        member[tblName] <- params[tblName]

  if (isMyUserId(member.userId)) {
    isMeSessionLobbyRoomOwner.set(isRoomMemberOperator(member))
    SessionLobbyState.isInLobbySession = isRoomMemberInSession(member)
    initMyParamsByMemberInfo(member)
    let ready = getTblValue("ready", getTblValue("public", member, {}), null)
    if (!hasSessionInLobby() && ready != null && ready != SessionLobbyState.isReady)
      updateReadyAndSyncMyInfo(ready)
    else if (SessionLobbyState.needJoinSessionAfterMyInfoApply)
      tryJoinSession(true)
    SessionLobbyState.needJoinSessionAfterMyInfoApply = false
  }
  broadcastEvent("LobbyMemberInfoChanged")
}

function isMissionReady() {
  return !isUserMission() ||
    (sessionLobbyStatus.get() != lobbyStates.UPLOAD_CONTENT && SessionLobbyState.uploadedMissionId == getSessionLobbyMissionName())
}

function uploadUserMission(afterDoneFunc = null) {
  if (!isInSessionRoom.get() || !isUserMission() || sessionLobbyStatus.get() == lobbyStates.UPLOAD_CONTENT)
    return

  let missionId = getSessionLobbyMissionName()
  if (SessionLobbyState.uploadedMissionId == missionId) {
    afterDoneFunc?()
    return
  }

  let missionInfo = DataBlock()
  missionInfo.setFrom(getUrlOrFileMissionMetaInfo(missionId))
  let missionBlk = DataBlock()
  if (missionInfo)
    missionBlk.load(missionInfo.mis_file)
  
  

  let blkData = base64.encodeBlk(missionBlk)
  
  
  if (!blkData || !("result" in blkData) || !blkData.result.len()) {
    showInfoMsgBox(loc("msg/cant_load_user_mission"))
    return
  }

  switchStatus(lobbyStates.UPLOAD_CONTENT)
  setRoomAttributes({ roomId = SessionLobbyState.roomId, private = { userMission = blkData.result } },
                        function(p) {
                          if (!checkMatchingError(p)) {
                            returnStatusToRoom()
                            return
                          }
                          SessionLobbyState.uploadedMissionId = missionId
                          returnStatusToRoom()
                          if (afterDoneFunc)
                            afterDoneFunc()
                        })
}

function destroyRoom() {
  if (!isMeSessionLobbyRoomOwner.get())
    return

  requestDestroyRoom({ roomId = SessionLobbyState.roomId }, @(_) null)
  sendSessionRoomLeavedEvent()
}

function startSession() {
  if (sessionLobbyStatus.get() != lobbyStates.IN_ROOM
      && sessionLobbyStatus.get() != lobbyStates.IN_LOBBY
      && sessionLobbyStatus.get() != lobbyStates.IN_LOBBY_HIDDEN)
    return
  if (!isMissionReady()) {
    let self = callee()
    uploadUserMission(self)
    return
  }
  log("start session")

  roomStartSession({ roomId = SessionLobbyState.roomId, cluster = getSessionLobbyPublicParam("cluster", "EU") },
    function(p) {
      if (!isInSessionRoom.get())
        return
      if (!checkMatchingError(p)) {
        if (!haveLobby())
          destroyRoom()
        else if (isInMenu.get())
          returnStatusToRoom()
        return
      }
      switchStatus(lobbyStates.JOINING_SESSION)
    })
  switchStatus(lobbyStates.START_SESSION)
}

function checkAutoStart() {
  if (isMeSessionLobbyRoomOwner.get() && !SessionLobbyState.isRoomByQueue && !haveLobby() && SessionLobbyState.roomUpdated
      && g_squad_manager.getOnlineMembersCount() <= getMembersCount())
    startSession()
}

function onMemberJoin(params) {
  if (isMemberHost(params))
    return updateMemberHostParams(params)

  foreach (m in SessionLobbyState.members)
    if (m.memberId == params.memberId) {
      onMemberInfoUpdate(params)
      return
    }
  SessionLobbyState.members.append(params)
  broadcastEvent("LobbyMembersChanged")
  checkAutoStart()
}

function afterRoomUpdate(params) {
  if (!checkMatchingError(params, false))
    return destroyRoom()

  SessionLobbyState.roomUpdated = true
  checkAutoStart()
}

function sessionLobbyHostCb(res) {
  if ((type(res) == "table") && ("errCode" in res)) {
    local errorCode;
    if (res.errCode == 0) {
      if (get_game_mode() == GM_DOMINATION)
        errorCode = NET_SERVER_LOST
      else
        errorCode = NET_SERVER_QUIT_FROM_GAME
    }
    else
      errorCode = res.errCode

    needCheckReconnect.set(true)

    if (isInSessionRoom.get())
      if (haveLobby())
        returnStatusToRoom()
      else
        leaveSessionRoom()

    showErrorMessageBox("yn1/connect_error", errorCode,
      [["ok", @() destroySessionScripted("on error message from host") ]],
      "ok",
      { saved = true })
  }
}

function LoadingStateChange(_) {
  if (handlersManager.isInLoading)
    return

  if (isInFlight())
    switchStatusChecked(
      [lobbyStates.IN_ROOM, lobbyStates.IN_LOBBY, lobbyStates.IN_LOBBY_HIDDEN,
       lobbyStates.JOINING_SESSION],
      lobbyStates.IN_SESSION
    )
  else
    switchStatusChecked(
      [lobbyStates.IN_SESSION, lobbyStates.JOINING_SESSION],
      lobbyStates.IN_DEBRIEFING
    )
}

function fillUseroptSessionPassword(_optionId, descr, _context) {
  descr.id = "session_password"
  descr.controlType = optionControlType.EDITBOX
  descr.controlName <- "editbox"
  descr.value = getSessionLobbyPassword()
  descr.getValueLocText = @(val) val ? loc("options/yes") : loc("options/no")
}

registerOption(USEROPT_SESSION_PASSWORD, fillUseroptSessionPassword,
  @(value, _descr, _optionId) changeRoomPassword(value ?? ""))

addListenersWithoutEnv({
  LoadingStateChange
  UnitRepaired               = @(_) checkUpdateMatchingSlots()
  SlotbarUnitChanged         = @(_) checkUpdateMatchingSlots()
  MySessionLobbyInfoSynced   = @(_) checkUpdateMatchingSlots()
  RoomAttributesUpdated      = @(p) afterRoomUpdate(p)
}, DEFAULT_HANDLER)

matchingRpcSubscribe("match.notify_wait_for_session_join",
  @(_) setWaitForQueueRoom(true))
matchingRpcSubscribe("match.notify_join_session_aborted",
  @(_) leaveWaitForQueueRoom())

ecs.register_es("on_connected_to_server_es", {
  [EventOnConnectedToServer] = function() {
    if (MatchingRoomExtraParams == null)
      return
    let { routeEvaluationChance = 0.0, ddosSimulationChance = 0.0, ddosSimulationAddRtt = 0 } =  getRoomEvent()
    ecs.g_entity_mgr.broadcastEvent(MatchingRoomExtraParams({
        routeEvaluationChance = routeEvaluationChance,
        ddosSimulationChance = ddosSimulationChance,
        ddosSimulationAddRtt = ddosSimulationAddRtt,
    }));
  },
})

eventbus_subscribe("notify_session_start", function notify_session_start(...) {
  let sessionId = get_mp_session_id_str()
  if (sessionId != "")
    set_last_session_debug_info($"sid:{sessionId}")

  log("notify_session_start")
  sendBqEvent("CLIENT_BATTLE_2", "joining_session", {
    gm = get_game_mode()
    sessionId = sessionId
    missionsComplete = getMissionsComplete()
  })
  switchStatus(lobbyStates.JOINING_SESSION)
})

eventbus_subscribe("on_sign_out", function(...) {
  if (!isInSessionRoom.get())
    return
  leaveSessionRoom()
})

eventbus_subscribe("on_connection_failed", function on_connection_failed(evt) {
  let text = evt.reason
  if (!isInSessionRoom.get())
    return
  destroySessionScripted("on_connection_failed")
  leaveSessionRoom()
  showInfoMsgBox(text, "on_connection_failed")
})

return {
  setMyTeamInRoom
  setSessionLobbyReady
  switchMyTeamInRoom
  setSessionLobbyCountryData
  switchSpectator
  setCustomPlayersInfo
  setExternalSessionId
  guiStartMpLobby
  setWaitForQueueRoom
  updateRoomAttributes
  continueCoopWithSquad
  goForwardSessionLobbyAfterDebriefing
  leaveSessionRoom
  tryJoinSession
  checkLeaveRoomInDebriefing
  onSettingsChanged
  onMemberInfoUpdate
  startSession
  onMemberJoin
  sessionLobbyHostCb
  setSessionLobbySettings = setSettings
  switchSessionLobbyStatus = switchStatus
  changeRoomPassword
  needCheckReconnect
  syncAllSessionLobbyInfo = syncAllInfo
  initMyParamsByMemberInfo
  updateMemberHostParams
  returnStatusToRoom
  checkAutoStart
  destroyRoom
  setLastRound = @(v) last_round = v
  setRoomInSession
  prepareSettings
}
