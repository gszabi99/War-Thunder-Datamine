from "%rGui/globals/ui_library.nut" import *

let interopGet = require("interopGen.nut")

let missionState = {
  gameType = Watched(0)
  gameOverReason = Watched(0)
  timeLeft = Watched(900)
  roundTimeLeft = Watched(900)
  scoreTeamA = Watched(0)
  scoreTeamB = Watched(0)
  ticketsTeamA = Watched(0)
  ticketsTeamB = Watched(0)
  localTeam = Watched(0)
  scoreLimit = Watched(0)
  deathPenaltyMul = Watched(1.0)
  ctaDeathTicketPenalty = Watched(1)
  useDeathmatchHUD = Watched(false)
  timeLimitWarn = Watched(-1)
  customHUD = Watched("")
  missionProgressScore = Watched(0)
  missionProgressScoreEnemy = Watched(0)
}


interopGet({
  stateTable = missionState
  prefix = "mission"
  postfix = "Update"
})


return missionState
