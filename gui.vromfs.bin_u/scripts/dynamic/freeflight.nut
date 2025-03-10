
let { Point3 } = require("dagor.math")
let { slidesReplace } = require("%scripts/dynamic/misGenFuncTools.nut")
let { debug_dump_stack } = require("dagor.debug")
let { mgBeginMission, mgGetPlayerSide, mgAcceptMission, mgFullLogs, mgSetInt,
  mgCreateStartPoint, mgCreateStartLookAt, mgSetupArmada, mgSetupAirfield,
  mgSetDistToAction, getAircraftDescription, mgGetMissionSector, mgGetLevelName,
  mgThisIsFreeFlight, mgSetMinMaxAircrafts
} = require("dynamicMission")

function genFreeFlightMission(isFreeFlight) { 
  if (!isFreeFlight)
    return

  let playerSide = mgGetPlayerSide()
  mgBeginMission("gameData/missions/dynamic_campaign/objectives/free_flight_preset02.blk")
  mgThisIsFreeFlight()
  let startPos = mgCreateStartPoint(1500)

  mgSetDistToAction(1000)
  mgSetupAirfield(startPos, 0)

  let startLookAt = mgCreateStartLookAt()
  let playerAnyPlane = getAircraftDescription(playerSide, "any", [],
    ["frontGun", "cannon", "bomb", "rocket", "torpedo", "antiShip", "antiHeavyTanks"], true, 0, 99999999)
  mgSetupArmada("#player.any", startPos, Point3(0, 0, 0), startLookAt, "", 4, 4, playerAnyPlane)

  mgSetInt("mission_settings/mission/wpAward", 0)

  mgSetMinMaxAircrafts("player", "", 1, 8)

  
  if (playerAnyPlane == "")
    return

  slidesReplace(mgGetLevelName(), mgGetMissionSector(), "none")

  if (mgFullLogs())
    debug_dump_stack()

  mgAcceptMission()
}

return {
  genFreeFlightMission
}
