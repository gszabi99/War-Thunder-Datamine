from "%rGui/globals/ui_library.nut" import *
from "hudState" import hud_request_hud_crew_state

let { eventbus_subscribe } = require("eventbus")

let crewState = Watched({ current = 0, total = 0, regenerating = false})
let crewGunnerState = Watched({ state = "ok" })
let crewDriverState = Watched({ state = "ok" })
let distance = Watched({ distance = 0 })

eventbus_subscribe("CrewState:CrewState", @(data) crewState.set(data))
eventbus_subscribe("CrewState:GunnerState", @(data) crewGunnerState.set(data))
eventbus_subscribe("CrewState:DriverState", @(data) crewDriverState.set(data))
eventbus_subscribe("CrewState:Distance", @(data) distance.set(data))

return {
  crewState
  crewGunnerState
  crewDriverState
  distance
  reInitHudCrewStates = hud_request_hud_crew_state
}
