from "%scripts/dagui_library.nut" import *

let { INVALID_SQUAD_ID } = require("matching.errors")
let u = require("%sqStdLibs/helpers/u.nut")
let { getSessionLobbyGameMode, getSessionLobbyPlayersInfo
} = require("%scripts/matchingRooms/sessionLobbyState.nut")

let listLabelsSquad = {}
let nextLabel = { team1 = 1, team2 = 1 }
local topSquads = {}
let playersInfo = mkWatched(persist, "playersInfo", {})

let getPlayersInfo = @() playersInfo.get()
function updateIconPlayersInfo() {
  let sessionPlayersInfo = getSessionLobbyPlayersInfo()
  if (sessionPlayersInfo.len() > 0 && !u.isEqual(playersInfo.get(), sessionPlayersInfo))
    playersInfo.set(clone sessionPlayersInfo)
}

function initListLabelsSquad() {
  listLabelsSquad.clear()
  nextLabel.team1 = 1
  nextLabel.team2 = 1
  topSquads = {}
  playersInfo.set({})
  updateIconPlayersInfo()
}

function updateListLabelsSquad() {
  foreach (teamSquads in listLabelsSquad)
    foreach (label in teamSquads)
      label.count = 0

  foreach (_uid, member in getPlayersInfo()) {
    let teamId = member.team
    let teamName = $"team{teamId}"
    if (!(teamName in nextLabel))
      continue

    let squadId = member?.squad ?? INVALID_SQUAD_ID
    if (squadId == INVALID_SQUAD_ID)
      continue
    if (teamId not in listLabelsSquad)
      listLabelsSquad[teamId] <- {}
    let teamSquads = listLabelsSquad[teamId]
    if (squadId in teamSquads) {
      let curSquad = teamSquads[squadId]
      if (curSquad.count < 2) {
        curSquad.count++
        if (curSquad.count > 1 && curSquad.label == "") {
          curSquad.label = nextLabel[teamName].tostring()
          nextLabel[teamName]++
        }
      }
    }
    else
      teamSquads[squadId] <- {
        squadId
        count = 1
        label = ""
        autoSquad = member?.auto_squad ?? false
        teamId
      }
  }
}

function getSquadInfo(teamId, squadId) {
  if (squadId == INVALID_SQUAD_ID)
    return null
  let squad = listLabelsSquad?[teamId][squadId]
  if (squad == null || squad.count < 2)
    return null
  return squad
}

function getSquadInfoByMemberId(userId) {
  if (userId == null)
    return null

  foreach (uid, member in getPlayersInfo())
    if (uid == userId)
      return getSquadInfo(member.team, member.squad)

  return null
}

let isShowSquad = @() getSessionLobbyGameMode() != GM_SKIRMISH
function updateTopSquadScore(mplayers) {
  if (!isShowSquad())
    return
  let teamId = mplayers.len() ? getTblValue("team", mplayers[0], null) : null
  if (teamId == null)
    return

  local topSquadId = null

  local topSquadScore = 0
  let squads = {}
  foreach (player in mplayers) {
    let squadScore = getTblValue("squadScore", player, 0)
    if (!squadScore || squadScore < topSquadScore)
      continue
    let squadId = getTblValue("squadId", getSquadInfoByMemberId(player?.userId.tointeger()), INVALID_SQUAD_ID)
    if (squadId == INVALID_SQUAD_ID)
      continue
    if (squadScore > topSquadScore) {
      topSquadScore = squadScore
      squads.clear()
    }
    let score = getTblValue("score", player, 0)
    if (!(squadId in squads))
      squads[squadId] <- { playerScore = 0, members = 0 }
    squads[squadId].playerScore += score
    squads[squadId].members++
  }

  local topAvgPlayerScore = 0.0
  foreach (squadId, data in squads) {
    let avg = data.playerScore * 1.0 / data.members
    if (topSquadId == null || avg > topAvgPlayerScore) {
      topSquadId = squadId
      topAvgPlayerScore = avg
    }
  }

  topSquads[teamId] <- topSquadId
}

let getTopSquadId = @(teamId) topSquads?[teamId]

return {
  getPlayersInfo
  initListLabelsSquad
  updateIconPlayersInfo
  updateTopSquadScore
  updateListLabelsSquad
  getSquadInfo
  isShowSquad
  getSquadInfoByMemberId
  getTopSquadId
}
