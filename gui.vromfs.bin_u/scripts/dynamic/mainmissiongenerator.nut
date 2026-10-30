from "%scripts/dynamic/headtohead.nut" import genHeadToHeadMission
from "%scripts/dynamic/combat_patrol.nut" import genCombatPatrolMission
from "%scripts/dynamic/bombing.nut" import genBombingVehiclesMission, genBombingAntiTankMission, genBombingBuildingsMission, genBombingShipsMission, genBombingCarrierMission
from "%scripts/dynamic/freeflight.nut" import genFreeFlightMission
from "%scripts/dynamic/waypointflight.nut" import genWayPointFlightMission
from "%scripts/dynamic/bombing_intercept.nut" import genInterceptBombingMission
from "%scripts/dynamic/cover_bombers.nut" import genCoverMission
from "%scripts/dynamic/bombing_defense.nut" import genBombingDefenseMission
from "%scripts/dynamic/assault_defense.nut" import genAssaultDefenseMission
from "%scripts/dynamic/assault.nut" import genAssaultFirstMission, genAssaultSecondMission, genAssaultThirdMission
from "%scripts/dynamic/cover_assault.nut" import genCoverGattackMission
from "scriptRespondent" import registerRespondent

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
