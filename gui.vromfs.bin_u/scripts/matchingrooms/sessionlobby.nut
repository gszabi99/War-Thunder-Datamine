local antiCheat = require("scripts/penitentiary/antiCheat.nut")
local unitTypes = require("scripts/unit/unitTypesList.nut")
local { getPlayerName } = require("scripts/clientState/platform.nut")

/*
SessionLobby API

  all:
    createRoom(missionSettings)
    isInRoom
    joinRoom
    leaveRoom
    setReady(bool)
    syncAllInfo

  room owner:
    destroyRoom
    updateRoomAttributes(missionSettings)
    invitePlayer(uid)
    kickPlayer(uid)
    startSession

  squad leader:
    startCoopBySquad(missionSettings)

*/


local time = require("scripts/time.nut")
local ingame_chat = require("scripts/chat/mpChatModel.nut")
local penalties = require("scripts/penitentiary/penalties.nut")


const NET_SERVER_LOST = 0x82220002  //for hostCb
const NET_SERVER_QUIT_FROM_GAME = 0x82220003

const CUSTOM_GAMEMODE_KEY = "_customGameMode"

const MAX_BR_DIFF_AVAILABLE_AND_REQ_UNITS = 0.6

::INVITE_LIFE_TIME    <- 3600000

::LAST_SESSION_DEBUG_INFO <- ""

::last_round <- true

global enum lobbyStates
{
  NOT_IN_ROOM,
  WAIT_FOR_QUEUE_ROOM,
  CREATING_ROOM,
  JOINING_ROOM,
  IN_ROOM,
  IN_LOBBY,
  IN_LOBBY_HIDDEN, //in loby, but hidden by joining wnd. Used when lobby after queue before session
  UPLOAD_CONTENT,
  START_SESSION,
  JOINING_SESSION,
  IN_SESSION,
  IN_DEBRIEFING
}

