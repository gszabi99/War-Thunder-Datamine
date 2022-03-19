local interopGet = require("interopGen.nut")

local missionState = {
  gameType = Watched(0)
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
}


interopGet({
  stateTable = missionState
  prefix = "mission"
  postfix = "Update"
})


return missionState
