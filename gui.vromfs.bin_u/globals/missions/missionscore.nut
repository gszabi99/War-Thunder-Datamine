import "%sqstd/ecs.nut" as ecs
from "%appGlobals/missions/nuclearEscalationCfg.nut" import yieldLimitFromStage

let missionScoreQuery = ecs.SqQuery("missionScoreQuery", { comps_ro = [
  ["mission_score__scoreTeamA", ecs.TYPE_INT],
  ["mission_score__ticketsTeamA", ecs.TYPE_INT],
  ["mission_score__ticketsTeamB", ecs.TYPE_INT]
] })


let getMissionScore = @() missionScoreQuery.perform(@(_eid, comp) {
  ffaMaxScore = comp.mission_score__scoreTeamA
  ticketsA = comp.mission_score__ticketsTeamA
  ticketsB = comp.mission_score__ticketsTeamB
}) ?? { ffaMaxScore = 0, ticketsA = 0, ticketsB = 0 }

function getAllowedNuclearYield(mis) {
  let { ticketsA, ticketsB } = getMissionScore()
  let getTeamScore = @(tickets) tickets > 0 ? mis.scoreLimit - tickets : 0
  let sumScore = getTeamScore(ticketsA) + getTeamScore(ticketsB)
  local escalationStage = 0
  for (local stage = 1; stage <= 3; stage++) {
    let stageScore = mis[$"nuclearEscalationStage{stage}"]
    if (stageScore > 0 && sumScore >= stageScore)
      escalationStage = stage
  }
  return yieldLimitFromStage?[escalationStage] ?? 0
}

return freeze({
  getMissionScore
  getAllowedNuclearYield
})
