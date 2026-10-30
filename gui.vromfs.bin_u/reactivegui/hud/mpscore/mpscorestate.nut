from "%sqstd/ecs.nut" import TYPE_INT, TYPE_ARRAY
from "ecs.computed" import mkEcsComputed, mkEcsComputedEidMap
from "mission" import get_local_mplayer
from "%rGui/missionState.nut" import gameType, customHUD, scoreLimit, ticketsTeamA, ticketsTeamB, scoreTeamA as ffaKillLimit
from "%rGui/hudState.nut" import playerArmyForHud
from "%globalScripts/gameTypeConsts.nut" import GT_MP_SCORE, GT_MP_TICKETS, GT_FOOTBALL, GT_RACE
from "%rGui/globals/ui_library.nut" import *

enum MpScoreMode {
  NONE
  TEAMS
  FFA
}

let playerKills = mkEcsComputedEidMap({ comps = [["player_id", TYPE_INT], ["player__kills", TYPE_INT]] })

let bases = mkEcsComputed({ comps = [["mission_score__bases", TYPE_ARRAY]], defVal = [] })
let captureZones = mkEcsComputed({ comps = [["mission_score__captureZones", TYPE_ARRAY]], defVal = [] })


let mpScoreMode = Computed(function() {
  let gt = gameType.get()
  if (customHUD.get() != "")
    return MpScoreMode.NONE
  if ((gt & GT_MP_SCORE) != 0 && (gt & GT_FOOTBALL) == 0)
    return (gt & GT_RACE) != 0 ? MpScoreMode.NONE : MpScoreMode.FFA
  return (gt & GT_MP_TICKETS) != 0 ? MpScoreMode.TEAMS : MpScoreMode.NONE
})

let playerTeam = Computed(@() (playerArmyForHud.get() == 1 || playerArmyForHud.get() == 2) ? playerArmyForHud.get() : 0)
let toSides = @(team, valueA, valueB) team == 2 ? { player = valueB, enemy = valueA } : { player = valueA, enemy = valueB }


let teamBarParts = Computed(function() {
  let team = playerTeam.get()
  if (team == 0)
    return null
  let limit = scoreLimit.get()
  let getPart = @(tickets) limit > 0 ? clamp(tickets.tofloat() / limit, 0.0, 1.0) : 0.0
  return toSides(team, getPart(ticketsTeamA.get()), getPart(ticketsTeamB.get()))
})


let ticketDrops = Computed(function(prev) {
  let ticketsA = ticketsTeamA.get()
  let ticketsB = ticketsTeamB.get()
  let isFirst = prev == FRP_INITIAL
  return {
    ticketsA
    ticketsB
    dropsA = isFirst ? 0 : prev.dropsA + (ticketsA < prev.ticketsA ? 1 : 0)
    dropsB = isFirst ? 0 : prev.dropsB + (ticketsB < prev.ticketsB ? 1 : 0)
  }
})

let teamBarDrops = Computed(@() toSides(playerTeam.get(), ticketDrops.get().dropsA, ticketDrops.get().dropsB))

function getFfaLine(players, localId, maxScore) {
  local own = 0
  foreach (p in players)
    if (p.player_id == localId)
      own = p.player__kills
  local leader = 0
  local rank = 1
  foreach (p in players) {
    leader = max(leader, p.player__kills)
    if (p.player__kills > own)
      rank++
  }
  return $"{own} / {leader} / {maxScore}  {loc("sm_rank")}:{rank}"
}


let ffaLine = Computed(@() getFfaLine(playerKills.get(), get_local_mplayer()?.id, ffaKillLimit.get()))

return freeze({
  MpScoreMode
  mpScoreMode
  playerTeam
  teamBarParts
  teamBarDrops
  playerKills
  getFfaLine
  ffaLine
  bases
  captureZones
})
