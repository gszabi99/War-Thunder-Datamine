from "%scripts/dagui_library.nut" import *
from "%scripts/teamsConsts.nut" import Team
from "%scripts/mainConsts.nut" import global_max_players_versus

let regexp2 = require("regexp2")
let { get_meta_mission_info_by_name } = require("guiMission")
let { format } = require("string")
let { INVALID_SQUAD_ID } = require("matching.errors")
let { getGlobalModule } = require("%scripts/global_modules.nut")
let events = getGlobalModule("events")
let { g_team } = require("%scripts/teams.nut")
let { getSessionLobbyPublicData, getSessionLobbyMissionData, getSessionLobbyGameMode, isInSessionRoom,
  isPlayerInMyRoom, isMeSessionLobbyRoomOwner, SessionLobbyState, getSessionLobbyCurRoomEdiff,
  getSessionLobbyMGameModeId, isInSessionLobbyEventRoom, getSessionLobbyPlayerInfoByUid, getRoomSize,
  getSessionLobbyPlayerInfoByName, getSessionLobbyMaxRespawns, getSessionInfo, getSessionLobbyPublicParam,
  getRoomMembers, isMemberHost, hasSessionInLobby, isMemberSpectator, getRoomMembersCnt, isUrlMissionByRoom,
  getMissionUrl, isUserMission
} = require("%scripts/matchingRooms/sessionLobbyState.nut")
let { userIdInt64, isMyUserId } = require("%scripts/user/profileStates.nut")
let { getRealName } = require("%scripts/user/nameMapping.nut")
let { getCombineLocNameMission } = require("%scripts/missions/missionsText.nut")
let { getEventRankCalcMode, isEventWithLobby } = require("%scripts/events/eventInfo.nut")
let { getMissionLocIdsArray, getUrlOrFileMissionMetaInfo, getSessionLobbyMissionName
} = require("%scripts/missions/missionsUtilsModule.nut")
let { getModeById } = require("%scripts/matching/matchingGameModes.nut")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { getCurSlotbarUnit } = require("%scripts/slotbar/slotbarState.nut")
let { getCrewsListByCountry } = require("%scripts/slotbar/crewsList.nut")
let { getCrewUnit } = require("%scripts/crew/crew.nut")
let { secondsToString } = require("%scripts/time.nut")
let { floor } = require("math")
let { frnd } = require("dagor.random")
let { isRoomMemberInSession, isRoomMemberReady } = require("%scripts/matchingRooms/sessionLobbyMembersInfo.nut")
let { g_url_missions } = require("%scripts/missions/urlMissionsList.nut")
let { getPlayerName } = require("%scripts/user/remapNick.nut")
let { g_mislist_type } =  require("%scripts/missions/misListType.nut")
let { getMatchingServerTime } = require("%scripts/onlineInfo/onlineInfo.nut")

const CUSTOM_GAMEMODE_KEY = "_customGameMode"
const MAX_BR_DIFF_AVAILABLE_AND_REQ_UNITS = 0.6
let missionLocNameRegexp = regexp2(@"[^a-zA-Z0-9;_\/]")

let roomTimers = [
  {
    publicKey = "timeToCloseByDisbalance"
    color = "@warningTextColor"
    function getLocText(public, locParams) {
      local res = loc("multiplayer/closeByDisbalance", locParams)
      if ("disbalanceType" in public)
        res = "".concat(res, "\n", loc("multiplayer/reason"), loc("ui/colon"),
          loc($"roomCloseReason/{public.disbalanceType}"))
      return res
    }
  }
  {
    publicKey = "matchStartTime"
    color = "@inQueueTextColor"
    function getLocText(_public, locParams) {
      return loc("multiplayer/battleStartsIn", locParams)
    }
  }
]

function getRoomEvent(room = null) {
  return events.getEvent(getSessionLobbyPublicData(room)?.game_mode_name)
}

function getSessionLobbyMissionNameLoc(room = null) {
  let misData = getSessionLobbyMissionData(room)
  if ("name" in misData) {
    let missionMetaInfo = getUrlOrFileMissionMetaInfo(misData.name)
    return getCombineLocNameMission(missionMetaInfo ? missionMetaInfo : misData)
  }
  return ""
}

