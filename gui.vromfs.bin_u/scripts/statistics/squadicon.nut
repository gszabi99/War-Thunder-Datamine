from "%scripts/dagui_library.nut" import *

let { INVALID_SQUAD_ID } = require("matching.errors")
let u = require("%sqStdLibs/helpers/u.nut")
let listLabelsSquad = {}
let nextLabel = { team1 = 1, team2 = 1 }
local topSquads = {}
let playersInfo = mkWatched(persist, "playersInfo", {})

let getPlayersInfo = @() playersInfo.value
function updateIconPlayersInfo() {
  let sessionPlayersInfo = ::SessionLobby.getPlayersInfo()
  if (sessionPlayersInfo.len() > 0 && !u.isEqual(playersInfo.value, sessionPlayersInfo))
    playersInfo(clone sessionPlayersInfo)
}

function initListLabelsSquad() {
  listLabelsSquad.clear()
  nextLabel.team1 = 1
  nextLabel.team2 = 1
  topSquads = {}
  playersInfo({})
  updateIconPlayersInfo()
}

function updateListLabelsSquad() {
  foreach (label in listLabelsSquad)
    label.count = 0;
  local team = ""
  foreach (_uid, member in getPlayersInfo()) {
    team = $"team{member.team}"
    if (!(team in nextLabel))
      continue

    let squadId = member.squad
    if (squadId == INVALID_SQUAD_ID)
      continue
    if (squadId in listLabelsSquad) {
      if (listLabelsSquad[squadId].count < 2) {
        listLabelsSquad[squadId].count++
        if (listLabelsSquad[squadId].count > 1 && listLabelsSquad[squadId].label == "") {
          listLabelsSquad[squadId].label = nextLabel[team].tostring()
          nextLabel[team]++
        }
      }
    }
    else
      listLabelsSquad[squadId] <- {
        squadId = squadId
        count = 1
        label = ""
        autoSquad = getTblValue("auto_squad", member, false)
        teamId = member.team
      }
  }
}

function getSquadInfo(idSquad) {
  if (idSquad == INVALID_SQUAD_ID)
    return null
  let squad = (idSquad in listLabelsSquad) ? listLabelsSquad[idSquad] : null
  if (squad == null)
    return null
  else if (squad.count < 2)
    return null
  return squad
}

function getSquadInfoByMemberId(userId) {
  if (userId == null)
    return null

  foreach (uid, member in getPlayersInfo())
    if (uid == userId)
      return getSquadInfo(member.squad)

  return null
}

let isShowSquad = @() ::SessionLobby.getGameMode() != GM_SKIRMISH
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
    let squadId = getTblValue("squadId", getSquadInfoByMemberId(player?.id), INVALID_SQUAD_ID)
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
