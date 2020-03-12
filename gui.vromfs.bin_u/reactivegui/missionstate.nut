local interopGet = require("daRg/helpers/interopGen.nut")

local missionState = {
  gameType = Watched(0)
  timeLeft = Watched(900)
  scoreTeamA = Watched(0)
  scoreTeamB = Watched(0)
  localTeam = Watched(0)
}


interopGet({
  stateTable = missionState
  prefix = "mission"
  postfix = "Update"
})


return missionState