function haveLobby() {
  let gm = getSessionLobbyGameMode()
  if (gm == GM_SKIRMISH)
    return true
  if (gm == GM_DOMINATION)
    return isEventWithLobby(getRoomEvent())
  return false
}

function canInvitePlayerToSessionRoom(uid) {
  return isInSessionRoom.get() && !isMyUserId(uid) && haveLobby() && !isPlayerInMyRoom(uid)
}

function needAutoInviteSquadToSessionRoom() {
  return isInSessionRoom.get() && (isMeSessionLobbyRoomOwner.get() || (haveLobby() && !SessionLobbyState.isRoomByQueue))
}

function getSessionLobbyTimeLimit(room = null) {
  local timeLimit = getSessionLobbyMissionData(room)?.timeLimit ?? 0
  if (timeLimit)
    return timeLimit

  let missionName = getSessionLobbyMissionName(true, room)
  if (!missionName)
    return timeLimit

  let misData = get_meta_mission_info_by_name(missionName)
  return misData?.timeLimit ?? 0
}



function getRoomSpecialRules(_room = null) {
  return null 
}

function getRoomTeamData(teamCode, room = null) {
  return events.getTeamData(getSessionLobbyPublicData(room), teamCode)
}

function getTeamToCheckUnits() {
  return SessionLobbyState.team == Team.B ? Team.B : Team.A
}

function getTeamDataToCheckUnits() {
  return getRoomTeamData(getTeamToCheckUnits())
}





function isUnitAllowedForRoom(unit) {
  let roomSpecialRules = getRoomSpecialRules()
  if (roomSpecialRules && !events.isUnitMatchesRule(unit, roomSpecialRules, true, getSessionLobbyCurRoomEdiff()))
    return false

  let teamData = getTeamDataToCheckUnits()
  return !teamData || events.isUnitAllowedByTeamData(teamData, unit.name, getSessionLobbyCurRoomEdiff())
}

function hasUnitRequirementsInRoom() {
  return events.hasUnitRequirements(getTeamDataToCheckUnits())
}

function isUnitRequiredForRoom(unit) {
  let teamData = getTeamDataToCheckUnits()
  if (!teamData)
    return false

  return events.isUnitMatchesRule(unit.name,
    events.getRequiredCrafts(teamData), true, getSessionLobbyCurRoomEdiff())
}

function getRoomRequiredCrafts(teamCode = Team.A, room = null) {
  let teamData = getRoomTeamData(teamCode, room)
  return events.getRequiredCrafts(teamData)
}

function getRoomMGameMode(room = null, isCustomGameModeAllowed = true) {
  let mGameModeId = getSessionLobbyMGameModeId(room)
  if (mGameModeId == null)
      return null

  if (isCustomGameModeAllowed && (CUSTOM_GAMEMODE_KEY in room))
    return room._customGameMode

  let mGameMode = getModeById(mGameModeId)
  if (isCustomGameModeAllowed && room && mGameMode && events.isCustomGameMode(mGameMode)) {
    let customGameMode = clone mGameMode
    foreach (team in g_team.getTeams())
      customGameMode[team.name] <- getRoomTeamData(team.code, room)
    customGameMode.isSymmetric <- false
    room[CUSTOM_GAMEMODE_KEY] <- customGameMode
    return customGameMode
  }
  return mGameMode
}

function getRoomRankCalcMode() {
  let event = getRoomEvent()
  return getEventRankCalcMode(event)
}

function getRoomMaxDisbalance() {
  return getRoomMGameMode()?.maxLobbyDisbalance ?? global_max_players_versus
}

function getRoomUnitTypesMask(room = null) {
  return events.getEventUnitTypesMask(getRoomMGameMode(room) || getSessionLobbyPublicData(room))
}

function getRoomRequiredUnitTypesMask(room = null) {
  return events.getEventRequiredUnitTypesMask(getRoomMGameMode(room) || getSessionLobbyPublicData(room))
}

function getSessionLobbyLockedCountryData() {
  if (SessionLobbyState.crsSetTeamTo == Team.none)
    return null

  let availableCountries = getRoomTeamData(SessionLobbyState.crsSetTeamTo)?.countries ?? []
  if (availableCountries.len() == 0)
    return null

  return {
    availableCountries = availableCountries
    reasonText = loc("multiplayer/cantChangeCountryInLobby", {
      availableCountries = "".concat(loc("available_countries"), loc("ui/colon"),
        loc("ui/comma").join(availableCountries.map(@(c) loc(c))))
    })
  }
}