local allowed_mission_settings = { //only this settings are allowed in room
                              //default params used only to check type atm
  name = null
  missionURL = null
  players = 12
  hidden = false  //can be found by search rooms

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
     weather = "clear"

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
     isLimitedAmmo = false
     isLimitedFuel = false
     optionalTakeOff = false
     dedicatedReplay = false
     useKillStreaks = false
     disableAirfields = false
     spawnAiTankOnTankMaps = true

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

// rooms notifications
::notify_room_invite <- function notify_room_invite(params)
{
  dagor.debug("notify_room_invite")
  //debugTableData(params)

  if (!::isInMenu() && ::g_login.isLoggedIn())
  {
    dagor.debug("Invite rejected: player is already in flight or in loading level or in unloading level");
    return false;
  }

  local senderId = ("senderId" in params)? params.senderId : null
  local password = ::getTblValue("password", params, null)
  if (!senderId) //querry room
    ::SessionLobby.joinRoom(params.roomId, senderId, password)
  else
    ::g_invites.addSessionRoomInvite(params.roomId, senderId.tostring(), params.senderName, password)
  return true
}

::notify_room_destroyed <- function notify_room_destroyed(params)
{
  dagor.debug("notify_room_destroyed")
  //debugTableData(params)

  ::SessionLobby.afterLeaveRoom(params)
}

::notify_room_member_joined <- function notify_room_member_joined(params)
{
  dagor.debug("notify_room_member_joined")
  //debugTableData(params)
  ::SessionLobby.onMemberJoin(params)
}

::notify_room_member_leaved <- function notify_room_member_leaved(params)
{
  dagor.debug("notify_room_member_leaved")
  ::SessionLobby.onMemberLeave(params)
}

::notify_room_member_kicked <- function notify_room_member_kicked(params)
{
  dagor.debug("notify_room_member_kicked")
  ::SessionLobby.onMemberLeave(params, true)
}

::notify_room_member_attribs_changed <- function notify_room_member_attribs_changed(params)
{
  dagor.debug("notify_room_member_attribs_changed")
  ::SessionLobby.onMemberInfoUpdate(params)
}

::notify_room_attribs_changed <- function notify_room_attribs_changed(params)
{
  dagor.debug("notify_room_attribs_changed")
  //debugTableData(params)

  ::SessionLobby.onSettingsChanged(params)
}

::notify_session_start <- function notify_session_start()
{
  local sessionId = ::get_mp_session_id()
  if (sessionId != "")
    ::LAST_SESSION_DEBUG_INFO = "sid:" + sessionId

  dagor.debug("notify_session_start")
  ::add_big_query_record("joining_session",
    ::save_to_json({
      gm = ::get_game_mode()
      sessionId = sessionId
      missionsComplete = ::my_stats.getMissionsComplete()
    }))
  ::SessionLobby.switchStatus(lobbyStates.JOINING_SESSION)
}

::SessionLobby <- {
  [PERSISTENT_DATA_PARAMS] = [
    "roomId", "settings", "uploadedMissionId", "status",
    "isRoomInSession", "isRoomOwner", "isRoomByQueue", "isEventRoom",
    "roomUpdated", "password", "members", "memberHostId",
    "spectator", "isReady", "isInLobbySession", "team", "countryData", "myState",
    "isSpectatorSelectLocked", "crsSetTeamTo", "curEdiff",
    "needJoinSessionAfterMyInfoApply", "isLeavingLobbySession", "_syncedMyInfo",
    "playersInfo", "overrideSlotbar", "overrrideSlotbarMissionName", "lastEventName, isReadyInSetStateRoom"
  ]

  settings = {}
  uploadedMissionId = ""
  status = lobbyStates.NOT_IN_ROOM
  isRoomInSession = false
  isRoomOwner = false
  isRoomByQueue = false
  isEventRoom = false
  roomId = INVALID_ROOM_ID
  lastEventName = ""
  roomUpdated = false
  password = ""

  overrideSlotbar = null
  overrrideSlotbarMissionName = "" //recalc slotbar only on mission change

  members = []
  memberDefaults = {
    team = Team.Any
    country = "country_0"
    spectator = false
    ready = false
    is_in_session = false
    clanTag = ""
    title = ""
    pilotId = 0
    selAirs = ""
    state = ::PLAYER_IN_LOBBY_NOT_READY
  }
  memberHostId = -1

  //my room attributes
  spectator = false
  isReady = false
  isInLobbySession = false //in some lobby session are used instead of ready
  team = Team.Any
  countryData = null
  myState = ::PLAYER_IN_LOBBY_NOT_READY
  isSpectatorSelectLocked = false
  crsSetTeamTo = Team.none
  curEdiff = -1

  _syncedMyInfo = null
  playersInfo = {}

  reconnectData = {
    inviteData = null
    sendResp = null
  }

  delayedJoinRoomFunc = null
  needJoinSessionAfterMyInfoApply = false
  isLeavingLobbySession = false

  isReadyInSetStateRoom = null // if null then not response is expected from room_set_ready_state

  roomTimers = [
    {
      publicKey = "timeToCloseByDisbalance"
      color = "@warningTextColor"
      function getLocText(public, locParams)
      {
        local res = ::loc("multiplayer/closeByDisbalance", locParams)
        if ("disbalanceType" in public)
          res += "\n" + ::loc("multiplayer/reason") + ::loc("ui/colon")
            + ::loc("roomCloseReason/" + public.disbalanceType)
        return res
      }
    }
    {
      publicKey = "matchStartTime"
      color = "@inQueueTextColor"
      function getLocText(public, locParams)
      {
        return ::loc("multiplayer/battleStartsIn", locParams)
      }
    }
  ]

  function getDifficulty(room = null)
  {
    local diffValue = getMissionData(room)?.difficulty
    local difficulty = (diffValue == "custom")
      ? ::g_difficulty.getDifficultyByDiffCode(::get_cd_base_difficulty())
      : ::g_difficulty.getDifficultyByName(diffValue)
    return difficulty
  }

  function getLockedCountryData() {
    if (crsSetTeamTo == Team.none)
      return null

    local availableCountries = getTeamData(crsSetTeamTo)?.countries ?? []
    if (availableCountries.len() == 0)
      return null

    return {
      availableCountries = availableCountries
      reasonText = ::loc("multiplayer/cantChangeCountryInLobby", {
        availableCountries = "".concat(::loc("available_countries"), ::loc("ui/colon"),
          ::loc("ui/comma").join(availableCountries.map(@(c) ::loc(c))))
      })
    }
  }
}

SessionLobby.setIngamePresence <- function setIngamePresence(roomPublic, roomId)
{
  local team = 0
  local myPinfo = getMemberPlayerInfo(::my_user_id_int64)
  if (myPinfo != null)
    team = myPinfo.team

  local inGamePresence = {
    gameModeId = ::getTblValue("game_mode_id", roomPublic)
    gameQueueId = ::getTblValue("game_queue_id", roomPublic)
    mission    = ::getTblValue("mission", roomPublic)
    roomId     = roomId
    team       = team
  }
  ::g_user_presence.setPresence({in_game_ex = inGamePresence})
}


SessionLobby.isInRoom <- function isInRoom()
{
  return status != lobbyStates.NOT_IN_ROOM
    && status != lobbyStates.WAIT_FOR_QUEUE_ROOM
    && status != lobbyStates.CREATING_ROOM
    && status != lobbyStates.JOINING_ROOM
}

SessionLobby.isWaitForQueueRoom <- function isWaitForQueueRoom()
{
  return status == lobbyStates.WAIT_FOR_QUEUE_ROOM
}

SessionLobby.setWaitForQueueRoom <- function setWaitForQueueRoom(set)
{
  if (status == lobbyStates.NOT_IN_ROOM || status == lobbyStates.WAIT_FOR_QUEUE_ROOM)
    switchStatus(set? lobbyStates.WAIT_FOR_QUEUE_ROOM : lobbyStates.NOT_IN_ROOM)
}

SessionLobby.leaveWaitForQueueRoom <- function leaveWaitForQueueRoom()
{
  if (!isWaitForQueueRoom())
    return

  setWaitForQueueRoom(false)
  ::g_popups.add(null, ::loc("NET_CANNOT_ENTER_SESSION"))
}

SessionLobby.findParam <- function findParam(key, tbl1, tbl2)
{
  if (key in tbl1)
    return tbl1[key]
  if (key in tbl2)
    return tbl2[key]
  return null
}

SessionLobby.validateMissionCountry <- function validateMissionCountry(country, fullCountriesList)
{
  if (::isInArray(country, fullCountriesList))
    return null
  if (::isInArray("country_" + country, fullCountriesList))
    return "country_" + country
  return null
}

SessionLobby.prepareSettings <- function prepareSettings(missionSettings)
{
  local _settings = {}
  local mission = missionSettings.mission

  foreach(key, v in allowed_mission_settings)
  {
    if (key == "mission")
      continue
    local value = findParam(key, missionSettings, mission)
    if (typeof(v) == "array" && typeof(value) != "array")
      value = [value]
    _settings[key] <- value //value == null will clear param on server
  }

  _settings.mission <- {}
  foreach(key, v in allowed_mission_settings.mission)
  {
    local value = findParam(key, mission, missionSettings)
    if (key == "postfix")
      value = ::getTblValue(key, missionSettings)
    if (value==null)
      continue

    _settings.mission[key] <- ::u.isDataBlock(value) ? ::buildTableFromBlk(value) : value
  }

  _settings.creator <- ::my_user_name
  _settings.mission.originalMissionName <- ::getTblValue("name", _settings.mission, "")
  if ("postfix" in _settings.mission && _settings.mission.postfix)
  {
    local ending = "_tm"
    local nameNoTm = _settings.mission.name
    if (nameNoTm.len() > ending.len() && nameNoTm.slice(nameNoTm.len()-ending.len())==ending)
      nameNoTm = nameNoTm.slice(0, nameNoTm.len()-ending.len())
    _settings.mission.loc_name = nameNoTm + _settings.mission.postfix
    _settings.mission.name += _settings.mission.postfix
  }
  if (::is_user_mission(mission))
    _settings.userMissionName <- ::loc("missions/" + mission.name)
  if (!("_gameMode" in _settings.mission))
    _settings.mission._gameMode <- ::get_game_mode()
  if (!("_gameType" in _settings.mission))
    _settings.mission._gameType <- ::get_game_type()
  if (::getTblValue("coop", _settings) == null)
    _settings.coop <- ::is_gamemode_coop(_settings.mission._gameMode)
  if (("difficulty" in _settings.mission) && _settings.mission.difficulty == "custom")
    _settings.mission.custDifficulty <- ::get_cd_preset(::DIFFICULTY_CUSTOM)

  //validate Countries
  local countriesType = ::getTblValue("countriesType", missionSettings, misCountries.ALL)
  local fullCountriesList = ::g_crews_list.getSlotbarOverrideCountriesByMissionName(_settings.mission.originalMissionName)
  if (!fullCountriesList.len())
    fullCountriesList = clone ::shopCountriesList
  foreach(name in ["country_allies", "country_axis"])
  {
    local countries = null
    if (countriesType == misCountries.BY_MISSION)
    {
      countries = ::getTblValue(name, _settings, [])
      for(local i=countries.len()-1; i>=0; i--)
      {
        countries[i] = validateMissionCountry(countries[i], fullCountriesList)
        if (!countries[i])
          countries.remove(i)
      }
    } else if (countriesType == misCountries.SYMMETRIC || countriesType == misCountries.CUSTOM)
    {
      local bitMaskKey = (countriesType == misCountries.SYMMETRIC)? "country_allies" : name
      countries = ::get_array_by_bit_value(::getTblValue(bitMaskKey + "_bitmask", missionSettings, 0), ::shopCountriesList)
    }
    _settings[name] <- (countries && countries.len())? countries : fullCountriesList
  }

  local userAllowedUnitTypesMask = missionSettings?.userAllowedUnitTypesMask ?? 0
  if (userAllowedUnitTypesMask)
    foreach (unitType in unitTypes.types)
      if (unitType.isAvailableByMissionSettings(_settings.mission) && !(userAllowedUnitTypesMask & unitType.bit))
        _settings.mission[unitType.missionSettingsAvailabilityFlag] = false

  local mrankMin = missionSettings?.mrankMin ?? 0
  local mrankMax = missionSettings?.mrankMax ?? ::MAX_ECONOMIC_RANK
  if (mrankMin > mrankMax)
  {
    local temp = mrankMin
    mrankMin = mrankMax
    mrankMax = temp
  }
  if (mrankMin > 0 || mrankMax < ::MAX_ECONOMIC_RANK)
    _settings.mranks <- { min = mrankMin, max = mrankMax }

  _settings.chatPassword <- isInRoom() ? getChatRoomPassword() : ::gen_rnd_password(16)
  if (!u.isEmpty(settings?.externalSessionId))
    _settings.externalSessionId <- settings.externalSessionId

  fillTeamsInfo(_settings, mission)

  checkDynamicSettings(true, _settings)
  setSettings(_settings)
}

SessionLobby.setExternalId <- function setExternalId(extId)
{
  if (settings?.externalSessionId == extId)
    return

  settings["externalSessionId"] <- extId
  ::set_room_attributes({roomId=roomId, public=settings}, @(p) ::SessionLobby.afterRoomUpdate(p))
}

SessionLobby.getExternalId <- function getExternalId()
{
  return settings?.externalSessionId
}

SessionLobby.setSettings <- function setSettings(_settings, notify = false, checkEqual = true)
{
  if (typeof _settings == "array")
  {
    ::dagor.debug("_settings param, public info, is array, instead of table")
    ::callstack()
    return
  }

  if (checkEqual && ::u.isEqual(settings, _settings))
    return

  //_settings can be publick date of room, and it does not need to be updated settings somewhere else
  settings = clone _settings
  //not mission room settings
  settings.connect_on_join <- !haveLobby()

  UpdateCrsSettings()
  UpdatePlayersInfo()
  updateOverrideSlotbar()

  curEdiff = calcEdiff(settings)

  roomUpdated = notify || !isRoomOwner || !isInRoom() || isEventRoom
  if (!roomUpdated)
    ::set_room_attributes({ roomId = roomId, public = settings }, function(p) { ::SessionLobby.afterRoomUpdate(p) })

  if (isInRoom())
    validateTeamAndReady()

  local newGm = getGameMode()
  if (newGm >= 0)
    ::set_mp_mode(newGm)

  ::broadcastEvent("LobbySettingsChange")
}

SessionLobby.UpdatePlayersInfo <- function UpdatePlayersInfo()
{
  // old format. players_info in lobby is array of objects for each player
  if ("players_info" in settings)
  {
    playersInfo = {}
    foreach (pinfo in settings.players_info)
      playersInfo[pinfo.id] <- pinfo
    return
  }

  // new format. player infos are separate values in rooms public table
  foreach (k, pinfo in settings)
  {
    if (k.indexof("pinfo_") != 0)
      continue
    local uid = k.slice(6).tointeger()
    if (pinfo == null)
    {
      if (uid in playersInfo)
        delete playersInfo[uid]
    }
    else
    {
      playersInfo[uid] <- pinfo
    }
  }
  ::SquadIcon.updatePlayersInfo()
}

SessionLobby.UpdateCrsSettings <- function UpdateCrsSettings()
{
  isSpectatorSelectLocked = false
  local userInUidsList = function(list_name)
  {
    local ids = ::getTblValue(list_name, getSessionInfo())
    if (::u.isArray(ids))
      return ::isInArray(::my_user_id_int64, ids)
    return false
  }

  if (userInUidsList("referees") || userInUidsList("spectators"))
  {
    isSpectatorSelectLocked = true
    setSpectator(isSpectatorSelectLocked)
  }

  crsSetTeamTo = Team.none
  foreach (team in ::events.getSidesList())
  {
    local players = getSessionInfo()?[::events.getTeamName(team)].players
    if (!::u.isArray(players))
      continue

    foreach(uid in players)
      if (is_my_userid(uid))
      {
        crsSetTeamTo = team
        break
      }

    if (crsSetTeamTo != Team.none)
      break
  }
}

SessionLobby.fillTeamsInfo <- function fillTeamsInfo(_settings, misBlk)
{
  //!!fill simmetric teams data
  local teamData = {}
  teamData.allowedCrafts <- []

  foreach (unitType in unitTypes.types)
    if (unitType.isAvailableByMissionSettings(_settings.mission))
    {
      local rule = { ["class"] = unitType.getMissionAllowedCraftsClassName() }
      if (_settings?.mranks)
        rule.mranks <- _settings.mranks
      teamData.allowedCrafts.append(rule)
    }

  //!!fill assymetric teamdata
  local teamDataA = teamData
  local teamDataB = clone teamData

  //in future better to comletely remove old countries selection, and use only countries in teamData
  teamDataA.countries <- _settings.country_allies
  teamDataB.countries <- _settings.country_axis

  addTeamsInfoToSettings(_settings, teamDataA, teamDataB)
}

SessionLobby.addTeamsInfoToSettings <- function addTeamsInfoToSettings(_settings, teamDataA, teamDataB)
{
  _settings[::events.getTeamName(Team.A)] <- teamDataA
  _settings[::events.getTeamName(Team.B)] <- teamDataB
}

SessionLobby.checkDynamicSettings <- function checkDynamicSettings(silent = false, _settings = null)
{
  if (!isRoomOwner && isInRoom())
    return

  if (!_settings)
  {
    if (!settings || !settings.len())
      return //owner have joined back to the room, and not receive settings yet
    _settings = settings
  } else
    silent = true //no need to update when custom settings checked

  local changed = false
  local wasHidden = ::getTblValue("hidden", _settings, false)
  _settings.hidden <- ::getTblValue("coop", _settings, false)
                      || (isRoomInSession && !::getTblValue("allowJIP", _settings, true))
  changed = changed || (wasHidden != _settings.hidden) // warning disable: -const-in-bool-expr

  local wasPassword = ::getTblValue("hasPassword", _settings, false)
  _settings.hasPassword <- password != ""
  changed = changed || (wasPassword != _settings.hasPassword)

  if (changed && !silent)
    setSettings(settings, false, false)
}

SessionLobby.onSettingsChanged <- function onSettingsChanged(p)
{
  if (roomId!=p.roomId)
    return
  local set = ::getTblValue("public", p)
  if (!set)
    return

  if ("last_round" in set)
  {
    ::last_round = set.last_round
    dagor.debug("last round " + ::last_round)
  }

  local newSet = clone settings
  foreach (k, v in set)
    if (v == null)
    {
      if (k in newSet)
        delete newSet[k]
    }
    else
      newSet[k] <- v

  setSettings(newSet, true)

  setRoomInSession(isSessionStartedInRoom())
}

SessionLobby.setRoomInSession <- function setRoomInSession(newIsInSession)
{
  if (newIsInSession==isRoomInSession)
    return

  isRoomInSession = newIsInSession
  if (!isInRoom())
    return

  ::broadcastEvent("LobbyRoomInSession")
  if (isRoomOwner)
    checkDynamicSettings()
}

SessionLobby.isCoop <- function isCoop()
{
  return ("coop" in settings)? settings.coop : false
}

SessionLobby.haveLobby <- function haveLobby()
{
  local gm = getGameMode()
  if (gm == ::GM_SKIRMISH)
    return true
  if (gm == ::GM_DOMINATION)
    return ::events.isEventWithLobby(getRoomEvent())
  return false
}

SessionLobby.needJoiningWnd <- function needJoiningWnd()
{
  return ::isInArray(status,
    [lobbyStates.WAIT_FOR_QUEUE_ROOM, lobbyStates.CREATING_ROOM, lobbyStates.JOINING_ROOM,
     lobbyStates.IN_ROOM, lobbyStates.IN_LOBBY_HIDDEN,
     lobbyStates.UPLOAD_CONTENT, lobbyStates.START_SESSION, lobbyStates.JOINING_SESSION
    ])
}

SessionLobby.getSessionInfo <- function getSessionInfo()
{
  return settings
}

SessionLobby.getMissionName <- function getMissionName(isOriginalName = false, room = null)
{
  local misData = getMissionData(room)
  return (isOriginalName && ::getTblValue("originalMissionName", misData))
         || ::getTblValue("name", misData, "")
}

SessionLobby.getMissionNameLoc <- function getMissionNameLoc(room = null)
{
  local misData = getMissionData(room)
  if ("name" in misData)
    return ::get_combine_loc_name_mission(::get_mission_meta_info(misData.name))
  return ""
}

SessionLobby.getPublicData <- function getPublicData(room = null)
{
  return room? (("public" in room)? room.public : room) : settings
}

SessionLobby.getMissionData <- function getMissionData(room = null)
{
  return ::getTblValue("mission", getPublicData(room))
}

SessionLobby.getGameMode <- function getGameMode(room = null)
{
  return ::getTblValue("_gameMode", getMissionData(room), ::GM_DOMINATION)
}

SessionLobby.getGameType <- function getGameType(room = null)
{
  local res = ::getTblValue("_gameType", getMissionData(room), 0)
  return ::u.isInteger(res) ? res : 0
}

SessionLobby.getMGameModeId <- function getMGameModeId(room = null) //gameModeId by g_matching_game_modes
{
  return ::getTblValue("game_mode_id", getPublicData(room))
}

SessionLobby.getClusterName <- function getClusterName(room = null) //gameModeId by g_matching_game_modes
{
  local cluster = ::getTblValue("cluster", room)
  if (cluster == null)
    cluster = ::getTblValue("cluster", getPublicData(room))
  return cluster || ""
}

SessionLobby.getMaxRespawns <- function getMaxRespawns(room = null)
{
  return ::getTblValue("maxRespawns", getMissionData(room), 0)
}

SessionLobby.getTimeLimit <- function getTimeLimit(room = null)
{
  local timeLimit = ::getTblValue("timeLimit", getMissionData(room), 0)
  if (timeLimit)
    return timeLimit

  local missionName = getMissionName(true, room)
  if (!missionName)
    return timeLimit

  local misData = ::get_meta_mission_info_by_name(missionName)
  timeLimit = ::getTblValue("timeLimit", misData, 0)
  return timeLimit
}

//need only for  event roomsList, because other rooms has full rules list in public
//return null when no such rules
SessionLobby.getRoomSpecialRules <- function getRoomSpecialRules(room = null)
{
  return null //now all data come in room teamData even in list. But maybe this mehanism will be used in future.
}

SessionLobby.getTeamData <- function getTeamData(teamCode, room = null)
{
  return ::events.getTeamData(getPublicData(room), teamCode)
}

SessionLobby.getRequiredCrafts <- function getRequiredCrafts(teamCode = Team.A, room = null)
{
  local teamData = getTeamData(teamCode, room)
  return ::events.getRequiredCrafts(teamData)
}

SessionLobby.getRoomSessionStartTime <- function getRoomSessionStartTime(room = null)
{
  return ::getTblValue("matchStartTime", getPublicData(room), 0)
}

SessionLobby.getUnitTypesMask <- function getUnitTypesMask(room = null)
{
  return ::events.getEventUnitTypesMask(getMGameMode(room) || getPublicData(room))
}

SessionLobby.getRequiredUnitTypesMask <- function getRequiredUnitTypesMask(room = null)
{
  return ::events.getEventRequiredUnitTypesMask(getMGameMode(room) || getPublicData(room))
}

SessionLobby.getNotAvailableUnitByBRText <- function getNotAvailableUnitByBRText(unit, room = null)
{
  if (!unit)
    return null

  local mGameMode = getMGameMode(room)
  if (!mGameMode)
    return null

  local curBR = unit.getBattleRating(::is_in_flight()
    ? ::get_mission_difficulty_int()
    : ::get_current_shop_difficulty().diffCode)
  local maxBR = (getBattleRatingParamByPlayerInfo(getMemberPlayerInfo(::my_user_id_int64),
    ::ES_UNIT_TYPE_SHIP)?.units?[0]?.rating ?? 0) + MAX_BR_DIFF_AVAILABLE_AND_REQ_UNITS
  return (::events.isUnitTypeRequired(mGameMode, ::ES_UNIT_TYPE_SHIP)
    && unit.esUnitType == ::ES_UNIT_TYPE_AIRCRAFT
    && ((curBR - maxBR)*10).tointeger() >= 0)
      ? ::loc("not_available_aircraft/byBR", {
          gameModeName = ::events.getEventNameText(mGameMode),
          lockedUnitType = ::colorize("userlogColoredText",
            ::loc("mainmenu/type_" + unit.unitType.lowerName)),
          battleRatingDiff = ::colorize("userlogColoredText", ::format("%.1f", MAX_BR_DIFF_AVAILABLE_AND_REQ_UNITS)),
          reqUnitType = ::colorize("userlogColoredText", ::loc("mainmenu/type_ship"))
        })
      : null
}

SessionLobby.calcEdiff <- function calcEdiff(room = null)
{
  return getDifficulty(room).getEdiffByUnitMask(getUnitTypesMask(room))
}

SessionLobby.getCurRoomEdiff <- function getCurRoomEdiff()
{
  return curEdiff
}

SessionLobby.getMissionParam <- function getMissionParam(name, defValue = "")
{
  if (("mission" in settings) && (name in settings.mission))
    return settings.mission[name]
  return defValue
}

SessionLobby.getPublicParam <- function getPublicParam(name, defValue = "")
{
  if (name in settings)
    return settings[name]
  return defValue
}

SessionLobby.getMissionParams <- function getMissionParams()
{
  if (!isInRoom())
    return null
  return ("mission" in settings)? settings.mission : null
}

SessionLobby.getOperationId <- function getOperationId()
{
  if (!isInRoom())
    return -1
  return (getMissionParams()?.customRules?.operationId ?? -1).tointeger()
}

SessionLobby.getWwBattleId <- function getWwBattleId()
{
  if (!isInRoom())
    return ""
  return (getMissionParams()?.customRules?.battleId ?? "")
}

SessionLobby.getTeamsCountries <- function getTeamsCountries(room = null)
{
  local res = []
  local hasCountries = false
  foreach(t in [Team.A, Team.B])
  {
    local teamData = getTeamData(t, room)
    local countries = ::events.getCountries(teamData)
    res.append(countries)
    hasCountries = hasCountries || countries.len()
  }

  if (hasCountries)
    return res
  //!!FIX ME: is we need a code below? But better to do something with it only with a s.zvyagin
  local mGameMode = getMGameMode(room)
  if (mGameMode)
    return ::events.getCountriesByTeams(mGameMode)

  local pData = getPublicData(room)
  foreach(idx, name in ["country_allies", "country_axis"])
    if (name in pData)
      res[idx] = pData[name]
  return res
}

SessionLobby.switchStatus <- function switchStatus(_status)
{
  if (status == _status)
    return

  local wasInRoom = isInRoom()
  local wasStatus = status
  status = _status  //for easy notify other handlers about change status
  //dlog("GP: status changed to " + ::getEnumValName("lobbyStates", status))
  if (needJoiningWnd())
    ::gui_modal_joiningGame()
  if (status == lobbyStates.IN_LOBBY)
  {
    //delay to allow current view handlers to catch room state change event before destroy
    local guiScene = ::get_main_gui_scene()
    if (guiScene)
      guiScene.performDelayed(this, ::gui_start_mp_lobby)
  }

  if (status == lobbyStates.IN_DEBRIEFING && hasSessionInLobby())
    leaveEventSessionWithRetry()

  if (status == lobbyStates.NOT_IN_ROOM || status == lobbyStates.IN_DEBRIEFING)
    setReady(false, true)
  if (status == lobbyStates.NOT_IN_ROOM)
  {
    resetParams()
    if (wasStatus == lobbyStates.JOINING_SESSION)
      ::destroy_session_scripted()
  }
  if (status == lobbyStates.JOINING_SESSION)
    ::add_squad_to_contacts()

  if (status == lobbyStates.JOINING_SESSION ||
    status == lobbyStates.IN_SESSION)
    lastEventName = getRoomEvent()?.name ?? ""

  updateMyState()

  ::broadcastEvent("LobbyStatusChange")
  if (wasInRoom != isInRoom())
  {
    ::broadcastEvent("LobbyIsInRoomChanged")
    ::call_darg("networkIsMultiplayerUpdate", isInRoom())
  }
}

SessionLobby.resetParams <- function resetParams()
{
  settings.clear()
  changePassword("") //reset password after leave room
  updateMemberHostParams(null)
  team = Team.Any
  isRoomByQueue = false
  isEventRoom = false
  myState = ::PLAYER_IN_LOBBY_NOT_READY
  roomUpdated = false
  spectator = false
  _syncedMyInfo = null
  needJoinSessionAfterMyInfoApply = false
  isLeavingLobbySession = false
  playersInfo.clear()
  if (overrideSlotbar != null) {
    overrideSlotbar = null
    ::broadcastEvent("OverrideSlotbarChanged")
  }
  overrrideSlotbarMissionName = ""
  ::g_user_presence.setPresence({in_game_ex = null})
}

SessionLobby.resetPlayersInfo <- function resetPlayersInfo()
{
  playersInfo.clear()
}

SessionLobby.switchStatusChecked <- function switchStatusChecked(oldStatusList, newStatus)
{
  if (::isInArray(status, oldStatusList))
    switchStatus(newStatus)
}

SessionLobby.changePassword <- function changePassword(_password)
{
  if (typeof(_password)!="string" || password==_password)
    return

  if (isRoomOwner && status != lobbyStates.NOT_IN_ROOM && status != lobbyStates.CREATING_ROOM)
  {
    local prevPass = password
    ::room_set_password({ roomId = roomId, password = _password },
      (@(prevPass) function(p) {
        if (!::checkMatchingError(p))
        {
          ::SessionLobby.password = prevPass
          ::SessionLobby.checkDynamicSettings()
        }
      })(prevPass))
  }
  password = _password
}

SessionLobby.getMisListType <- function getMisListType(_settings = null)
{
  if (isUserMission(_settings))
    return ::g_mislist_type.UGM
  if (isUrlMission(_settings))
    return ::g_mislist_type.URL
  return ::g_mislist_type.BASE
}

SessionLobby.isUserMission <- function isUserMission(_settings = null)
{
  return ::getTblValue("userMissionName", _settings || settings) != null
}

SessionLobby.isUrlMission <- function isUrlMission(room = null)
{
  return getMissionUrl(room) != ""
}

SessionLobby.getMissionUrl <- function getMissionUrl(room = null)
{
  return getPublicData(room)?.missionURL ?? ""
}

SessionLobby.isMissionReady <- function isMissionReady()
{
  return !isUserMission() ||
         (status != lobbyStates.UPLOAD_CONTENT && uploadedMissionId == getMissionName())
}

SessionLobby.uploadUserMission <- function uploadUserMission(afterDoneFunc = null)
{
  if (!isInRoom() || !isUserMission() || status == lobbyStates.UPLOAD_CONTENT)
    return
  if (uploadedMissionId == getMissionName()) {
    afterDoneFunc?()
    return
  }

  local missionId = getMissionName()
  local missionInfo = ::DataBlock()
  missionInfo.setFrom(::get_mission_meta_info(missionId))
  local missionBlk = missionInfo && missionInfo.mis_file && ::DataBlock(missionInfo.mis_file)
  //dlog("GP: upload mission!")
  //debugTableData(missionBlk)

  local blkData = missionBlk && ::pack_blk_to_base64(missionBlk)
  //dlog("GP: data = " + blkData)
  //debugTableData(blkData)
  if (!blkData || !("result" in blkData) || !blkData.result.len())
  {
    ::showInfoMsgBox(::loc("msg/cant_load_user_mission"))
    return
  }

  switchStatus(lobbyStates.UPLOAD_CONTENT)
  ::set_room_attributes({ roomId = roomId, private = { userMission = blkData.result } },
                        (@(missionId, afterDoneFunc) function(p) {
                          if (!::checkMatchingError(p)) {
                            ::SessionLobby.returnStatusToRoom()
                            return
                          }
                          ::SessionLobby.uploadedMissionId = missionId
                          ::SessionLobby.returnStatusToRoom()
                          if (afterDoneFunc)
                            afterDoneFunc()
                        })(missionId, afterDoneFunc))
}

SessionLobby.mergeTblChanges <- function mergeTblChanges(tblBase, tblNew)
{
  if (tblNew == null)
    return tblBase

  foreach(key, value in tblNew)
    if (value!=null)
      tblBase[key] <- value
    else if (key in tblBase)
      delete tblBase[key]
  return tblBase
}

::updateMemberHostParams <- function updateMemberHostParams(member = null) //null = host leave
{
  memberHostId = member ? member.memberId : -1
}


SessionLobby.updateReadyAndSyncMyInfo <- function updateReadyAndSyncMyInfo(ready)
{
  isReady = ready
  syncMyInfo({state = updateMyState(true)})
  broadcastEvent("LobbyReadyChanged")
}

SessionLobby.onMemberInfoUpdate <- function onMemberInfoUpdate(params)
{
  if (params.roomId != roomId)
    return
  if (isMemberHost(params))
    return updateMemberHostParams(params)

  local member = null
  foreach(m in members)
    if (m.memberId == params.memberId)
    {
      member = m
      break
    }
  if (!member)
    return

  foreach(tblName in ["public", "private"])
    if (tblName in params)
      if (tblName in member)
        mergeTblChanges(member[tblName], params[tblName])
      else
        member[tblName] <- params[tblName]

  if (is_my_userid(member.userId))
  {
    isRoomOwner = isMemberOperator(member)
    isInLobbySession = isMemberInSession(member)
    initMyParamsByMemberInfo(member)
    local ready = ::getTblValue("ready", ::getTblValue("public", member, {}), null)
    if (!hasSessionInLobby() && ready != null && ready != isReady)
      updateReadyAndSyncMyInfo(ready)
    else if (needJoinSessionAfterMyInfoApply)
      tryJoinSession(true)
    needJoinSessionAfterMyInfoApply = false
  }
  broadcastEvent("LobbyMemberInfoChanged")
}

SessionLobby.initMyParamsByMemberInfo <- function initMyParamsByMemberInfo(me = null)
{
  if (!me)
    me = ::u.search(members, function(m) { return is_my_userid(m.userId) })
  if (!me)
    return

  local myTeam = getMemberPublicParam(me, "team")
  if (myTeam != Team.Any && myTeam != team)
    team = myTeam

  if (myTeam == Team.Any)
    validateTeamAndReady()
}

SessionLobby.syncMyInfo <- function syncMyInfo(newInfo, reqUpdateMatchingSlots = false)
{
  if (::isInArray(status, [lobbyStates.NOT_IN_ROOM, lobbyStates.WAIT_FOR_QUEUE_ROOM, lobbyStates.CREATING_ROOM, lobbyStates.JOINING_ROOM])
      || !haveLobby()
      || isLeavingLobbySession)
    return

  local syncData = newInfo
  if (!_syncedMyInfo)
    _syncedMyInfo = newInfo
  else
  {
    syncData = {}
    foreach(key, value in newInfo)
    {
      if (key in _syncedMyInfo)
      {
        if (_syncedMyInfo[key] == value)
          continue
        if (typeof(value)=="array" || typeof(value)=="table")
          if (::u.isEqual(_syncedMyInfo[key], value))
            continue
      }
      syncData[key] <- value
      _syncedMyInfo[key] <- value
    }
  }

  // DIRTY HACK: Server ignores spectator=true flag if it is sent before pressing Ready button,
  // when Referee joins into already started Skirmish mission.
  if (::getTblValue("state", newInfo) == lobbyStates.IN_ROOM)
    syncData.spectator <- ::getTblValue("spectator", _syncedMyInfo, false)

  local info = {
    roomId = roomId
    public = syncData
  }

  // Sends info to server
  ::set_member_attributes(info, (@(reqUpdateMatchingSlots) function(p) {
    if (reqUpdateMatchingSlots)
      checkUpdateMatchingSlots()
  })(reqUpdateMatchingSlots).bindenv(this))
  ::broadcastEvent("LobbyMyInfoChanged", syncData)
}

SessionLobby.syncAllInfo <- function syncAllInfo()
{
  local myInfo = get_profile_info()
  local myStats = ::my_stats.getStats()

  syncMyInfo({
    team = team
    country = countryData ? countryData.country : null
    selAirs = countryData ? countryData.selAirs : null
    slots = countryData ? countryData.slots : null
    spectator = spectator
    clanTag = get_profile_info().clanTag
    title = myStats ? myStats.title : ""
    pilotId = myInfo.pilotId
    state = updateMyState(true)
  })
}

SessionLobby.getMemberState <- function getMemberState(member)
{
  return getMemberPublicParam(member, "state")
}

SessionLobby.getMemberPublicParam <- function getMemberPublicParam(member, param)
{
  return (("public" in member) && (param in member.public))? member.public[param] : memberDefaults[param]
}

SessionLobby.isMemberInSession <- function isMemberInSession(member)
{
  return getMemberPublicParam(member, "is_in_session")
}

SessionLobby.isMemberReady <- function isMemberReady(member)
{
  return getMemberPublicParam(member, "ready")
}

SessionLobby.getMemberInfo <- function getMemberInfo(member)
{
  if (!member)
    return null

  local pub = ("public" in member)? member.public : {}
  local res = {
    memberId = member.memberId
    userId = member.userId.tostring() //member info same format as get_mplayers_list
    name = member.name
    isLocal = is_my_userid(member.userId)
    spectator = ::getTblValue("spectator", member, false)
    isBot = false
  }
  foreach(key, value in memberDefaults)
    res[key] <- (key in pub)? pub[key] : value

  if (hasSessionInLobby())
  {
    if (res.state == ::PLAYER_IN_LOBBY_NOT_READY || res.state == ::PLAYER_IN_LOBBY_READY)
      res.state = isMemberInSession(member) ? ::PLAYER_IN_LOBBY_READY : ::PLAYER_IN_LOBBY_NOT_READY
  }
  else if (!isUserCanChangeReady() && res.state == ::PLAYER_IN_LOBBY_NOT_READY)
    res.state = ::PLAYER_IN_LOBBY_READY //player cant change ready self, and will go to battle event when no ready.
  return res
}

SessionLobby.getMemberByName <- function getMemberByName(userName, room = null)
{
  if (userName == "")
    return null
  foreach (key, member in getRoomMembers(room))
    if (member.name == userName)
      return member
  return null
}

SessionLobby.getMembersInfoList <- function getMembersInfoList(room = null)
{
  local res = []
  foreach(member in getRoomMembers(room))
    res.append(getMemberInfo(member))
  return res
}

SessionLobby.updateMyState <- function updateMyState(silent = false)
{
  local newState = ::PLAYER_IN_LOBBY_NOT_READY
  if (status == lobbyStates.IN_LOBBY || status == lobbyStates.START_SESSION)
    newState = isReady? ::PLAYER_IN_LOBBY_READY : ::PLAYER_IN_LOBBY_NOT_READY
  else if (status == lobbyStates.IN_LOBBY_HIDDEN)
    newState = ::PLAYER_IN_LOBBY_READY
  else if (status == lobbyStates.IN_SESSION)
    newState = ::PLAYER_IN_FLIGHT
  else if (status == lobbyStates.IN_DEBRIEFING)
    newState = ::PLAYER_IN_STATISTICS_BEFORE_LOBBY

  local changed = myState!=newState
  myState = newState
  if (!silent && changed)
    syncMyInfo({state = updateMyState(true)})
  return myState
}

SessionLobby.setReady <- function setReady(ready, silent = false, forceRequest = false) //return is my info changed
{
  if (!forceRequest && isReady == ready)
    return false
  if (ready && !canSetReady(silent))
  {
    if (isReady)
      ready = false
    else
      return false
  }

  if (!isInRoom())
  {
    isReady = false
    return ready
  }

  isReadyInSetStateRoom = ready
  ::room_set_ready_state(
    {state = ready, roomId = roomId},
    (@(silent, ready) function(p) {
      isReadyInSetStateRoom = null
      if (!isInRoom())
      {
        isReady = false
        return
      }

      local wasReady = isReady
      local needUpdateState = !silent
      isReady = ready

      //if we receive error on set ready, result is ready == false always.
      if (!::checkMatchingError(p, !silent))
      {
        isReady = false
        needUpdateState = true
      }

      if (isReady == wasReady)
        return

      if (needUpdateState)
        syncMyInfo({state = updateMyState(true)})
      ::broadcastEvent("LobbyReadyChanged")
    })(silent, ready).bindenv(this))
  return true
}

//matching update slots from char when ready flag set to true
SessionLobby.checkUpdateMatchingSlots <- function checkUpdateMatchingSlots()
{
  if (hasSessionInLobby())
  {
    if (isInLobbySession)
      joinEventSession(false, { update_profile = true })
  } else if (isReady && (isReadyInSetStateRoom == null || isReadyInSetStateRoom))
    setReady(isReady, true, true)
}

SessionLobby.getAvailableTeam <- function getAvailableTeam()
{
  if (spectator)
    return (crsSetTeamTo == Team.none) ? Team.Any : crsSetTeamTo

  local myCountry = ::get_profile_country_sq()
  local aTeams = [crsSetTeamTo != Team.B, //Team.A or Team.none
                  crsSetTeamTo != Team.A
                 ]

  local teamsCountries = getTeamsCountries()
  foreach(idx, value in aTeams)
    if (!::isInArray(myCountry, ::getTblValue(idx, teamsCountries, teamsCountries[0])))
      aTeams[idx] = false

  local canPlayTeam = 0
  if (aTeams[0])
    canPlayTeam = aTeams[1]? Team.Any : Team.A
  else
    canPlayTeam = aTeams[1]? Team.B : Team.none
  return canPlayTeam
}

SessionLobby.checkMyTeam <- function checkMyTeam() //returns changed data
{
  local data = {}

  if (!haveLobby())
    return data

  local setTeamTo = team
  if (getAvailableTeam() == Team.none)
  {
    if (setReady(false, true))
      data.state <- updateMyState(true)
    setTeamTo = crsSetTeamTo
  }

  if (setTeamTo != Team.none && setTeam(setTeamTo, true))
  {
    data.team <- team
    local myCountry = ::get_profile_country_sq()
    local availableCountries = getTeamData(team)?.countries ?? []
    if (availableCountries.len() > 0 && !::isInArray(myCountry, availableCountries))
      ::switch_profile_country(availableCountries[0])
  }
  return data
}

SessionLobby.canChangeTeam <- function canChangeTeam()
{
  if (!haveLobby() || isEventRoom)
    return false
  local canPlayTeam = getAvailableTeam()
  return canPlayTeam == Team.Any
}


SessionLobby.switchTeam <- function switchTeam(skipTeamAny = false)
{
  if (!canChangeTeam())
    return false

  local newTeam = team + 1
  if (newTeam >= Team.none)
    newTeam = skipTeamAny ? 1 : 0
  return setTeam(newTeam)
}

SessionLobby.setTeam <- function setTeam(newTeam, silent = false) //return is team changed
{
  local _team = newTeam
  local canPlayTeam = getAvailableTeam()

  if (canPlayTeam == Team.A || canPlayTeam == Team.B)
    _team = canPlayTeam

  if (team == _team)
    return false

  team = _team

  if (!silent)
    syncMyInfo({team = team}, true)

  return true
}

SessionLobby.canBeSpectator <- function canBeSpectator()
{
  if (!::has_feature("Spectator"))
    return false
  if (getGameMode() != ::GM_SKIRMISH) //spectator only for skirmish mode
    return false
  return true
}

SessionLobby.switchSpectator <- function switchSpectator()
{
  if (!canBeSpectator() && !spectator)
    return false

  local newSpectator = !spectator
  return setSpectator(newSpectator)
}

SessionLobby.setSpectator <- function setSpectator(newSpectator) //return is spectator changed
{
  if (!canBeSpectator())
    newSpectator = false
  if (spectator == newSpectator)
    return false

  spectator = newSpectator
  syncMyInfo({spectator=spectator}, true)
  return true
}

SessionLobby.setCountryData <- function setCountryData(data) //return is data changed
{
  local changed = !countryData || !::u.isEqual(countryData, data)
  countryData = data
  local teamDataChanges = checkMyTeam()
  changed = changed || teamDataChanges.len() > 0
  if (!changed)
    return false

  foreach (i, v in teamDataChanges)
    data[i] <- v
  syncMyInfo(data, true)
  return true
}

SessionLobby.validateTeamAndReady <- function validateTeamAndReady()
{
  local teamDataChanges = checkMyTeam()
  if (!teamDataChanges.len())
  {
    if (isReady && !canSetReady(true))
      setReady(false)
    return
  }
  syncMyInfo(teamDataChanges, true)
}

SessionLobby.canSetReady <- function canSetReady(silent)
{
  if (spectator)
    return true

  local curCountry = ::getTblValue("country", countryData)
  if (::tanksDriveGamemodeRestrictionMsgBox("TanksInCustomBattles", curCountry, null, "cbt_tanks/forbidden/skirmish"))
    return false

  local availTeam = getAvailableTeam()
  if (availTeam == Team.none)
  {
    if (!silent)
      ::showInfoMsgBox(::loc("events/no_selected_country"))
    return false
  }

  local checkUnitsResult = checkUnitsInSlotbar(curCountry, availTeam)
  local res = checkUnitsResult.isAvailable
  if (!res && !silent)
    ::showInfoMsgBox(checkUnitsResult.reasonText)

  return res
}

SessionLobby.isUserCanChangeReady <- function isUserCanChangeReady()
{
  return !hasSessionInLobby()
}

SessionLobby.canChangeSettings <- function canChangeSettings()
{
  return !isEventRoom && isRoomOwner
}

SessionLobby.canStartSession <- function canStartSession()
{
  return !isEventRoom && isRoomOwner
}

SessionLobby.canChangeCrewUnits <- function canChangeCrewUnits()
{
  return !isEventRoom || !isRoomInSession
}

SessionLobby.canChangeCountry <- function canChangeCountry()
{
  return !isInRoom() || !isEventRoom
}

SessionLobby.canInviteIntoSession <- function canInviteIntoSession()
{
  return isInRoom() && getGameMode() == ::GM_SKIRMISH
}

SessionLobby.isInvalidCrewsAllowed <- function isInvalidCrewsAllowed()
{
  return !isInRoom() || !isEventRoom
}

SessionLobby.isMpSquadChatAllowed <- function isMpSquadChatAllowed()
{
  return getGameMode() != ::GM_SKIRMISH
}

SessionLobby.startCoopBySquad <- function startCoopBySquad(missionSettings)
{
  if (status != lobbyStates.NOT_IN_ROOM)
    return false

  prepareSettings(missionSettings)

  ::create_room({ size = 4, public = settings }, function(p) { ::SessionLobby.afterRoomCreation(p) })
  switchStatus(lobbyStates.CREATING_ROOM)
  return true
}

SessionLobby.createRoom <- function createRoom(missionSettings)
{
  if (status != lobbyStates.NOT_IN_ROOM)
    return false

  prepareSettings(missionSettings)

  local initParams = {
    size = getMaxMembersCount()
    public = settings
  }
  if (password && password!="")
    initParams.password <- password
  local blacklist = getContactsGroupUidList(::EPL_BLOCKLIST)
  if (blacklist.len())
    initParams.blacklist <- blacklist

  ::create_room(initParams, function(p) { ::SessionLobby.afterRoomCreation(p) })
  switchStatus(lobbyStates.CREATING_ROOM)
  return true
}

SessionLobby.createEventRoom <- function createEventRoom(mGameMode, lobbyParams)
{
  if (status != lobbyStates.NOT_IN_ROOM)
    return false

  local params = {
    public = {
      game_mode_id = mGameMode.gameModeId
    }
    custom_matching_lobby = lobbyParams
  }

  isEventRoom = true
  ::create_room(params, function(p) { ::SessionLobby.afterRoomCreation(p) })
  switchStatus(lobbyStates.CREATING_ROOM)
  return true
}

SessionLobby.continueCoopWithSquad <- function continueCoopWithSquad(missionSettings)
{
  switchStatus(lobbyStates.IN_ROOM);
  prepareSettings(missionSettings);
}

SessionLobby.afterRoomCreation <- function afterRoomCreation(params)
{
  if (!::checkMatchingError(params))
    return switchStatus(lobbyStates.NOT_IN_ROOM)

  isRoomOwner = true
  isRoomByQueue = false
  afterRoomJoining(params)
}

SessionLobby.destroyRoom <- function destroyRoom()
{
  if (!isRoomOwner)
    return

  ::destroy_room({ roomId = roomId }, function(p) {})
  ::SessionLobby.afterLeaveRoom({})
}

SessionLobby.leaveRoom <- function leaveRoom()
{
  if (status == lobbyStates.NOT_IN_ROOM || status == lobbyStates.WAIT_FOR_QUEUE_ROOM)
  {
    setWaitForQueueRoom(false)
    return
  }

  ::leave_room({}, function(p) {
      ::SessionLobby.afterLeaveRoom({})
   })
}

SessionLobby.checkLeaveRoomInDebriefing <- function checkLeaveRoomInDebriefing()
{
  if (::get_game_mode() == ::GM_DYNAMIC && !::is_dynamic_won())
    return;

  if (!last_round)
    return;

  if (isInRoom() && !haveLobby())
    leaveRoom()
}

//return true if success
SessionLobby.goForwardAfterDebriefing <- function goForwardAfterDebriefing()
{
  if (!haveLobby() || !isInRoom())
    return false

  isRoomByQueue = false //from now it not room by queue because we are back to lobby from session
  if (status == lobbyStates.IN_LOBBY)
    ::gui_start_mp_lobby()
  else
    returnStatusToRoom()
  return true
}

SessionLobby.afterLeaveRoom <- function afterLeaveRoom(p)
{
  roomId = INVALID_ROOM_ID
  switchStatus(lobbyStates.NOT_IN_ROOM)
  local guiScene = ::get_main_gui_scene()
  if (guiScene)
    guiScene.performDelayed(this, checkSessionReconnect) //notify room leave will be received soon
}

SessionLobby.sendJoinRoomRequest <- function sendJoinRoomRequest(join_params, cb = function(...) {})
{
  if (isInRoom())
    leaveRoom() //leave old room before join the new one

  ::leave_mp_session()

  if (!isRoomOwner)
  {
    setSettings({})
    members = []
  }

  ::LAST_SESSION_DEBUG_INFO =
    ("roomId" in join_params) ? ("room:" + join_params.roomId) :
    ("battleId" in join_params) ? ("battle:" + join_params.battleId) :
    ""

  switchStatus(lobbyStates.JOINING_ROOM)
  ::join_room(join_params, afterRoomJoining.bindenv(this))
}

SessionLobby.joinBattle <- function joinBattle(battleId)
{
  ::queues.leaveAllQueuesSilent()
  ::notify_queue_leave({})
  isRoomOwner = false
  isRoomByQueue = false
  sendJoinRoomRequest({battleId = battleId})
}

SessionLobby.joinRoom <- function joinRoom(_roomId, senderId = "", _password = null,
                                cb = function(...) {}) //by default not a queue, but no id too
{
  if (roomId == _roomId && isInRoom())
    return

  if (!::g_login.isLoggedIn() || isInRoom())
  {
    delayedJoinRoomFunc = (@(_roomId, senderId, _password, cb) function() { joinRoom(_roomId, senderId, _password, cb) })(_roomId, senderId, _password, cb)

    if (isInRoom())
      leaveRoom()
    return
  }

  isRoomOwner = is_my_userid(senderId)
  isRoomByQueue = senderId == null

  if (isRoomByQueue)
    ::notify_queue_leave({})
  else
    ::queues.leaveAllQueuesSilent()

  if (_password && _password.len())
    changePassword(_password)

  local joinParams = { roomId = _roomId }
  if (password!="")
    joinParams.password <- password

  sendJoinRoomRequest(joinParams, cb)
}

SessionLobby.joinFoundRoom <- function joinFoundRoom(room) //by default not a queue, but no id too
{
  if (("hasPassword" in room) && room.hasPassword && getRoomCreatorUid(room) != ::my_user_name)
    joinRoomWithPassword(room.roomId)
  else
    joinRoom(room.roomId)
}

SessionLobby.joinRoomWithPassword <- function joinRoomWithPassword(joinRoomId, prevPass = "", wasEntered = false)
{
  if (joinRoomId == "")
  {
    ::dagor.assertf(false, "SessionLobby Error: try to join room with password with empty room id")
    return
  }

  ::gui_modal_editbox_wnd({
    value = prevPass
    editboxHeaderText = wasEntered ? ::loc("matching/SERVER_ERROR_ROOM_PASSWORD_MISMATCH") : ""
    allowEmpty = false
    okFunc = @(pass) ::SessionLobby.joinRoom(joinRoomId, "", pass)
  })
}

SessionLobby.afterRoomJoining <- function afterRoomJoining(params)
{
  if (params.error == SERVER_ERROR_ROOM_PASSWORD_MISMATCH)
  {
    local joinRoomId = params.roomId //not_in_room status will clear room Id
    local oldPass = params.password
    switchStatus(lobbyStates.NOT_IN_ROOM)
    joinRoomWithPassword(joinRoomId, oldPass, oldPass != "")
    return
  }

  if (!::checkMatchingError(params))
    return switchStatus(lobbyStates.NOT_IN_ROOM)

  roomId = params.roomId
  roomUpdated = true
  members = ::getTblValue("members", params, [])
  initMyParamsByMemberInfo()
  ingame_chat.clearLog()
  ::g_squad_utils.updateMyCountryData()

  local public = ::getTblValue("public", params, settings)
  if (!isRoomOwner || ::u.isEmpty(settings))
  {
    setSettings(public)

    local mGameMode = getMGameMode()
    if (mGameMode)
    {
      setIngamePresence(public, roomId)
      isEventRoom = ::events.isEventWithLobby(mGameMode)
    }
    dagor.debug("Joined room: isEventRoom " + isEventRoom)

    if (isRoomByQueue && !isSessionStartedInRoom())
      isRoomByQueue = false
    if (isEventRoom && !isRoomByQueue && haveLobby())
      needJoinSessionAfterMyInfoApply = true
  }

  for(local i = members.len()-1; i>=0; i--)
    if (isMemberHost(members[i]))
    {
      updateMemberHostParams(members[i])
      members.remove(i)
    } else
      if (is_my_userid(members[i].userId))
        isRoomOwner = isMemberOperator(members[i])

  returnStatusToRoom()
  syncAllInfo()

  checkSquadAutoInvite()

  local event = ::SessionLobby.getRoomEvent()
  if (event)
  {
    if (::events.isEventVisibleInEventsWindow(event))
      ::saveLocalByAccount("lastPlayedEvent", {
        eventName = event.name
        economicName = ::events.getEventEconomicName(event)
      })

    ::broadcastEvent("AfterJoinEventRoom", event)
  }

  if (isRoomOwner && ::get_game_mode() == ::GM_DYNAMIC && !::dynamic_mission_played())
  {
    ::serialize_dyncampaign({ roomId = roomId },
      function(p)
      {
        if (checkMatchingError(p))
          ::SessionLobby.checkAutoStart()
        else
          ::SessionLobby.destroyRoom();
      });
  }
  else
    checkAutoStart()
  ::SquadIcon.initListLabelsSquad()

  last_round = ::getTblValue("last_round", public, true)
  setRoomInSession(isSessionStartedInRoom())
  ::broadcastEvent("RoomJoined", params)
}

SessionLobby.returnStatusToRoom <- function returnStatusToRoom()
{
  local newStatus = lobbyStates.IN_ROOM
  if (haveLobby())
    newStatus = isRoomByQueue ? lobbyStates.IN_LOBBY_HIDDEN : lobbyStates.IN_LOBBY
  switchStatus(newStatus)
}

SessionLobby.isMemberOperator <- function isMemberOperator(member)
{
  return ("public" in member) && ("operator" in member.public) && member.public.operator
}

SessionLobby.invitePlayer <- function invitePlayer(uid)
{
  if (roomId == INVALID_ROOM_ID) // we are not in room. nothere to invite
  {
    local is_in_room = isInRoom()                   // warning disable: -declared-never-used
    local room_id = roomId                          // warning disable: -declared-never-used
    local last_session = ::LAST_SESSION_DEBUG_INFO  // warning disable: -declared-never-used
    ::script_net_assert("trying to invite into room without roomId")
    return
  }

  ::invite_player_to_room({ roomId = roomId, userId = uid}, function(p) { ::checkMatchingError(p, false) })
}

SessionLobby.kickPlayer <- function kickPlayer(member)
{
  if (!("memberId" in member) || !isRoomOwner || !isInRoom())
    return

  foreach(idx, m in members)
    if (m.memberId == member.memberId)
      ::kick_member({ roomId = roomId, memberId = member.memberId }, function(p) { ::checkMatchingError(p) })
}

SessionLobby.updateRoomAttributes <- function updateRoomAttributes(missionSettings)
{
  if (!isRoomOwner)
    return

  prepareSettings(missionSettings)
}

SessionLobby.afterRoomUpdate <- function afterRoomUpdate(params)
{
  if (!::checkMatchingError(params))
    return destroyRoom()

  roomUpdated = true
  checkAutoStart()
}

SessionLobby.isMemberHost <- function isMemberHost(m)
{
  return (m.memberId==memberHostId || (("public" in m) && ("host" in m.public) && m.public.host))
}

SessionLobby.isMemberSpectator <- function isMemberSpectator(m)
{
  return (("public" in m) && ("spectator" in m.public) && m.public.spectator)
}

SessionLobby.getMembersCount <- function getMembersCount(room = null)
{
  local res = 0
  foreach(m in getRoomMembers(room))
    if (!isMemberHost(m))
      res++
  return res
}

//we doesn't know full members info outside room atm, but still return the same data format.
SessionLobby.getMembersCountByTeams <- function getMembersCountByTeams(room = null, needReadyOnly = false)
{
  local res = {
    total = 0,
    participants = 0,
    spectators = 0,
    [Team.Any] = 0,
    [Team.A] = 0,
    [Team.B] = 0
  }

  local roomMembers = getRoomMembers(room)
  if (room && !roomMembers.len())
  {
    local teamsCount = room?.session.teams
    foreach(team in ::g_team.getTeams())
    {
      local count = teamsCount?[team.id].players ?? 0
      res[team.code] = count
      res.total += count
    }
    return res
  }

  if (!isInRoom() && !room)
    return res

  foreach(m in roomMembers)
  {
    if (isMemberHost(m))
      continue

    if (needReadyOnly)
      if (!hasSessionInLobby() && !isMemberReady(m))
        continue
      else if (hasSessionInLobby() && !isMemberInSession(m))
        continue

    res.total++
    if (isMemberSpectator(m))
      res.spectators++
    else
      res.participants++
    if (("public" in m) && ("team" in m.public) && (m.public.team.tointeger() in res))
      res[m.public.team.tointeger()]++
  }
  return res
}

SessionLobby.getChatRoomId <- function getChatRoomId()
{
  return ::g_chat_room_type.MP_LOBBY.getRoomId(roomId)
}

SessionLobby.isLobbyRoom <- function isLobbyRoom(roomId)
{
  return ::g_chat_room_type.MP_LOBBY.checkRoomId(roomId)
}

SessionLobby.getChatRoomPassword <- function getChatRoomPassword()
{
  return getPublicParam("chatPassword", "")
}

SessionLobby.isSessionStartedInRoom <- function isSessionStartedInRoom(room = null)
{
  return ::getTblValue("hasSession", getPublicData(room), false)
}

SessionLobby.getMaxMembersCount <- function getMaxMembersCount(room = null)
{
  if (room)
    return getRoomSize(room)
  return ::getTblValue("players", settings, 0)
}

SessionLobby.checkAutoStart <- function checkAutoStart()
{
  if (isRoomOwner && !isRoomByQueue && !haveLobby() && roomUpdated
    && ::g_squad_manager.getOnlineMembersCount() <= getMembersCount())
    startSession()
}

SessionLobby.startSession <- function startSession()
{
  if (status != lobbyStates.IN_ROOM && status != lobbyStates.IN_LOBBY && status != lobbyStates.IN_LOBBY_HIDDEN)
    return
  if (!isMissionReady())
  {
    uploadUserMission(function() { ::SessionLobby.startSession() })
    return
  }
  dagor.debug("start session")

  ::room_start_session({ roomId = roomId, cluster = getPublicParam("cluster", "EU") },
      function(p)
      {
        if (!::SessionLobby.isInRoom())
          return
        if (!::checkMatchingError(p))
        {
          if (!::SessionLobby.haveLobby())
            ::SessionLobby.destroyRoom()
          else if (::isInMenu())
            ::SessionLobby.returnStatusToRoom()
          return
        }
        ::SessionLobby.switchStatus(lobbyStates.JOINING_SESSION)
      })
  switchStatus(lobbyStates.START_SESSION)
}

SessionLobby.hostCb <- function hostCb(res)
{
  if ((typeof(res)=="table") && ("errCode" in res))
  {
    local errorCode;
    if (res.errCode == 0)
    {
      if (::get_game_mode() == ::GM_DOMINATION)
        errorCode = NET_SERVER_LOST
      else
        errorCode = NET_SERVER_QUIT_FROM_GAME
    }
    else
      errorCode = res.errCode

    if (isInRoom())
      if (haveLobby())
        returnStatusToRoom()
      else
        leaveRoom()

    ::error_message_box("yn1/connect_error", errorCode,
      [["ok", ::destroy_session_scripted]],
      "ok",
      { saved = true })
  }
  //else
  //  switchStatus(lobbyStates.JOINING_SESSION)
}

SessionLobby.onMemberJoin <- function onMemberJoin(params)
{
  if (isMemberHost(params))
    return updateMemberHostParams(params)

  foreach(m in members)
    if (m.memberId == params.memberId)
    {
      onMemberInfoUpdate(params)
      return
    }
  members.append(params)
  broadcastEvent("LobbyMembersChanged")
  checkAutoStart()
}

SessionLobby.onMemberLeave <- function onMemberLeave(params, kicked = false)
{
  if (isMemberHost(params))
    return updateMemberHostParams(null)

  foreach(idx, m in members)
    if (params.memberId == m.memberId)
    {
      members.remove(idx)
      if (is_my_userid(m.userId))
      {
        afterLeaveRoom({})
        if (kicked)
        {
          if (!::isInMenu())
          {
            ::quit_to_debriefing()
            ::interrupt_multiplayer(true)
            ::in_flight_menu(false)
          }
          ::scene_msg_box("you_kicked_out_of_battle", null, ::loc("matching/msg_kicked"),
                          [["ok", function (){}]], "ok",
                          { saved = true })
        }
      }
      broadcastEvent("LobbyMembersChanged")
      break
    }
}

//only with full room info
SessionLobby.getRoomMembers <- function getRoomMembers(room = null)
{
  if (!room)
    return members
  return ::getTblValue("members", room, [])
}

SessionLobby.getRoomMembersCnt <- function getRoomMembersCnt(room)
{
  return ::getTblValue("membersCnt", room, 0)
}

SessionLobby.getRoomSize <- function getRoomSize(room)
{
  return ::getTblValue("players", ::getTblValue("public", room), ::getTblValue("size", room, 0))
}

SessionLobby.getRoomCreatorUid <- function getRoomCreatorUid(room)
{
  return ::getTblValue("creator", ::getTblValue("public", room))
}

SessionLobby.getRoomsInfoTbl <- function getRoomsInfoTbl(roomsList)
{
  local res = []
  foreach(room in roomsList)
  {
    local public = room?.public
    local misData = public?.mission ?? {}
    local item = {
      hasPassword = public?.hasPassword ?? false
      numPlayers = getRoomMembersCnt(room)
      numPlayersTotal = getRoomSize(room)
    }
    if ("roomName" in public)
      item.mission <- public.roomName
    else if (isUrlMission(public))
    {
      local url = getMissionUrl(public)
      local urlMission =  ::g_url_missions.findMissionByUrl(url)
      local missionName = urlMission ? urlMission.name : url
      item.mission <- missionName
    }
    else
      item.mission <- getMissionNameLoc(public)
    if ("creator" in public)
      item.name <- getPlayerName(public?.creator ?? "")
    if ("difficulty" in misData)
      item.difficultyStr <- ::loc($"options/{misData.difficulty}")
    res.append(item)
  }
  return res
}

SessionLobby.isRoomHavePassword <- function isRoomHavePassword(room)
{
  return false
}

SessionLobby.getMembersReadyStatus <- function getMembersReadyStatus()
{
  local res = {
    readyToStart = true
    ableToStart = false //can be not full ready, but able to start.
    haveNotReady = false
    statusText = ::loc("multiplayer/readyToGo")
  }

  local teamsCount = {
    [Team.Any] = 0,
    [Team.A] = 0,
    [Team.B] = 0
  }

  foreach(idx, member in members)
  {
    local ready = isMemberReady(member)
    local spectator = getMemberPublicParam(member, "spectator")
    local team = getMemberPublicParam(member, "team").tointeger()
    res.haveNotReady = res.haveNotReady || (!ready && !spectator)
    res.ableToStart = res.ableToStart || !spectator
    if (ready && !spectator)
    {
      if (team in teamsCount)
        teamsCount[team]++
      else
        teamsCount[Team.Any]++
    }
  }

  res.readyToStart = !res.haveNotReady
  if (res.haveNotReady)
    res.statusText = ::loc("multiplayer/not_all_ready")

  local gt = getGameType()
  local checkTeams = ::is_mode_with_teams(gt)
  if (!checkTeams)
    return res

  local haveBots = getMissionParam("isBotsAllowed", false)
  local maxInTeam = (0.5*getMaxMembersCount() + 0.5).tointeger()

  if ((!haveBots && (::abs(teamsCount[Team.A] - teamsCount[Team.B]) - teamsCount[Team.Any] > 1))
      || teamsCount[Team.A] > maxInTeam || teamsCount[Team.B] > maxInTeam)
  {
    res.readyToStart = false
    res.statusText = ::loc("multiplayer/nonBalancedGame")
  }

  if (!res.ableToStart || !haveBots)
  {
    local minInTeam = 1
    local teamAEnough = (teamsCount[Team.A] + teamsCount[Team.Any]) >= minInTeam
    local teamBEnough = (teamsCount[Team.B] + teamsCount[Team.Any]) >= minInTeam
    local teamsTotalEnough = teamsCount[Team.A] + teamsCount[Team.B] + teamsCount[Team.Any] >= minInTeam * 2
    if (!teamAEnough || !teamBEnough || !teamsTotalEnough)
    {
      res.readyToStart = false
      res.ableToStart = false
      res.statusText = ::loc(res.haveNotReady? "multiplayer/notEnoughReadyPlayers" : "multiplayer/notEnoughPlayers")
    }
  }

  return res
}

SessionLobby.canInvitePlayer <- function canInvitePlayer(uid)
{
  return isInRoom() && !is_my_userid(uid) && haveLobby() && !isPlayerInMyRoom(uid)
}

SessionLobby.isPlayerInMyRoom <- function isPlayerInMyRoom(uid)
{
  local roomMembers = getRoomMembers()
  foreach (member in roomMembers)
    if (member.userId == uid.tointeger())
      return true

  return false
}

SessionLobby.needAutoInviteSquad <- function needAutoInviteSquad()
{
  return isInRoom() && (isRoomOwner || (haveLobby() && !isRoomByQueue))
}

SessionLobby.checkSquadAutoInvite <- function checkSquadAutoInvite()
{
  if (!::g_squad_manager.isSquadLeader() || !needAutoInviteSquad())
    return

  local sMembers = ::g_squad_manager.getMembers()
  foreach(uid, member in sMembers)
    if (member.online
        && member.isReady
        && !member.isMe()
        && !::u.search(members, @(m) m.userId == uid)
        && ::g_squad_manager.canInvitePlayerToSessionByName(member.name))
    {
      invitePlayer(uid)
    }
}

::SessionLobby.onEventSquadStatusChanged <- @(p) checkSquadAutoInvite()

SessionLobby.getValueSettings <- function getValueSettings(value)
{
  if (value != "" && (value in SessionLobby.settings))
    return SessionLobby.settings[value]
  return null
}

SessionLobby.getMemberPlayerInfo <- function getMemberPlayerInfo(uid)
{
  return ::getTblValue(uid.tointeger(), playersInfo)
}

SessionLobby.getPlayersInfo <- function getPlayersInfo()
{
  return playersInfo
}

SessionLobby.isMemberInMySquadByName <- function isMemberInMySquadByName(name)
{
  if (!::SessionLobby.isInRoom())
    return false

  local memberInfo = null
  local myInfo = getMemberPlayerInfo(::my_user_id_int64)
  if (myInfo != null)
  {
    if (myInfo.squad == INVALID_SQUAD_ID)
      return false
    if (myInfo.name == name)
      return false
  }

  foreach (uid, member in playersInfo)
  {
    if (member.name == name)
    {
      memberInfo = member
      break
    }
  }
  if (memberInfo == null || myInfo == null)
    return false

  return memberInfo.team == myInfo.team && memberInfo.squad == myInfo.squad
}

SessionLobby.isEqualSquadId <- function isEqualSquadId(squadId1, squadId2)
{
  return squadId1 != INVALID_SQUAD_ID && squadId1 == squadId2
}

SessionLobby.getBattleRatingParamByPlayerInfo <- function getBattleRatingParamByPlayerInfo(member, esUnitTypeFilter = null)
{
  local craftsInfo = member?.crafts_info
  if (craftsInfo == null)
    return null
  local difficulty = ::is_in_flight() ? ::get_mission_difficulty_int() : ::get_current_shop_difficulty().diffCode
  local units = []
  foreach (unitInfo in craftsInfo)
  {
    local unitName = unitInfo.name
    local unit = ::getAircraftByName(unitName)
    if (esUnitTypeFilter != null && esUnitTypeFilter != unit.esUnitType)
      continue

    units.append({
      rating = unit?.getBattleRating(difficulty) ?? 0
      name = ::loc($"{unitName}_shop")
      rankUnused = unitInfo?.rankUnused ?? false
    })
  }
  units.sort(@(a,b) a.rankUnused <=> b.rankUnused || b.rating <=> a.rating)
  local squad = member?.squad ?? INVALID_SQUAD_ID
  return { rank = member.mrank, squad = squad, units = units }
}

/**
 * Returns true if unit available for spawn is player's own unit with own crew.
 * Returns false for non player's (random, etc.) units available for spawn.
 */
SessionLobby.isUsedPlayersOwnUnit <- function isUsedPlayersOwnUnit(member, unitId)
{
  return ::u.search(member?.crafts_info ?? [], @(ci) ci.name == unitId) != null
}

/**
 * Returns null if all countries available.
 */
SessionLobby.getCountriesByTeamIndex <- function getCountriesByTeamIndex(teamIndex)
{
  local event = ::SessionLobby.getRoomEvent()
  if (!event)
    return null
  return ::events.getCountries(::events.getTeamData(event, teamIndex))
}

SessionLobby.getMyCurUnit <- function getMyCurUnit()
{
  return ::get_cur_slotbar_unit()
}

SessionLobby.getTeamToCheckUnits <- function getTeamToCheckUnits()
{
  return team == Team.B ? Team.B : Team.A
}

SessionLobby.getTeamDataToCheckUnits <- function getTeamDataToCheckUnits()
{
  return getTeamData(getTeamToCheckUnits())
}

/**
 * Returns table with two keys: checkAllowed, checkForbidden.
 * Takes in account current selected team.
 */
SessionLobby.isUnitAllowed <- function isUnitAllowed(unit)
{
  local roomSpecialRules = getRoomSpecialRules()
  if (roomSpecialRules && !::events.isUnitMatchesRule(unit, roomSpecialRules, true, getCurRoomEdiff()))
    return false

  local teamData = getTeamDataToCheckUnits()
  return !teamData || ::events.isUnitAllowedByTeamData(teamData, unit.name, getCurRoomEdiff())
}

SessionLobby.hasUnitRequirements <- function hasUnitRequirements()
{
  return ::events.hasUnitRequirements(getTeamDataToCheckUnits())
}

SessionLobby.isUnitRequired <- function isUnitRequired(unit)
{
  local teamData = getTeamDataToCheckUnits()
  if (!teamData)
    return false

  return ::events.isUnitMatchesRule(unit.name,
    ::events.getRequiredCrafts(teamData), true, getCurRoomEdiff())
}

/**
 * Returns table with two keys: checkAllowed, checkForbidden.
 * Takes in account current selected team.
 * @param countryName Applied to units in all countries if not specified.
 * @param team Optional parameter to override current selected team.
 */
SessionLobby.checkUnitsInSlotbar <- function checkUnitsInSlotbar(countryName, teamToCheck = null)
{
  local res = {
    isAvailable = true
    reasonText = ""
  }

  if (teamToCheck == null)
    teamToCheck = team
  local teamsToCheck
  if (teamToCheck == Team.Any)
    teamsToCheck = [Team.A, Team.B]
  else if (teamToCheck == Team.none)
    teamsToCheck = []
  else
    teamsToCheck = [teamToCheck]

  local hasTeamData = false
  local hasAnyAvailable = false
  local isCurUnitAvailable = false
  local hasRespawns = getMaxRespawns() != 1
  local ediff = getCurRoomEdiff()
  local curUnit = getMyCurUnit()
  local crews = ::get_crews_list_by_country(countryName)

  foreach (team in teamsToCheck)
  {
    local teamName = ::events.getTeamName(team)
    local teamData = ::getTblValue(teamName, getSessionInfo(), null)
    if (teamData == null)
      continue

    hasTeamData = true
    foreach (crew in crews)
    {
      local unit = ::g_crew.getCrewUnit(crew)
      if (!unit || !::events.isUnitAllowedByTeamData(teamData, unit.name, ediff))
        continue

      hasAnyAvailable = true
      if (unit == curUnit)
        isCurUnitAvailable = true
    }
  }

  if (hasTeamData) //allow all when no team data
  {
    if (!hasRespawns && !isCurUnitAvailable)
      res.reasonText = ::loc("events/selected_craft_is_not_allowed")
    else if (!hasAnyAvailable)
      res.reasonText = ::loc("events/no_allowed_crafts")
    res.isAvailable = res.reasonText == ""
  }

  return res
}

/**
 * Returns random team but prefers one with valid units.
 */
SessionLobby.getRandomTeam <- function getRandomTeam()
{
  local curCountry = ::SessionLobby.countryData ? ::SessionLobby.countryData.country : null
  local teams = []
  local allTeams = ::events.getSidesList()
  foreach (team in allTeams)
  {
    local checkTeamResult = checkUnitsInSlotbar(curCountry, team)
    if (checkTeamResult.isAvailable)
      teams.append(team)
  }
  if (teams.len() == 0)
    teams.extend(allTeams)
  if (teams.len() == 1)
    return teams[0]
  local randomIndex = ::floor(teams.len() * ::math.frnd())
  return teams[randomIndex]
}

SessionLobby.getRankCalcMode <- function getRankCalcMode()
{
  local event = ::SessionLobby.getRoomEvent()
  return ::events.getEventRankCalcMode(event)
}

SessionLobby.rpcJoinBattle <- function rpcJoinBattle(params)
{
  if (!::is_online_available())
    return "client not ready"
  local battleId = params.battleId
  if (typeof (battleId) != "string")
    return "bad battleId type"
  if (::g_squad_manager.getSquadSize() > 1)
    return "player is in squad"
  if (::SessionLobby.isInRoom())
    return "already in room"
  if (::is_in_flight())
    return "already in session"
  if (!antiCheat.showMsgboxIfEacInactive({enableEAC = true}))
    return "EAC is not active"

  dagor.debug("join to battle with id " + battleId)
  SessionLobby.joinBattle(battleId)
  return "ok"
}

SessionLobby.getMGameMode <- function getMGameMode(room = null, isCustomGameModeAllowed = true)
{
  local mGameModeId = getMGameModeId(room)
  if (mGameModeId == null)
    return null

  if (isCustomGameModeAllowed && (CUSTOM_GAMEMODE_KEY in room))
    return room._customGameMode

  local mGameMode = ::g_matching_game_modes.getModeById(mGameModeId)
  if (isCustomGameModeAllowed && room && mGameMode && ::events.isCustomGameMode(mGameMode))
  {
    local customGameMode = clone mGameMode
    foreach(team in ::g_team.getTeams())
      customGameMode[team.name] <- getTeamData(team.code, room)
    customGameMode.isSymmetric <- false
    room[CUSTOM_GAMEMODE_KEY] <- customGameMode
    return customGameMode
  }
  return mGameMode
}

SessionLobby.getRoomEvent <- function getRoomEvent(room = null)
{
  local mGameMode = getMGameMode(room)
  return mGameMode && ::events.getEvent(mGameMode.name)
}

SessionLobby.getMaxDisbalance <- function getMaxDisbalance()
{
  return ::getTblValue("maxLobbyDisbalance", getMGameMode(), ::global_max_players_versus)
}

SessionLobby.onEventMatchingDisconnect <- function onEventMatchingDisconnect(p)
{
  leaveRoom()
}

SessionLobby.onEventMatchingConnect <- function onEventMatchingConnect(p)
{
  leaveRoom()
}

SessionLobby.onEventLoadingStateChange <- function onEventLoadingStateChange(p)
{
  if (::handlersManager.isInLoading)
    return

  if (::is_in_flight())
    ::SessionLobby.switchStatusChecked(
      [lobbyStates.IN_ROOM, lobbyStates.IN_LOBBY, lobbyStates.IN_LOBBY_HIDDEN,
       lobbyStates.JOINING_SESSION],
      lobbyStates.IN_SESSION
    )
  else
    ::SessionLobby.switchStatusChecked(
      [lobbyStates.IN_SESSION, lobbyStates.JOINING_SESSION],
      lobbyStates.IN_DEBRIEFING
    )
}

SessionLobby.checkSessionReconnect <- function checkSessionReconnect()
{
  if (!::g_login.isLoggedIn() || penalties.isMeBanned())
    return

  if (delayedJoinRoomFunc)
  {
    delayedJoinRoomFunc()
    delayedJoinRoomFunc = null
  }

  checkSessionInvite()
}

SessionLobby.checkSessionInvite <- function checkSessionInvite()
{
  if (!reconnectData.inviteData || !reconnectData.sendResp)
    return

  local inviteData = reconnectData.inviteData
  local sendResp = reconnectData.sendResp

  local applyInvite = function() {
    local event = ::events.getEvent(inviteData?.attribs.game_mode_name)
    if (!antiCheat.showMsgboxIfEacInactive(event))
      return

    sendResp({})
    ::SessionLobby.joinRoom(inviteData.roomId, null, null)
  }

  local rejectInvite = (@(sendResp) function() {
    sendResp({error_id="INVITE_REJECTED"})
  })(sendResp)

  ::scene_msg_box("backToBattle_dialog", null, ::loc("msgbox/return_to_battle_session"),
    [
      ["yes", applyInvite],
      ["no", rejectInvite]
    ], "yes", {cancel_fn = rejectInvite})

  reconnectData.inviteData = null
  reconnectData.sendResp = null
}

SessionLobby.getRoomActiveTimers <- function getRoomActiveTimers()
{
  local res = []
  if (!isInRoom())
    return res

  local curTime = ::get_matching_server_time()
  foreach(timerId, cfg in roomTimers)
  {
    local tgtTime = getPublicParam(cfg.publicKey, -1)
    if (tgtTime == -1 || !::is_numeric(tgtTime) || tgtTime < curTime)
      continue

    local timeLeft = tgtTime - curTime
    res.append({
      id = timerId
      timeLeft = timeLeft
      text = ::colorize(cfg.color, cfg.getLocText(settings, { time = time.secondsToString(timeLeft, true, true) }))
    })
  }
  return res
}

SessionLobby.hasSessionInLobby <- function hasSessionInLobby()
{
  return isEventRoom
}

SessionLobby.canJoinSession <- function canJoinSession()
{
  if (hasSessionInLobby())
    return !isLeavingLobbySession
  return isRoomInSession
}

SessionLobby.updateOverrideSlotbar <- function updateOverrideSlotbar()
{
  local missionName = getMissionName(true)
  if (missionName == overrrideSlotbarMissionName)
    return
  overrrideSlotbarMissionName = missionName

  local newOverrideSlotbar = ::g_crews_list.calcSlotbarOverrideByMissionName(missionName)
  if (::u.isEqual(overrideSlotbar, newOverrideSlotbar))
    return

  overrideSlotbar = newOverrideSlotbar
  ::broadcastEvent("OverrideSlotbarChanged")
}


SessionLobby.isSlotbarOverrided <- function isSlotbarOverrided(room = null)
{
  return getSlotbarOverrideData(room) != null
}

SessionLobby.getSlotbarOverrideData <- function getSlotbarOverrideData(room = null)
{
  if (!room || getMissionName(true, room) == overrrideSlotbarMissionName)
    return overrideSlotbar
  return ::g_crews_list.calcSlotbarOverrideByMissionName(getMissionName(true, room))
}

SessionLobby.tryJoinSession <- function tryJoinSession(needLeaveRoomOnError = false)
{
   if (!canJoinSession())
     return false

   if (hasSessionInLobby())
   {
     joinEventSession(needLeaveRoomOnError)
     return true
   }
   if (isRoomInSession)
   {
     setReady(true)
     return true
   }
   return false
}

SessionLobby.joinEventSession <- function joinEventSession(needLeaveRoomOnError = false, params = null)
{
  ::matching_api_func("mrooms.join_session",
    function(params)
    {
      if (!::checkMatchingError(params) && needLeaveRoomOnError)
        leaveRoom()
    }.bindenv(this),
    params
  )
}

SessionLobby.leaveEventSessionWithRetry <- function leaveEventSessionWithRetry()
{
  isLeavingLobbySession = true
  ::matching_api_func("mrooms.leave_session",
    function(params)
    {
      // there is a some lag between actual disconnect from host and disconnect detection
      // just try to leave until host says that player is not in session anymore
      if (::getTblValue("error_id", params) == "MATCH.PLAYER_IN_SESSION")
        ::g_delayed_actions.add(leaveEventSessionWithRetry.bindenv(this), 1000)
      else
      {
        isLeavingLobbySession = false
        ::broadcastEvent("LobbyStatusChange")
      }
    }.bindenv(this))
}

SessionLobby.onEventUnitRepaired <- function onEventUnitRepaired(p)
{
  checkUpdateMatchingSlots()
}

SessionLobby.onEventSlotbarUnitChanged <- function onEventSlotbarUnitChanged(p)
{
  checkUpdateMatchingSlots()
}

web_rpc.register_handler("join_battle", SessionLobby.rpcJoinBattle)
::g_script_reloader.registerPersistentDataFromRoot("SessionLobby")
::subscribe_handler(::SessionLobby, ::g_listener_priority.DEFAULT_HANDLER)

foreach (notificationName, callback in
  {
    ["mrooms.reconnect_invite2"] = function (invite_data, send_resp)
    {
      dagor.debug("got reconnect invite from matching")
      if (::is_in_flight())
        return

     ::SessionLobby.reconnectData.inviteData = invite_data
     ::SessionLobby.reconnectData.sendResp = send_resp
     ::SessionLobby.checkSessionReconnect()
    },

    ["match.notify_wait_for_session_join"] = @(params) ::SessionLobby.setWaitForQueueRoom(true),

    ["match.notify_join_session_aborted"] = @(params) ::SessionLobby.leaveWaitForQueueRoom()
  }
)
  ::matching_rpc_subscribe(notificationName, callback)
