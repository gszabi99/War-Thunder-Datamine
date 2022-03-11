local interopGet = require("interopGen.nut")

local crewState = {
  totalCrewCount = Watched(0)
  aliveCrewMembersCount = Watched(0)
  minCrewMembersCount = Watched(1)
  bestMinCrewMembersCount = Watched(1)
  totalCrewMembersCount = Watched(1)
  driverAlive = Watched(false)
  gunnerAlive = Watched(false)
}


interopGet({
  stateTable = crewState
  prefix = "crew"
  postfix = "Update"
})


return crewState
