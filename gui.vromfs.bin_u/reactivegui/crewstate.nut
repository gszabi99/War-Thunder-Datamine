from "%rGui/globals/ui_library.nut" import *

let interopGen = require("%rGui/interopGen.nut")
let { register_command } = require("console")

let crewState = {
  totalCrewCount = Watched(0)
  aliveCrewMembersCount = Watched(0)
  minCrewMembersCount = Watched(1)
  bestMinCrewMembersCount = Watched(1)
  totalCrewMembersCount = Watched(1)
  driverAlive = Watched(false)
  gunnerAlive = Watched(false)
}


interopGen({
  stateTable = crewState
  prefix = "crew"
  postfix = "Update"
})

register_command(@(val) crewState.aliveCrewMembersCount.set(crewState.aliveCrewMembersCount.get() - val), "hud.shipCrewDamage")

return crewState
