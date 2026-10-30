import "%rGui/interopGen.nut" as interopGet
import "%globalScripts/missionTeamScores.nut" as missionTeamScores
from "%rGui/globals/ui_library.nut" import *

let missionState = {
  gameType = Watched(0)
  gameOverReason = Watched(0)
  timeLeft = Watched(900)
  roundTimeLeft = Watched(900)
  localTeam = Watched(0)
  scoreLimit = Watched(0)
  deathPenaltyMul = Watched(1.0)
  ctaDeathTicketPenalty = Watched(1)
  timeLimitWarn = Watched(-1)
  customHUD = Watched("")
  missionProgressScore = Watched(0)
  missionProgressScoreEnemy = Watched(0)
  missionProgressAttackShip = Watched(0)
  missionProgressDefendShip = Watched(0)
  isZoneALocal = Watched(false)
  totalDomEnabled = Watched(false)
  totalDomTeam = Watched(0)
  totalDomMult = Watched(0)
  totalDomNextMult = Watched(0)
  totalDomSecLeft = Watched(0)
}

interopGet({
  stateTable = missionState
  prefix = "mission"
  postfix = "Update"
})


return freeze(missionState.__merge(missionTeamScores))
