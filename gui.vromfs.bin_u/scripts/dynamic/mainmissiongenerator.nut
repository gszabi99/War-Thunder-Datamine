
let { registerRespondent } = require("scriptRespondent")
let { genHeadToHeadMission } = require("%scripts/dynamic/headtohead.nut")
let { genCombatPatrolMission } = require("%scripts/dynamic/combat_patrol.nut")
let { genBombingVehiclesMission, genBombingAntiTankMission, genBombingBuildingsMission,
  genBombingShipsMission, genBombingCarrierMission } = require("%scripts/dynamic/bombing.nut")
let { genFreeFlightMission } = require("%scripts/dynamic/freeflight.nut")
let { genWayPointFlightMission } = require("%scripts/dynamic/waypointflight.nut")
let { genInterceptBombingMission } = require("%scripts/dynamic/bombing_intercept.nut")
let { genCoverMission } = require("%scripts/dynamic/cover_bombers.nut")
let { genBombingDefenseMission } = require("%scripts/dynamic/bombing_defense.nut")
let { genAssaultDefenseMission } = require("%scripts/dynamic/assault_defense.nut")
let { genAssaultFirstMission, genAssaultSecondMission, genAssaultThirdMission
} = require("%scripts/dynamic/assault.nut")
let { genCoverGattackMission } = require("%scripts/dynamic/cover_assault.nut")

let missionGenFunctions = [
  genHeadToHeadMission
  genCombatPatrolMission
  genBombingVehiclesMission
  genBombingAntiTankMission
  genBombingBuildingsMission
  genBombingShipsMission
  genBombingCarrierMission
  genFreeFlightMission
  genWayPointFlightMission
  genInterceptBombingMission
  genCoverMission
  genBombingDefenseMission
  genAssaultDefenseMission
  genAssaultFirstMission
  genAssaultSecondMission
  genAssaultThirdMission
  genCoverGattackMission
]

local currentMissionNo = 0


registerRespondent("beginMissionsGeneration", function beginMissionsGeneration() {
  currentMissionNo = 0
})

registerRespondent("generateNextMission", function generateNextMission(isFreeFlight) { 
  if (currentMissionNo >= missionGenFunctions.len())
    return false

  missionGenFunctions[currentMissionNo](isFreeFlight)
  currentMissionNo++
  return true
})
