from "math" import max, min, sqrt, clamp

let { Point3 } = require("dagor.math")
let { getEnemyPlaneByWpCost, planeCostCalculate, warpointCalculate, slidesReplace
} = require("%scripts/dynamic/misGenFuncTools.nut")
let { debug_dump_stack } = require("dagor.debug")
let { mgBeginMission, mgGetPlayerSide, mgAcceptMission, mgFullLogs, mgSetInt, mgSetBool,
  mgGetEnemySide, mgCreateStartLookAt, mgCreateGroundUnits, mgGetUnitsCount, mgSetupArmada,
  mgSetupArea, rndRange, rndRangeInt, getDistancePerMinute, getAircraftCost,
  getAnyPlayerFighter, mgReplace, mgSetupAirfield, mgSetDistToAction, getAircraftDescription,
  gmMarkCutsceneArmadaLooksLike, mgSetEffShootingRate, mgGetMissionSector, mgGetLevelName,
  mgSetMinMaxAircrafts
} = require("dynamicMission")
let { get_warpoints_blk } = require("blkGetters")

let function generateCoverMission(isFreeFlight, createGroundUnitsProc) {
  let mission_preset_name = "cover_bombers_preset01"
  mgBeginMission($"gameData/missions/dynamic_campaign/objectives/{mission_preset_name}.blk")
  let playerSide = mgGetPlayerSide()
  let enemySide = mgGetEnemySide()
  let bombtargets = createGroundUnitsProc(enemySide)

//planes cost and warpoint ratio calculate
  let ws = get_warpoints_blk()
  let wpMax = ws.dynPlanesMaxCost
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
  local bombersCount = 0
  local allyBomberPlane = ""

  local ground_type = ""
  local squad_type = ""
  let tanks_count = mgGetUnitsCount("#bomb_targets_tanks")
  let light_count = mgGetUnitsCount("#bomb_targets_light")
  let art_count = mgGetUnitsCount("#bomb_targets_art")
  let ships_count = mgGetUnitsCount("#bomb_targets_ships")
  let carrier_count = mgGetUnitsCount("#bomb_targets_carrier")
  let bombTargets_count = mgGetUnitsCount("#bomb_target_buildings")

  if (bombTargets_count > 0) {
    bombersCount = rndRangeInt(bombTargets_count * 0.5, bombTargets_count * 2)
    ground_type = "building"
    squad_type = "#bomb_target_buildings"
    allyBomberPlane = getAircraftDescription(playerSide, "bomber", ["bomber"],
      ["bomb"], false, 0, wpMax)
  }
  else if (tanks_count > 0 && tanks_count > light_count && tanks_count > art_count) {
    bombersCount = rndRangeInt(tanks_count, tanks_count * 3)
    ground_type = "tank"
    squad_type = "#bomb_targets_tanks"
    allyBomberPlane = getAircraftDescription(playerSide, "bomber", ["bomber"],
      ["antiTankBomb"], false, 0, wpMax)
  }
  else if (light_count > 0 && light_count > art_count) {
    bombersCount = rndRangeInt(light_count * 0.5, light_count)
    ground_type = "truck"
    squad_type = "#bomb_targets_light"
    allyBomberPlane = getAircraftDescription(playerSide, "bomber", ["bomber"],
      ["bomb"], false, 0, wpMax)
  }
  else if (art_count > 0) {
    bombersCount = rndRangeInt(art_count * 0.5, art_count)
    ground_type = "artillery"
    squad_type = "#bomb_targets_art"
    allyBomberPlane = getAircraftDescription(playerSide, "bomber", ["bomber"],
      ["bomb"], false, 0, wpMax)
  }
  else if (carrier_count > 0) {
    bombersCount = rndRangeInt(ships_count * 8, ships_count * 32)
    ground_type = "carrier"
    squad_type = "#bomb_targets_carrier"
    allyBomberPlane = getAircraftDescription(playerSide, "bomber", ["bomber"],
      ["antiShipBomb"], false, 0, wpMax)
  }
  else if (ships_count > 0) {
    bombersCount = rndRangeInt(ships_count * 4, ships_count * 8)
    ground_type = "destroyer"
    squad_type = "#bomb_targets_ships"
    allyBomberPlane = getAircraftDescription(playerSide, "bomber", ["bomber"],
      ["antiShipBomb"], false, 0, wpMax)
  }
  else
    return

  if (playerFighterPlane == "" || enemyFighterPlane == "" || allyBomberPlane == "")
    return

  mgReplace("mission_settings/briefing/part", "icontype", "carrier", ground_type)
  mgReplace("mission_settings/briefing/part", "point", "#bomb_targets", squad_type)
  mgReplace("mission_settings/briefing/part", "target", "#bomb_targets", squad_type)
  mgReplace("triggers", "object", "#bomb_targets", squad_type)
  mgReplace("triggers", "target", "#bomb_targets", squad_type)

  if (ground_type != "destroyer" && ground_type != "carrier") {
    mgReplace("mission_settings/briefing/part", "target", "target_waypoint_bombers", squad_type)
    mgReplace("mission_settings/briefing/part", "lookAt", "target_waypoint_bombers", squad_type)
    mgReplace("mission_settings/briefing/part", "point", "target_waypoint_bombers", squad_type)
  }

  bombersCount = clamp(bombersCount, 8, 24)
//fighters count calculate
  let allyFighterCountMin = (bombersCount * 0.5) / 1.5 * planeCost - 4
  let allyFighterCountMax = (bombersCount) / 1.5 * planeCost - 4
  local allyFightersCount = min(rndRangeInt(allyFighterCountMin, allyFighterCountMax), 16)
  if (allyFightersCount < 4)
    allyFightersCount = 0

  let enemyTotalCountMin = (bombersCount * 0.5 + allyFightersCount + 4) * 0.5 / planeCost
  let enemyTotalCountMax = (bombersCount + allyFightersCount + 4) / planeCost
  let enemyTotalCount = clamp(rndRangeInt(enemyTotalCountMin, enemyTotalCountMax), 8, 44)
//wave count
  let enemyWaveCount = enemyTotalCount < 16 ? 1
    : enemyTotalCount < 24 ? rndRangeInt(1, 2)
    : rndRangeInt(2, 3)

  local enemyWaveCount_temp = enemyWaveCount
  local wave1 = 0
  local wave2 = 0
  local wave3 = 0
  local j = 0

  do {
    j = rndRangeInt(1, 3)
    if (j == 1 && wave1 == 0) {
      wave1 = 1
      --enemyWaveCount_temp
    }
    if (j == 2 && wave2 == 0) {
      wave2 = 1
      --enemyWaveCount_temp
    }
    if (j == 3 && wave3 == 0) {
      wave3 = 1
      --enemyWaveCount_temp
    }
  }
  while (enemyWaveCount_temp > 0)

//enemy planes in each wave
  local enemyTotalCount_temp = enemyTotalCount
  enemyWaveCount_temp = enemyWaveCount

  let enemyCount = enemyTotalCount

  let enemyPlanesInWave = enemyTotalCount_temp / enemyWaveCount_temp
  local enemy1Count = 0
  local enemy2Count = 0
  local enemy3Count = 0

  if (wave1 == 1) {
    enemy1Count = max(enemyPlanesInWave * rndRange(2 / 3.0, 3 / 2.0), 8)
    enemyTotalCount_temp = enemyTotalCount_temp - enemy1Count
    enemyWaveCount_temp = enemyWaveCount_temp - 1
  }
  if (wave2 == 1 && enemyWaveCount_temp > 0) {
    enemy2Count = max(enemyTotalCount_temp / (enemyWaveCount_temp) * rndRange(2 / 3.0, 3 / 2.0), 8)
    enemyTotalCount_temp = enemyTotalCount_temp - enemy2Count
  }
  if (wave3 == 1 && enemyWaveCount_temp > 0)
    enemy3Count = max(enemyTotalCount_temp, 8)

//battle distance calculate
  let rndHeight = rndRange(2000, 4000)
  let playerSpeed = 300 * 1000 / 60
  let enemy1Speed = getDistancePerMinute(enemyFighterPlane)
  let enemy2Speed = getDistancePerMinute(enemyFighterPlane)
  let enemy3Speed = getDistancePerMinute(enemyFighterPlane)

  let timeToTarget = rndRange(120 + wave1 * 45 + wave2 * 45, 120 + wave1 * 60 + wave2 * 60) / 60.0
  local timeToEnemy1 = 0
  if (wave1 == 1)
    timeToEnemy1 = rndRange(30, timeToTarget * 60 / 4.0) / 60.0
  let timeToEnemy2 = rndRange(30 + timeToEnemy1 * 30, timeToTarget * 60 / 4.0 + timeToEnemy1 * 60) / 60.0
  let timeToEnemy3 = rndRange(30, 60) / 60.0

  mgSetDistToAction(playerSpeed * timeToTarget)
  mgSetupAirfield(bombtargets, playerSpeed * timeToTarget)
  let startLookAt = mgCreateStartLookAt()
  let enemy1Angle = rndRange(-90, 90)
  let enemy2Angle = rndRange(-90, 90)
  let evacAngle = rndRange(-10, 10)
//points setup
  mgSetupArea("player_start", bombtargets, startLookAt, 180, playerSpeed * timeToTarget, rndHeight)
  mgSetupArea("target_waypoint_bombers", bombtargets, "", 0, 0, rndHeight - 200)
  mgSetupArea("target_waypoint_fighters", bombtargets, "", 0, 0, rndHeight)
  mgSetupArea("evac", bombtargets, "player_start", evacAngle, 30000, rndHeight)
  mgSetupArea("evac_forCut", "evac", bombtargets, 0, 2000, 0)
  mgSetupArea("ally_evac", bombtargets, "player_start", evacAngle, 90000, 1000)
  mgSetupArea("enemy_evac", bombtargets, "player_start", evacAngle - 180, 90000, 1000)

  mgSetupArea("enemy1_pointToFight", "player_start", bombtargets, 0,
    playerSpeed * timeToEnemy1, rndHeight + rndRange(0, 2000))
  mgSetupArea("enemy1_start", "enemy1_pointToFight", bombtargets, enemy1Angle,
    enemy1Speed * timeToEnemy1, 0)

  mgSetupArea("enemy2_pointToFight", "enemy1_pointToFight", bombtargets, 0,
    playerSpeed * timeToEnemy2, rndHeight + rndRange(0, 2000))
  mgSetupArea("enemy2_start", "enemy2_pointToFight", bombtargets, enemy2Angle,
    enemy2Speed * timeToEnemy2, 0)

  mgSetupArea("enemy3_start", bombtargets, "player_start", 180,
    enemy3Speed * timeToEnemy3, rndHeight + rndRange(0, 2000))

//armada setup
  mgSetupArmada("#player.fighter", "player_start", Point3(0, 0, 0), bombtargets, "", 4, 4, playerFighterPlane)
  mgSetupArmada("#player_cut.any", "player_start", Point3(0, 0, 0), bombtargets, "", 4, 4, playerFighterPlane)
  gmMarkCutsceneArmadaLooksLike("#player_cut.any", "#player.fighter")

  mgSetupArmada("#ally01.bomber", "#player.fighter", Point3(200, -200, 0), bombtargets,
    "#ally_bombers_group", bombersCount, bombersCount, allyBomberPlane)

  if (allyFighterCountMin != 0)
    mgSetupArmada("#ally02.fighter", "#player.fighter", Point3(-500, 0, 0), bombtargets,
      "#ally_fighters_group", allyFighterCountMin, allyFighterCountMax, playerFighterPlane)


  if (wave1 == 1) {
    mgSetupArmada("#enemy01.fighter", "enemy1_start", Point3(0, 0, 0), "#ally01.bomber",
      "#enemy_attack_bombers01", enemy1Count / 2, enemy1Count / 2, enemyFighterPlane)
    mgSetupArmada("#enemy02.fighter", "enemy1_start", Point3(-200, -200, 200), "#player.fighter",
      "#enemy_attack_fighters01", enemy1Count / 2, enemy1Count / 2, enemyFighterPlane)
    mgSetBool("variables/e1_enable", true)
  }
  if (wave2 == 1) {
    mgSetupArmada("#enemy03.fighter", "enemy2_start", Point3(0, 0, 0), "#ally01.bomber",
      "#enemy_attack_bombers02", enemy2Count / 2, enemy2Count / 2, enemyFighterPlane)
    mgSetupArmada("#enemy04.fighter", "enemy2_start", Point3(-200, -200, 200), "#player.fighter",
      "#enemy_attack_fighters02", enemy2Count / 2, enemy2Count / 2, enemyFighterPlane)
    mgSetBool("variables/e2_enable", true)
    mgSetInt("variables/enemy2_time", timeToEnemy1 * 60)
  }
  if (wave3 == 1) {
    mgSetupArmada("#enemy05.fighter", "enemy3_start", Point3(0, 0, 0), "#ally01.bomber",
      "#enemy_attack_bombers03", enemy3Count / 2, enemy3Count / 2, enemyFighterPlane)
    mgSetupArmada("#enemy06.fighter", "enemy3_start", Point3(-200, -200, 200), "#player.fighter",
      "#enemy_attack_fighters03", enemy3Count / 2, enemy3Count / 2, enemyFighterPlane)

    mgSetBool("variables/e3_enable", true)
  }

  mgSetMinMaxAircrafts("player", "", 1, 8)
  mgSetMinMaxAircrafts("ally", "fighter", 0, 16)
  mgSetMinMaxAircrafts("ally", "bomber", 8, 24)
  mgSetMinMaxAircrafts("enemy", "fighter", 0, 44)

//mission warpoint cost calculate
  let mission_mult = sqrt(enemyTotalCount / 20.0 + 0.05)
  let missionWpCost = warpointCalculate(mission_preset_name, allyFightersCount + bombersCount * 0.5, enemyCount, planeCost,
    playerFighterPlane, mission_mult)
  mgSetInt("mission_settings/mission/wpAward", missionWpCost)

  mgSetEffShootingRate(0.1)
  if (playerFighterPlane == "" || allyBomberPlane == "")
    return

  slidesReplace(mgGetLevelName(), mgGetMissionSector(), "air")

  mgSetBool("variables/training_mode", isFreeFlight)

//  mgDebugDump("E:/dagor2/skyquake/develop/gameBase/gameData/missions/dynamic_campaign/objectives/testBombing_cover_temp.blk")
  if (mgFullLogs())
    debug_dump_stack()

  mgAcceptMission()
}

let function genCoverMission(isFreeFlight) {
  generateCoverMission(isFreeFlight,
    function(enemySide) {
      return mgCreateGroundUnits(enemySide, false, false,
        {
          heavy_vehicles = "#bomb_targets_tanks"
          light_vehicles = "#bomb_targets_light"
          infantry = "#bomb_target_cover"
          air_defence = "#bomb_target_cover"
          anti_tank = "#bomb_targets_art"
          bombtarget = "#bomb_target_buildings"
          ships = "#bomb_targets_ships"
          carriers = "#bomb_targets_carrier"
        })
    }
  )
}

return {
  genCoverMission
}
