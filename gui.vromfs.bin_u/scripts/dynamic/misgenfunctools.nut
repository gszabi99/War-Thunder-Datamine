//checked for plus_string

let { sqrt } = require("%sqstd/math.nut")
let { debug_dump_stack } = require("dagor.debug")
let { mgGetPlayerSide, mgFullLogs, rndRangeInt, getAnyFighter, getAircraftCost, mgReplace,
  getPlaneWpDiv, getPlaneWpAdd, getMissionCost, getZeroWpAddCoef, getRepairCostMult
} = require("dynamicMission")

let function getEnemyPlaneByWpCost(playerPlaneCost, enemySide) {
  let planeWpDiv = getPlaneWpDiv()
  let planeWpAdd = getPlaneWpAdd()

  local enemyFighterPlaneWpCostMin = playerPlaneCost * (planeWpDiv - 1) * 1.0 / planeWpDiv - planeWpAdd
  local enemyFighterPlaneWpCostMax = playerPlaneCost * (1 + 1.0 / planeWpDiv) + planeWpAdd

  local enemyFighterPlane = getAnyFighter(enemySide, enemyFighterPlaneWpCostMin, enemyFighterPlaneWpCostMax)
  local enemyPlaneCost = getAircraftCost(enemyFighterPlane)

  local i = 0

  while (enemyPlaneCost >= enemyFighterPlaneWpCostMax && enemyPlaneCost <= enemyFighterPlaneWpCostMin && i < 3) {
    if (enemyFighterPlaneWpCostMin > 0) {
      enemyFighterPlaneWpCostMin = 2 * enemyFighterPlaneWpCostMin - playerPlaneCost
    }
    else
      enemyFighterPlaneWpCostMax = 2 * enemyFighterPlaneWpCostMax - playerPlaneCost

    enemyFighterPlane = getAnyFighter(enemySide, enemyFighterPlaneWpCostMin, enemyFighterPlaneWpCostMax)
    enemyPlaneCost = getAircraftCost(enemyFighterPlane)

    i++
  }

  return enemyFighterPlane
}

let function planeCostCalculate(playerPlaneCost, enemyPlaneCost) {
  let planeWpDiv = getPlaneWpDiv()
  let planeWpAdd = getPlaneWpAdd()
  let planeCost = clamp((enemyPlaneCost + planeWpAdd * planeWpDiv) * (enemyPlaneCost + planeWpAdd * planeWpDiv) * 1.0 /
    ((playerPlaneCost + planeWpAdd * planeWpDiv) * (playerPlaneCost + planeWpAdd * planeWpDiv)), 0.25, 4)
  return planeCost
}

let function warpointCalculate(mission_preset_name, allyCount, enemyCount, planeCost, playerPlane, mission_mult) {
  if (enemyCount == 0 || planeCost == 0)
    return 0

  let missionWpBasicCost = getMissionCost(mission_preset_name)
  let enemyAllyCoef = clamp((enemyCount * 1.0 / (allyCount + 4)) * planeCost, 0.5, 1.5)
  let missionWpFighterCoef = clamp(sqrt(enemyAllyCoef * mission_mult), 0.5, 1.5)
  let zeroWpAddCoef = getZeroWpAddCoef()
  let repairCostMult = getRepairCostMult()
  let playerPlaneCost = getAircraftCost(playerPlane)
  local missionWpCost = max((zeroWpAddCoef * missionWpFighterCoef + playerPlaneCost * repairCostMult) * missionWpBasicCost, 0)
  if (missionWpCost > 99)
    missionWpCost = (missionWpCost / 10).tointeger() * 10

  if (mgFullLogs())
    debug_dump_stack()

  return missionWpCost
}

let function slidesReplace(level, sector, target_type) {
  mgReplace("mission_settings/briefing", "picture", "dynamic_missions/berlin_02_01",
    $"dynamic_missions/{level}_{sector}_0{rndRangeInt(1,3)}")

  if (target_type == "air")
    return

  let target_side = mgGetPlayerSide() == 1 ? "axis" : "allies"
  mgReplace("mission_settings/briefing", "picture", "dynamic_missions/mission_targets/ruhr_allies_tank",
    $"dynamic_missions/mission_targets/{level}_{target_side}_{target_type}")
}

return {
  getEnemyPlaneByWpCost
  planeCostCalculate
  warpointCalculate
  slidesReplace
}
