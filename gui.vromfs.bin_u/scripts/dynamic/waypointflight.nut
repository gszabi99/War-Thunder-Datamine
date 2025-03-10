from "math" import clamp

let { Point3 } = require("dagor.math")
let { slidesReplace } = require("%scripts/dynamic/misGenFuncTools.nut")
let { debug_dump_stack } = require("dagor.debug")
let { mgBeginMission, mgAcceptMission, mgFullLogs, mgSetInt, mgCreateStartPoint,
  mgCreateStartLookAt, mgSetupArmada, mgSetupArea, rndRange, rndRangeInt,
  getDistancePerMinute, getAnyPlayerFighter, mgSetupAirfield, mgRemoveStrParam,
  mgSetDistToAction, gmMarkCutsceneArmadaLooksLike, mgGetMissionSector, mgGetLevelName,
  mgEnsurePointsInMap, mgSetMinMaxAircrafts
} = require("dynamicMission")
let { get_warpoints_blk } = require("blkGetters")

local waypointFlightWpHeightNext = 0
local waypointFlightWpHeight = 0

function wpHeightCalc() {
  waypointFlightWpHeightNext = rndRange(clamp(1000 - waypointFlightWpHeight, -1000, 0), 1000)
  waypointFlightWpHeight = waypointFlightWpHeight + waypointFlightWpHeightNext
}

function genWayPointFlightMission(isFreeFlight) {
  if (!isFreeFlight)
    return

  mgBeginMission("gameData/missions/dynamic_campaign/objectives/free_flight_preset01.blk")
  let startHeight = rndRange(1500, 3000)
  let startPos = mgCreateStartPoint(startHeight)

  mgSetDistToAction(10000)
  mgSetupAirfield(startPos, 1000)

  let ws = get_warpoints_blk()
  local wpMax = ws.dynPlanesMaxCost
  let startLookAt = mgCreateStartLookAt()
  let playerFighterPlane = getAnyPlayerFighter(0, wpMax)
  if (playerFighterPlane == "")
    return

  let playerSpeed = getDistancePerMinute(playerFighterPlane)

  waypointFlightWpHeightNext = 0
  waypointFlightWpHeight = startHeight

  local maxWpOnSpeed = 9
  local maxTimeOnSpeed = 40
  if (playerSpeed > 10000) {
    maxWpOnSpeed = 5
    maxTimeOnSpeed = 30
  }
  else if (playerSpeed > 7000) {
    maxWpOnSpeed = 7
    maxTimeOnSpeed = 35
  }

  let wpDist = playerSpeed * 1.0 / 60

  wpMax = rndRangeInt(4, maxWpOnSpeed)

  mgSetInt("variables/wp_max", wpMax)

  local lastWp = ""
  local secondToLastWp = ""
  mgSetupArea("waypoint01", startPos, startLookAt, 180 + rndRange(-60, 60), wpDist * maxTimeOnSpeed, 0)
  wpHeightCalc()
  mgSetupArea("waypoint02", "waypoint01", startPos, rndRange(-60, 60), -wpDist * rndRange(10, maxTimeOnSpeed),
    waypointFlightWpHeightNext)
  wpHeightCalc()

  let offsetPoints = [startPos, "waypoint01", "waypoint02"]

  for (local j = 2; j < 10; j++) {
    if (wpMax > j) {
      mgSetupArea($"waypoint0{j+1}", $"waypoint0{j}", $"waypoint0{j-1}", rndRange(-60, 60),
        -wpDist * rndRange(10, maxTimeOnSpeed), waypointFlightWpHeightNext)
      wpHeightCalc()
      offsetPoints.append($"waypoint0{j+1}")
      lastWp = $"waypoint0{j+1}"
      secondToLastWp = $"waypoint0{j}"
    }
    else
      mgRemoveStrParam("mission_settings/briefing/part", $"waypoint0{j+1}")
  }

  mgSetupArea("evac", lastWp, secondToLastWp, rndRange(-60, 60),
    -wpDist * maxTimeOnSpeed, waypointFlightWpHeightNext)

  offsetPoints.append("evac")
  mgEnsurePointsInMap(offsetPoints)

  mgSetupArea("evac_forCut", "evac", lastWp, 0, 2000, 0)

  mgSetupArmada("#player.any", startPos, Point3(0, 0, 0), "waypoint01", "", 4, 4, playerFighterPlane)
  mgSetupArmada("#player_cut.any", startPos, Point3(0, 0, 0), "waypoint01", "", 4, 4, playerFighterPlane)
  gmMarkCutsceneArmadaLooksLike("#player_cut.any", "#player.any")

  mgSetInt("mission_settings/mission/wpAward", 0)

  if (playerFighterPlane == "")
    return

  mgSetMinMaxAircrafts("player", "", 1, 8)

  slidesReplace(mgGetLevelName(), mgGetMissionSector(), "none")


  if (mgFullLogs())
    debug_dump_stack()

  mgAcceptMission()
}

return {
  genWayPointFlightMission
}
