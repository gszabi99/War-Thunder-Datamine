from "math" import max, min, clamp

let { Point3 } = require("dagor.math")
let { getEnemyPlaneByWpCost, planeCostCalculate, warpointCalculate, slidesReplace
} = require("%scripts/dynamic/misGenFuncTools.nut")
let { debug_dump_stack } = require("dagor.debug")
let { mgBeginMission, mgGetPlayerSide, mgAcceptMission, mgFullLogs, mgSetInt,
  mgSetBool, mgGetEnemySide, mgCreateStartLookAt, mgCreateGroundUnits,
  mgGetUnitsCount, mgSetupArmada, mgSetupArea, rndRange, rndRangeInt, getDistancePerMinute,
  getAircraftCost, getAnyPlayerFighter, mgReplace, mgSetupAirfield, mgSetDistToAction,
  getAircraftDescription, gmMarkCutsceneArmadaLooksLike, mgSetEffShootingRate,
  mgGetMissionSector, mgGetLevelName, mgSetMinMaxAircrafts
} = require("dynamicMission")
let { get_warpoints_blk } = require("blkGetters")

let function generateInterceptBombingMission(isFreeFlight, createGroundUnitsProc) {
  let mission_preset_name = "intercept_bombers_preset01"
  mgBeginMission($"gameData/missions/dynamic_campaign/objectives/{mission_preset_name}.blk")
  let playerSide = mgGetPlayerSide()
  let enemySide = mgGetEnemySide()
  let bombtargets = createGroundUnitsProc(playerSide)

  local enemyBomberPlane = ""
  let ws = get_warpoints_blk()
  let wpMax = ws.dynPlanesMaxCost

//planes cost and warpoint ratio calculate
  let playerFighterPlane = getAnyPlayerFighter(0, wpMax)
  local playerPlaneCost = getAircraftCost(playerFighterPlane)
  if (playerPlaneCost == 0)
    playerPlaneCost = 250

  let enemyFighterPlane = getEnemyPlaneByWpCost(playerPlaneCost, enemySide)
  local enemyPlaneCost = getAircraftCost(enemyFighterPlane)
  if (enemyPlaneCost == 0)
    enemyPlaneCost = 250

  let planeCost = planeCostCalculate(playerPlaneCost, enemyPlaneCost)

//bombers count
  local ground_type = ""
  local squad_type = ""
  let tanks_count = mgGetUnitsCount("#bomb_targets_tanks")
  let light_count = mgGetUnitsCount("#bomb_targets_light")
  let art_count = mgGetUnitsCount("#bomb_targets_art")
  let ships_count = mgGetUnitsCount("#bomb_targets_ships")
  let carrier_count = mgGetUnitsCount("#bomb_targets_carrier")

  if (tanks_count > 0 && tanks_count > light_count && tanks_count > art_count) {
    ground_type = "tank"
    squad_type = "#bomb_targets_tanks"
    enemyBomberPlane = getAircraftDescription(enemySide, "bomber", ["bomber"],
      ["antiTankBomb"], false, 0, wpMax)
  }
  else if (light_count > 0 && light_count > art_count) {
    ground_type = "truck"
    squad_type = "#bomb_targets_light"
    enemyBomberPlane = getAircraftDescription(enemySide, "bomber", ["bomber"],
      ["bomb"], false, 0, wpMax)
  }
  else if (art_count > 0) {
    ground_type = "artillery"
    squad_type = "#bomb_targets_art"
    enemyBomberPlane = getAircraftDescription(enemySide, "bomber", ["bomber"],
      ["bomb"], false, 0, wpMax)
  }
  else if (carrier_count > 0) {
    ground_type = "carrier"
    squad_type = "#bomb_targets_carrier"
    enemyBomberPlane = getAircraftDescription(enemySide, "bomber", ["bomber"],
      ["antiShipBomb"], false, 0, wpMax)
  }
  else if (ships_count > 0) {
    ground_type = "destroyer"
    squad_type = "#bomb_targets_ships"
    enemyBomberPlane = getAircraftDescription(enemySide, "bomber", ["bomber"],
      ["antiShipBomb"], false, 0, wpMax)
  }
  else
    return

  if (playerFighterPlane == "" || enemyFighterPlane == "" || enemyBomberPlane == "")
    return

  mgReplace("mission_settings/briefing/part", "icontype", "carrier", ground_type)
  mgReplace("mission_settings/briefing/part", "point", "#bomb_targets", squad_type)
  mgReplace("mission_settings/briefing/part", "target", "#bomb_targets", squad_type)
  mgReplace("triggers", "object", "#bomb_targets", squad_type)
  mgReplace("triggers", "target", "#bomb_targets", squad_type)

  let bombersCount = min(rndRangeInt(16, 56), 48)
//enemy waves and fighter count calculate
  let enemyFightersCountMin = bombersCount * 0.25 / planeCost
  let enemyFightersCountMax = bombersCount * 0.5 / planeCost
  let enemyFightersCount = clamp(rndRangeInt(enemyFightersCountMin, enemyFightersCountMax), 4, 20)
  let allyFighterCountMin = bombersCount * 0.25 * planeCost - 4
  let allyFighterCountMax = bombersCount * 0.5 * planeCost - 4
  local allyCount = min(rndRangeInt(allyFighterCountMin, allyFighterCountMax), 16)
  if (allyCount < 4)
    allyCount = 0

//battle distance calculate
  let timeToTarget = max(bombersCount / 6.0, 4)
  let playerSpeed = getDistancePerMinute(playerFighterPlane)
  let enemyBomberSpeed = 250 * 1000 / 60.0
  let timeToEnemy = rndRange(30, 60) / 60.0
  let enemyDist = timeToTarget * enemyBomberSpeed + 5000

  mgSetDistToAction(-(enemyDist + bombersCount * 500 / 6.0))
  mgSetupAirfield(bombtargets, 6000)
  let startLookAt = mgCreateStartLookAt()
  let playerStartAngle = rndRange(-30, 30)
  let rndHeight = rndRange(1500, 3000)

  mgSetupArea("enemy_start", bombtargets, startLookAt, 0, enemyDist, rndHeight)
  mgSetupArea("player_start", "enemy_start", bombtargets, playerStartAngle,
    timeToEnemy * playerSpeed + 2000, rndRange(500, 1500))
  mgSetupArea("ally_start", "player_start", "enemy_start", 0, -500, 0)
  mgSetupArea("target_waypoint_bombers", bombtargets, "", 0, 0, rndHeight)
  mgSetupArea("target_waypoint_fighters", bombtargets, "", 0, 0, rndHeight + 500)
  mgSetupArea("evac", bombtargets, startLookAt, 0, 90000, rndHeight)
  mgSetupArea("evac_forCut", bombtargets, startLookAt, 0, 2000, rndHeight)

//armada setup
  mgSetupArmada("#player.fighter", "player_start", Point3(0, 0, 0), "enemy_start", "", 4, 4, playerFighterPlane)
  mgSetupArmada("#player_cut.any", "player_start", Point3(0, 0, 0), "enemy_start", "", 4, 4, playerFighterPlane)
  gmMarkCutsceneArmadaLooksLike("#player_cut.any", "#player.fighter")

  mgSetupArmada("#enemy02.bomber", "enemy_start", Point3(0, 0, 0), bombtargets,
    "#enemy_bomber_group", bombersCount, bombersCount, enemyBomberPlane)
  mgSetupArmada("#enemy_cut.any", "enemy_start", Point3(0, -100, 0), bombtargets,
    "", 10, 10, enemyBomberPlane)
  gmMarkCutsceneArmadaLooksLike("#enemy_cut.any", "#enemy02.bomber")

  mgSetupArmada("#enemy01.fighter", "enemy_start", Point3(-200, 500, 0), bombtargets,
    "#enemy_fighter_group", enemyFightersCount, enemyFightersCount, enemyFighterPlane)

  if (allyCount != 0)
    mgSetupArmada("#ally01.fighter", "ally_start", Point3(200, 0, 0), bombtargets,
      "#ally_fighters_group", allyCount, allyCount, playerFighterPlane)

  mgSetMinMaxAircrafts("player", "", 1, 8)
  mgSetMinMaxAircrafts("ally", "fighter", 0, 20)
  mgSetMinMaxAircrafts("enemy", "fighter", 0, 24)
  mgSetMinMaxAircrafts("enemy", "bomber", 8, 48)

//mission warpoint cost calculate
  let mission_mult = (bombersCount - 12) / 15.0 + 0.05
  let missionWpCost = warpointCalculate(mission_preset_name, 1, 5, 1,
    playerFighterPlane, mission_mult)
  mgSetInt("mission_settings/mission/wpAward", missionWpCost)

  mgSetEffShootingRate(0.2)

  if (playerFighterPlane == "" || enemyBomberPlane == "")
    return

  slidesReplace(mgGetLevelName(), mgGetMissionSector(), "air")

  mgSetBool("variables/training_mode", isFreeFlight)

 //  mgDebugDump("E:/dagor2/skyquake/develop/gameBase/gameData/missions/dynamic_campaign/objectives/testBombingDefense_temp.blk")
  if (mgFullLogs())
    debug_dump_stack()

  mgAcceptMission()
}

let function genInterceptBombingMission(isFreeFlight) {
  generateInterceptBombingMission(isFreeFlight,
    function(playerSide) {
      return mgCreateGroundUnits(playerSide, false, false,
        {
          heavy_vehicles = "#bomb_targets_tanks"
          light_vehicles = "#bomb_targets_light"
          infantry = "#bomb_target_cover"
          air_defence = "#bomb_target_cover"
          anti_tank = "#bomb_targets_art"
          bombtarget = "*"
          ships = "#bomb_targets_ships"
          carriers = "#bomb_targets_carrier"
        })
    }
  )
}

return {
  genInterceptBombingMission
}