function getSessionLobbyMissionNameLocIdsArray(room = null) {
  let misData = getSessionLobbyMissionData(room)
  if ("name" in misData)
    return getMissionLocIdsArray(getUrlOrFileMissionMetaInfo(misData.name))
  return []
}

function getRoomTeamsCountries(room = null) {
  let res = []
  local hasCountries = false
  foreach (t in [Team.A, Team.B]) {
    let teamData = getRoomTeamData(t, room)
    let countries = events.getCountries(teamData)
    res.append(countries)
    hasCountries = hasCountries || countries.len()
  }

  if (hasCountries)
    return res
  
  let mGameMode = getRoomMGameMode(room)
  if (mGameMode)
    return events.getCountriesByTeams(mGameMode)

  let pData = getSessionLobbyPublicData(room)
  foreach (idx, name in ["country_allies", "country_axis"])
    if (name in pData)
      res[idx] = pData[name]
  return res
}

function getAvailableTeamOfRoom() {
  if (SessionLobbyState.spectator)
    return (SessionLobbyState.crsSetTeamTo == Team.none) ? Team.Any : SessionLobbyState.crsSetTeamTo

  let myCountry = profileCountrySq.get()
  let aTeams = [ SessionLobbyState.crsSetTeamTo != Team.B, 
                 SessionLobbyState.crsSetTeamTo != Team.A
               ]

  let teamsCountries = getRoomTeamsCountries()
  foreach (idx, _value in aTeams)
    if (!isInArray(myCountry, getTblValue(idx, teamsCountries, teamsCountries[0])))
      aTeams[idx] = false

  local canPlayTeam = 0
  if (aTeams[0])
    canPlayTeam = aTeams[1] ? Team.Any : Team.A
  else
    canPlayTeam = aTeams[1] ? Team.B : Team.none
  return canPlayTeam
}

function canChangeTeamInLobby() {
  if (!haveLobby() || isInSessionLobbyEventRoom.get())
    return false
  let canPlayTeam = getAvailableTeamOfRoom()
  return canPlayTeam == Team.Any
}

function getBattleRatingParamByPlayerInfo(member, ediff, esUnitTypeFilter = null) {
  let craftsInfo = member?.crafts_info
  if (craftsInfo == null)
    return null
  let units = []
  foreach (unitInfo in craftsInfo) {
    let unitName = unitInfo.name
    let unit = getAircraftByName(unitName)
    if (esUnitTypeFilter != null && esUnitTypeFilter != unit.esUnitType)
      continue

    units.append({
      unitName
      rating = unit?.getBattleRating(ediff) ?? 0
      name = loc($"{unitName}_shop")
      rankUnused = unitInfo?.rankUnused ?? false
    })
  }
  units.sort(@(a, b) a.rankUnused <=> b.rankUnused || b.rating <=> a.rating)
  return { rank = member.mrank, units = units }
}

function getNotAvailableUnitByBRText(unit, ediff, room = null) {
  if (!unit)
    return null

  let mGameMode = getRoomMGameMode(room)
  if (!mGameMode)
    return null

  let curBR = unit.getBattleRating(ediff)
  let maxBR = (getBattleRatingParamByPlayerInfo(getSessionLobbyPlayerInfoByUid(userIdInt64.get()), ediff,
    ES_UNIT_TYPE_SHIP)?.units?[0]?.rating ?? 0) + MAX_BR_DIFF_AVAILABLE_AND_REQ_UNITS
  return (events.isUnitTypeRequired(mGameMode, ES_UNIT_TYPE_SHIP)
    && unit.esUnitType == ES_UNIT_TYPE_AIRCRAFT
    && ((curBR - maxBR) * 10).tointeger() >= 0)
      ? loc("not_available_aircraft/byBR", {
          gameModeName = events.getEventNameText(mGameMode),
          lockedUnitType = colorize("userlogColoredText",
            loc($"mainmenu/type_{unit.unitType.lowerName}")),
          battleRatingDiff = colorize("userlogColoredText", format("%.1f", MAX_BR_DIFF_AVAILABLE_AND_REQ_UNITS)),
          reqUnitType = colorize("userlogColoredText", loc("mainmenu/type_ship_and_boat"))
        })
      : null
}

