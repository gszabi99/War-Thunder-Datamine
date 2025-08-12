from "%scripts/dagui_natives.nut" import script_net_assert
from "%scripts/dagui_library.nut" import *
from "%scripts/teamsConsts.nut" import Team
from "%scripts/utils_sa.nut" import is_mode_with_teams

let { getRoomMembers, isUserCanChangeReadyInLobby, hasSessionInLobby, isInSessionRoom,
  SessionLobbyState, isMeSessionLobbyRoomOwner, getSessionLobbyGameType, getSessionLobbyMissionParam,
  getSessionLobbyMaxMembersCount, getMemberByName, isMemberHost
} = require("%scripts/matchingRooms/sessionLobbyState.nut")
let { getUserInfo } = require("%scripts/user/usersInfoManager.nut")
let { invitePlayerToRoom, kickMember } = require("%scripts/matching/serviceNotifications/mroomsApi.nut")
let { isMyUserId } = require("%scripts/user/profileStates.nut")
let { checkMatchingError } = require("%scripts/matching/api.nut")
let { INVALID_ROOM_ID, INVALID_SQUAD_ID } = require("matching.errors")
let { abs } = require("math")
let { get_local_mplayer } = require("mission")

let memberDefaults = freeze({
  team = Team.Any
  country = "country_0"
  squad = INVALID_SQUAD_ID
  spectator = false
  ready = false
  is_in_session = false
  clanTag = ""
  title = ""
  selAirs = ""
  state = PLAYER_IN_LOBBY_NOT_READY
})

function getRoomMemberPublicParam(member, param) {
  return member?.public[param] ?? memberDefaults[param]
}

function isRoomMemberInSession(member) {
  return getRoomMemberPublicParam(member, "is_in_session")
}

function isRoomMemberReady(member) {
  return getRoomMemberPublicParam(member, "ready")
}

function getRoomMemberInfo(member) {
  if (!member)
    return null
  let userInfo = getUserInfo(member.userId.tostring())
  let pub = member?.public ?? {}
  let res = {
    memberId = member.memberId
    userId = member.userId.tostring() 
    name = member.name
    isLocal = isMyUserId(member.userId)
    spectator = getTblValue("spectator", member, false)
    isBot = false
    pilotIcon = userInfo?.pilotIcon ?? ""
    pilotId = userInfo?.pilotId ?? ""
    frame = userInfo?.frame ?? ""
  }
  foreach (key, value in memberDefaults)
    res[key] <- (key in pub) ? pub[key] : value

  if (hasSessionInLobby()) {
    if (res.state == PLAYER_IN_LOBBY_NOT_READY || res.state == PLAYER_IN_LOBBY_READY)
      res.state = isRoomMemberInSession(member) ? PLAYER_IN_LOBBY_READY : PLAYER_IN_LOBBY_NOT_READY
  }
  else if (!isUserCanChangeReadyInLobby() && res.state == PLAYER_IN_LOBBY_NOT_READY)
    res.state = PLAYER_IN_LOBBY_READY 
  return res
}

function getRoomMembersInfoList(room = null) {
  let res = []
  foreach (member in getRoomMembers(room))
    if (!isMemberHost(member))
      res.append(getRoomMemberInfo(member))
  return res
}

function isRoomMemberOperator(member) {
  return member?.public.operator
}

function invitePlayerToSessionRoom(uid) {
  if (SessionLobbyState.roomId == INVALID_ROOM_ID) { 
    let is_in_room = isInSessionRoom.get()                   
    let room_id = SessionLobbyState.roomId                          
    script_net_assert("trying to invite into room without roomId")
    return
  }

  let params = { roomId = SessionLobbyState.roomId, userId = uid, password = SessionLobbyState.password }
  invitePlayerToRoom(params, @(p) checkMatchingError(p, false))
}

function kickPlayerFromRoom(member) {
  if (!("memberId" in member) || !isMeSessionLobbyRoomOwner.get() || !isInSessionRoom.get())
    return

  foreach (_idx, m in SessionLobbyState.members)
    if (m.memberId == member.memberId)
      kickMember({ roomId = SessionLobbyState.roomId, memberId = member.memberId }, function(p) { checkMatchingError(p) })
}





function isUsedPlayersOwnUnit(member, unitId) {
  return (member?.crafts_info ?? []).findvalue(@(ci) ci.name == unitId) != null
}

function getRoomMembersReadyStatus() {
  let res = {
    readyToStart = true
    ableToStart = false 
    haveNotReady = false
    statusText = loc("multiplayer/readyToGo")
  }

  let teamsCount = {
    [Team.Any] = 0,
    [Team.A] = 0,
    [Team.B] = 0
  }

  foreach (_idx, member in SessionLobbyState.members) {
    let ready = isRoomMemberReady(member)
    let spectator = getRoomMemberPublicParam(member, "spectator")
    let team = getRoomMemberPublicParam(member, "team").tointeger()
    res.haveNotReady = res.haveNotReady || (!ready && !spectator)
    res.ableToStart = res.ableToStart || !spectator
    if (ready && !spectator) {
      if (team in teamsCount)
        teamsCount[team]++
      else
        teamsCount[Team.Any]++
    }
  }

  res.readyToStart = !res.haveNotReady
  if (res.haveNotReady)
    res.statusText = loc("multiplayer/not_all_ready")

  let gt = getSessionLobbyGameType()
  let checkTeams = is_mode_with_teams(gt)
  if (!checkTeams)
    return res

  let haveBots = getSessionLobbyMissionParam("isBotsAllowed", false)
  let maxInTeam = (0.5 * getSessionLobbyMaxMembersCount() + 0.5).tointeger()

  if ((!haveBots && (abs(teamsCount[Team.A] - teamsCount[Team.B]) - teamsCount[Team.Any] > 1))
      || teamsCount[Team.A] > maxInTeam || teamsCount[Team.B] > maxInTeam) {
    res.readyToStart = false
    res.statusText = loc("multiplayer/nonBalancedGame")
  }

  let areAllowedEmptyTeams = getSessionLobbyMissionParam("allowEmptyTeams", false)
  if (!res.ableToStart || (!haveBots && !areAllowedEmptyTeams)) {
    let minInTeam = 1
    let teamAEnough = (teamsCount[Team.A] + teamsCount[Team.Any]) >= minInTeam
    let teamBEnough = (teamsCount[Team.B] + teamsCount[Team.Any]) >= minInTeam
    let teamsTotalEnough = teamsCount[Team.A] + teamsCount[Team.B] + teamsCount[Team.Any] >= minInTeam * 2
    if (!teamAEnough || !teamBEnough || !teamsTotalEnough) {
      res.readyToStart = false
      res.ableToStart = false
      res.statusText = loc(res.haveNotReady ? "multiplayer/notEnoughReadyPlayers" : "multiplayer/notEnoughPlayers")
    }
  }

  return res
}

function isPlayerDedicatedSpectator(name = null) {
  if (name) {
    let member = isInSessionRoom.get() ? getMemberByName(name) : null
    return member ? !!getRoomMemberPublicParam(member, "spectator") : false
  }
  return !!get_local_mplayer()?.spectator
}
::cross_call_api.isPlayerDedicatedSpectator <- isPlayerDedicatedSpectator

return {
  getRoomMemberPublicParam
  isRoomMemberInSession
  isRoomMemberReady
  getRoomMembersInfoList
  isRoomMemberOperator
  invitePlayerToSessionRoom
  kickPlayerFromRoom
  isUsedPlayersOwnUnit
  getRoomMembersReadyStatus
  isPlayerDedicatedSpectator
}