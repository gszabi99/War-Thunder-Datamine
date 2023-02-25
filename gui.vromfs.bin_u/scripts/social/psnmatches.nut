//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let psn = require("%sonyLib/webApi.nut")
let { isPS4PlayerName } = require("%scripts/clientState/platform.nut")
let { getActivityByGameMode } = require("%scripts/gameModes/psnActivities.nut")
let { reqPlayerExternalIDsByUserId } = require("%scripts/user/externalIdsService.nut")

let match = {
  id = null
  isOwner = false
  playerId = null
  teamId = null
  props = { // Reflects PSN structure
    activityId = null
    inGameRoster = {
      teams = [ { teamId = Team.A }, { teamId = Team.B } ]
    }
  }
  lastId = null
  players = {}
}

let function processMemberList(members) {
  let players = {}
  local minMemberId = null
  foreach (m in members) {
    let isMe = ::is_my_userid(m.userId)
    if (isPS4PlayerName(m.name)) {
      let pinfo = ::SessionLobby.getMemberPlayerInfo(m.userId)
      if (pinfo?.team != null) { // skip those, whose side is not yet known - can't send'em to PSN
        let player = { // reflects PSN structure
          playerId = m.memberId
          teamId = pinfo.team
          accountId = isMe ? ::ps4_get_account_id() : null
          playerType = "PSN_PLAYER"
        }
        players[m.userId.tostring()] <- player
        if (isMe)
          match.teamId = player.teamId
      }
      minMemberId = (minMemberId) == null ? m.memberId : min(m.memberId, minMemberId)
    }
    if (isMe)
      match.playerId = m.memberId
  }
  let isOwner = (match.playerId <= minMemberId)
  return { players, isOwner }
}

let function addPlayerToMatch(uid) {
  let player = match.players[uid]
  log($"[PSMT] adding {uid}/{player.playerId} to {player.teamId} for {match.id}")
  psn.send(psn.matches.join(match.id, player))
}

let function onReceivedExternalIds(data) {
  if (match.id == null)
    return

  let uid = data.request.uid
  if (uid in match.players) {
    match.players[uid].accountId = data.externalIds.psnId
    addPlayerToMatch(uid)
  }
}

let function updateMatchData() {
  let updated = processMemberList(::SessionLobby.members)
  if (!updated.isOwner || match.id == null)
    return

  let newPlayers = updated.players.filter(@(_v, k) !(k in match.players))
  let lostPlayers = match.players.filter(@(_v, k) !(k in updated.players))
  match.players = updated.players

  foreach (uid, player in newPlayers) {
    if (player.accountId == null)
      reqPlayerExternalIDsByUserId(uid)
    else
      addPlayerToMatch(uid)
  }

  foreach (p in lostPlayers) {
    log($"[PSMT] member {p.playerId} left {match.id}/{p.teamId}")
    psn.send(psn.matches.leave(match.id, { playerId = p.playerId, reason = psn.matches.LeaveReason.QUIT }))
  }
}


let function tryCreateMatch(info) {
  match.props.activityId = getActivityByGameMode(info?.public?.game_mode_name)
  if (match.props.activityId == null)
    return

  let updated = processMemberList(info.members)
  log($"[PSMT] try create match for {match.props.activityId}/{info?.public?.game_mode_name} as {updated.isOwner}")
  if (updated.isOwner && match.id == null) {
    psn.send(psn.matches.create(match.props), function(r, _e) {
        match.isOwner = true
        match.id = r?.matchId
        updateMatchData()
      })
  }
}

let function markMatchCompleted() {
  match.lastId = match.id
  match.id = null
  match.teamId = null
  match.players = {}
}

let function leaveMatch(reason = psn.matches.LeaveReason.FINISHED) {
  if (match.id == null)
    return

  let player = {
    playerId = match.playerId,
    reason = reason // TODO: set proper reason. How to determine?
  }
  log($"[PSMT] leaving match {match.id}, reason {reason}")
  psn.send(psn.matches.leave(match.id, player))
  markMatchCompleted()
}

let function updateMatchStatus(_eventData) {
  if (match.id == null)
    return

  if (::SessionLobby.myState == PLAYER_IN_FLIGHT) {
    log($"starting match {match.id}")
    psn.send(psn.matches.updateStatus(match.id, "PLAYING"))
  }
}

let function onBattleEnded(p) {
  if (match.id == null || p?.battleResult == null)
    return

  let isVictoryOurs = (p.battleResult == STATS_RESULT_SUCCESS)
  let winnerTeamId = isVictoryOurs ? match.teamId : (3 - match.teamId) // only two teams
  let teamResults = []
  foreach (team in match.props.inGameRoster.teams) {
    teamResults.append({
      teamId = $"{team.teamId}",
      rank = $"{(winnerTeamId == team.teamId) ? 1 : 2}"
    })
  }

  psn.send(psn.matches.reportResults(match.id, { teamResults }))
  markMatchCompleted()
}

let function enableMatchesReporting() {
  log("[PSMT] enabling matches reporting")
  ::add_event_listener("RoomJoined", tryCreateMatch)
  ::add_event_listener("LobbyMembersChanged", @(_p) updateMatchData())
  ::add_event_listener("LobbyMemberInfoChanged", @(_p) updateMatchData())
  ::add_event_listener("LobbyStatusChange", updateMatchStatus)
  ::add_event_listener("PlayerQuitMission", @(_p) leaveMatch(psn.matches.LeaveReason.QUIT))
  ::add_event_listener("UpdateExternalsIDs", onReceivedExternalIds)
  ::add_event_listener("BattleEnded", onBattleEnded)
}

return {
  enableMatchesReporting
}