function isMemberInMySquadByName(name) {
  if (!isInSessionRoom.get())
    return false

  let myInfo = getSessionLobbyPlayerInfoByUid(userIdInt64.get())
  if (myInfo != null && (myInfo.squad == INVALID_SQUAD_ID || myInfo.name == name))
    return false

  let memberInfo = getSessionLobbyPlayerInfoByName(name) ?? getSessionLobbyPlayerInfoByName(getRealName(name))
  if (memberInfo == null || myInfo == null)
    return false

  return memberInfo.team == myInfo.team && memberInfo.squad == myInfo.squad
}

function isMemberInMySquadById(userId) {
  if (userId == null || userId == userIdInt64.get())
    return false
  if (!isInSessionRoom.get())
    return false

  let myInfo = getSessionLobbyPlayerInfoByUid(userIdInt64.get())
  if (myInfo == null || myInfo.squad == INVALID_SQUAD_ID)
    return false

  let memberInfo = getSessionLobbyPlayerInfoByUid(userId)
  if (memberInfo == null)
    return false

  return memberInfo.team == myInfo.team && memberInfo.squad == myInfo.squad
}

function canBeSpectator() {
  if (!hasFeature("Spectator"))
    return false
  if (getSessionLobbyGameMode() != GM_SKIRMISH) 
    return false
  return true
}







function checkUnitsInSlotbar(countryName, teamToCheck = null) {
  let res = {
    isAvailable = true
    reasonText = ""
  }

  if (teamToCheck == null)
    teamToCheck = SessionLobbyState.team
  local teamsToCheck
  if (teamToCheck == Team.Any)
    teamsToCheck = [Team.A, Team.B]
  else if (teamToCheck == Team.none)
    teamsToCheck = []
  else
    teamsToCheck = [teamToCheck]

  local hasTeamData = false
  local hasUnitsInSlotbar = false
  local hasAnyAvailable = false
  local isCurUnitAvailable = false
  let hasRespawns = getSessionLobbyMaxRespawns() != 1
  let ediff = getSessionLobbyCurRoomEdiff()
  let curUnit = getCurSlotbarUnit()
  let crews = getCrewsListByCountry(countryName)

  foreach (team in teamsToCheck) {
    let teamName = events.getTeamName(team)
    let teamData = getSessionInfo()?[teamName]
    if (teamData == null)
      continue

    hasTeamData = true
    foreach (crew in crews) {
      let unit = getCrewUnit(crew)
      hasUnitsInSlotbar = hasUnitsInSlotbar || unit != null
      if (!unit || !events.isUnitAllowedByTeamData(teamData, unit.name, ediff))
        continue

      hasAnyAvailable = true
      if (unit == curUnit)
        isCurUnitAvailable = true
    }
  }

  if (hasTeamData) { 
    if (!hasUnitsInSlotbar)
      res.reasonText = loc("events/empty_slotbar")
    else if (!hasRespawns && !isCurUnitAvailable)
      res.reasonText = loc("events/selected_craft_is_not_allowed")
    else if (!hasAnyAvailable)
      res.reasonText = loc("events/no_allowed_crafts")
    res.isAvailable = res.reasonText == ""
  }

  return res
}




function getLobbyRandomTeam() {
  let curCountry = SessionLobbyState.countryData?.country
  let teams = []
  let allTeams = events.getSidesList()
  foreach (team in allTeams) {
    let checkTeamResult = checkUnitsInSlotbar(curCountry, team)
    if (checkTeamResult.isAvailable)
      teams.append(team)
  }
  if (teams.len() == 0)
    teams.extend(allTeams)
  if (teams.len() == 1)
    return teams[0]
  let randomIndex = floor(teams.len() * frnd())
  return teams[randomIndex]
}

function canSetReadyInLobby(silent) {
  if (SessionLobbyState.spectator)
    return true

  let availTeam = getAvailableTeamOfRoom()
  if (availTeam == Team.none) {
    if (!silent)
      showInfoMsgBox(loc("events/no_selected_country"))
    return false
  }

  let curCountry = SessionLobbyState.countryData?.country
  let checkUnitsResult = checkUnitsInSlotbar(curCountry, availTeam)
  let res = checkUnitsResult.isAvailable
  if (!res && !silent)
    showInfoMsgBox(checkUnitsResult.reasonText)

  return res
}

