local psn = require("sonyLib/webApi.nut")
local { open_player_review, PlayerReviewMode } = require("sony.social")
local { isPS4PlayerName } = require("scripts/clientState/platform.nut")
local { getActivityByGameMode } = require("scripts/gameModes/psnActivities.nut")
local { reqPlayerExternalIDsByUserId } = require("scripts/user/externalIdsService.nut")

local match = {
  id = null
  isOwner = false
  playerId = null
  props = { // Reflects PSN structure
    activityId = null
    inGameRoster = {
      teams = [ { teamId = Team.A }, { teamId = Team.B } ]
    }
  }
  lastId = null
  players = {}
}

local function processMemberList(members) {
  local players = {}
  local minMemberId = null
  foreach (m in members) {
    local isMe = ::is_my_userid(m.userId)
    if (isPS4PlayerName(m.name)) {
      local pinfo = ::SessionLobby.getMemberPlayerInfo(m.userId)
      if (pinfo?.team != null) { // skip those, whose side is not yet known - can't send'em to PSN
        local player = { // reflects PSN structure
          playerId = m.memberId
          teamId = pinfo.team
          accountId = isMe ? ::ps4_get_account_id() : null
          playerType = "PSN_PLAYER"
        }
        players[m.userId.tostring()] <- player
      }
      minMemberId = (minMemberId) == null ? m.memberId : ::min(m.memberId, minMemberId)
    }
    if (isMe)
      match.playerId = m.memberId
  }
  local isOwner = (match.playerId <= minMemberId)
  return { players, isOwner }
}

local function addPlayerToMatch(uid) {
  local player = match.players[uid]
  ::dagor.debug($"[PSMT] adding {uid}/{player.playerId} to {player.teamId} for {match.id}")
  psn.send(psn.matches.join(match.id, player))
}

local function onReceivedExternalIds(data) {
  if (match.id == null)
    return

  local uid = data.request.uid
  if (uid in match.players) {
    match.players[uid].accountId = data.externalIds.psnId
    addPlayerToMatch(uid)
  }
}

local function updateMatchData() {
  local updated = processMemberList(::SessionLobby.members)
  if (!updated.isOwner || match.id == null)
    return

  local newPlayers = updated.players.filter(@(v, k) !(k in match.players))
  local lostPlayers = match.players.filter(@(v, k) !(k in updated.players))
  match.players = updated.players

  foreach (uid, player in newPlayers) {
    if (player.accountId == null)
      reqPlayerExternalIDsByUserId(uid)
    else
      addPlayerToMatch(uid)
  }

  foreach (p in lostPlayers) {
    ::dagor.debug($"[PSMT] member {p.playerId} left {match.id}/{p.teamId}")
    psn.send(psn.matches.leave(match.id, { playerId = p.playerId, reason = psn.matches.LeaveReason.QUIT}))
  }
}


local function tryCreateMatch(info) {
  match.props.activityId = getActivityByGameMode(info?.public?.game_mode_name)
  if (match.props.activityId == null)
    return

  local updated = processMemberList(info.members)
  ::dagor.debug($"[PSMT] try create match for {match.props.activityId}/{info?.public?.game_mode_name} as {updated.isOwner}")
  if (updated.isOwner && match.id == null) {
    psn.send(psn.matches.create(match.props), function(r, e) {
        match.isOwner = true
        match.id = r?.matchId
        updateMatchData()
      })
  }
}


local function leaveMatch(reason=psn.matches.LeaveReason.FINISHED) {
  if (match.id == null)
    return

  local player = {
    playerId = match.playerId,
    reason = reason // TODO: set proper reason. How to determine?
  }
  ::dagor.debug($"[PSMT] leaving match {match.id}, reason {reason}")
  psn.send(psn.matches.leave(match.id, player))
  match.lastId = match.id
  match.id = null
  match.players = {}
}

local function updateMatchStatus(eventData) {
  if (match.id == null)
    return

  if (::SessionLobby.myState == ::PLAYER_IN_FLIGHT) {
    ::dagor.debug($"starting match {match.id}")
    psn.send(psn.matches.updateStatus(match.id, "PLAYING"))
  }
}

local function onIsInRoomChanged(p) {
  if (!::SessionLobby.isInRoom())
    leaveMatch()
}

local function enableMatchesReporting() {
  ::dagor.debug("[PSMT] enabling matches reporting")
  ::add_event_listener("RoomJoined", tryCreateMatch)
  ::add_event_listener("LobbyMembersChanged", @(p) updateMatchData())
  ::add_event_listener("LobbyMemberInfoChanged", @(p) updateMatchData())
  ::add_event_listener("LobbyStatusChange", updateMatchStatus)
  ::add_event_listener("LobbyIsInRoomChanged", onIsInRoomChanged)
  ::add_event_listener("PlayerQuitMission", @(p) leaveMatch(psn.matches.LeaveReason.QUIT))
  ::add_event_listener("UpdateExternalsIDs", onReceivedExternalIds)
}

local function openPlayerReviewDialog() {
  // Currently we only have Team matches set up
  local id = match.lastId || match.id
  if (id != null)
    open_player_review(id, PlayerReviewMode.TEAM_ONLY, @(r) null)
}

return {
  enableMatchesReporting
  canOpenPlayerReviewDialog = @() match.lastId != null
  openPlayerReviewDialog
}