function getRoomActiveTimers() {
  let res = []
  if (!isInSessionRoom.get())
    return res

  let curTime = getMatchingServerTime()
  foreach (timerId, cfg in roomTimers) {
    let tgtTime = getSessionLobbyPublicParam(cfg.publicKey, -1)
    if (tgtTime == -1 || !is_numeric(tgtTime) || tgtTime < curTime)
      continue

    let timeLeft = tgtTime - curTime
    res.append({
      id = timerId
      timeLeft = timeLeft
      text = colorize(cfg.color, cfg.getLocText(SessionLobbyState.settings, { time = secondsToString(timeLeft, true, true) }))
    })
  }
  return res
}


function getMembersCountByTeams(room = null, needReadyOnly = false) {
  let res = {
    total = 0,
    participants = 0,
    spectators = 0,
    [Team.Any] = 0,
    [Team.A] = 0,
    [Team.B] = 0
  }

  let roomMembers = getRoomMembers(room)
  if (room && !roomMembers.len()) {
    let teamsCount = room?.session.teams
    foreach (team in g_team.getTeams()) {
      let count = teamsCount?[team.id].players ?? 0
      res[team.code] = count
      res.total += count
    }
    return res
  }

  if (!isInSessionRoom.get() && !room)
    return res

  foreach (m in roomMembers) {
    if (isMemberHost(m))
      continue

    if (needReadyOnly)
      if (!hasSessionInLobby() && !isRoomMemberReady(m))
        continue
      else if (hasSessionInLobby() && !isRoomMemberInSession(m))
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

function isValidMissionLocName(mission) {
  if (mission?.mission.locNameTeamA != null)
    return !missionLocNameRegexp.match(mission.mission.locNameTeamA)
  return !missionLocNameRegexp.match(mission?.mission.locName ?? "")
}

function getRoomsInfoTbl(roomsList) {
  let res = []
  foreach (room in roomsList) {
    let public = room?.public
    let misData = public?.mission ?? {}
    let item = {
      hasPassword = public?.hasPassword ?? false
      numPlayers = getRoomMembersCnt(room)
      numPlayersTotal = getRoomSize(room)
    }
    if ("roomName" in public)
      item.mission <- public.roomName
    else if (isUrlMissionByRoom(public)) {
      let url = getMissionUrl(public)
      let urlMission =  g_url_missions.findMissionByUrl(url)
      let missionName = urlMission ? urlMission.name : url
      item.mission <- missionName
    }
    else {
      if (!isValidMissionLocName(public))
        continue
      item.mission <- getSessionLobbyMissionNameLoc(public)
    }
    if ("creator" in public)
      item.name <- getPlayerName(public?.creator ?? "")
    if ("difficulty" in misData)
      item.difficultyStr <- loc($"options/{misData.difficulty}")
    res.append(item)
  }
  return res
}

function getMisListType(v_settings = null) {
  if (isUserMission(v_settings))
    return g_mislist_type.UGM
  if (isUrlMissionByRoom(v_settings))
    return g_mislist_type.URL
  return g_mislist_type.BASE
}

return {
  getRoomEvent
  getSessionLobbyMissionNameLoc
  haveLobby
  canInvitePlayerToSessionRoom
  needAutoInviteSquadToSessionRoom
  getSessionLobbyTimeLimit
  getRoomSpecialRules
  getRoomTeamData
  isUnitAllowedForRoom
  hasUnitRequirementsInRoom
  isUnitRequiredForRoom
  getSessionLobbyLockedCountryData
  getSessionLobbyMissionNameLocIdsArray
  getRoomRequiredCrafts
  getRoomMGameMode
  getRoomRankCalcMode
  getRoomMaxDisbalance
  getRoomUnitTypesMask
  getRoomRequiredUnitTypesMask
  getRoomTeamsCountries
  getAvailableTeamOfRoom
  canChangeTeamInLobby
  getBattleRatingParamByPlayerInfo
  getNotAvailableUnitByBRText
  isMemberInMySquadByName
  isMemberInMySquadById
  canBeSpectator
  getLobbyRandomTeam
  canSetReadyInLobby
  getRoomActiveTimers
  getMembersCountByTeams
  getRoomsInfoTbl
  getMisListType
}
