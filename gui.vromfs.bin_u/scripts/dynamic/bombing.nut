from "math" import max, min, sqrt, clamp

let { Point3 } = require("dagor.math")
let { getEnemyPlaneByWpCost, planeCostCalculate, warpointCalculate, slidesReplace
} = require("%scripts/dynamic/misGenFuncTools.nut")
let { debug_dump_stack } = require("dagor.debug")
let { mgBeginMission, mgGetPlayerSide, mgAcceptMission, mgFullLogs, mgSetStr, mgSetInt,
  mgSetBool, mgGetEnemySide, mgCreateStartLookAt, mgCreateGroundUnits, mgGetUnitsCount,
  mgSetupArmada, mgSetupArea, rndRange, rndRangeInt, getAnyFighter, getDistancePerMinute,
  getAircraftCost, mgReplace, mgSetupAirfield, mgSetDistToAction, getAircraftDescription,
  gmMarkCutsceneArmadaLooksLike, mgSetEffShootingRate, mgGetMissionSector, mgGetLevelName,
  mgSetMinMaxAircrafts
} = require("dynamicMission")

function generateBombingMission(isFreeFlight, ground_type, createGroundUnitsProc) {
  let mission_preset_name = "bombing_preset01"
  mgBeginMission($"gameData/missions/dynamic_campaign/objectives/{mission_preset_name}.blk")
  let playerSide = mgGetPlayerSide()
  let enemySide = mgGetEnemySide()

  let wpMax = 1000000
  let allyFighterPlane = getAnyFighter(playerSide, 0, wpMax)
  local allyFighterPlaneCost = getAircraftCost(allyFighterPlane)
  if (allyFighterPlaneCost == 0)
    allyFighterPlaneCost = 250

  let enemyFighterPlane = getEnemyPlaneByWpCost(allyFighterPlaneCost, enemySide)
  local enemyPlaneCost = getAircraftCost(enemyFighterPlane)
  if (enemyPlaneCost == 0)
    enemyPlaneCost = 250

  let planeCost = planeCostCalculate(allyFighterPlaneCost, enemyPlaneCost)

  let bombTargetsCount = mgGetUnitsCount("#bomb_targets")
  let bombtargets = createGroundUnitsProc(enemySide)
  if (bombtargets == "" || bombTargetsCount <= 0)
    return

  local bombersCountMin = 0
  local bombersCountMax = 0
  local indicator_icon = ""

  local playerBomberPlane = ""
  if (ground_type == "tank" || ground_type == "building") {
    bombersCountMin = 1 * (bombTargetsCount) - 4
    bombersCountMax = 3 * (bombTargetsCount) - 4
    playerBomberPlane = getAircraftDescription(playerSide, "bomber", ["bomber"],
      ["antiTankBomb"], true, 0, wpMax)
    indicator_icon = ground_type
  }
  else if (ground_type == "artillery") {
    bombersCountMin = 1 * (bombTargetsCount) - 4
    bombersCountMax = 3 * (bombTargetsCount) - 4
    playerBomberPlane = getAircraftDescription(playerSide, "bomber", ["bomber"],
      ["bomb"], true, 0, wpMax)
    indicator_icon = "cannon"
  }
  else if (ground_type == "destroyer") {
    bombersCountMin = 4 * (bombTargetsCount) - 4
    bombersCountMax = 16 * (bombTargetsCount) - 4
    playerBomberPlane = getAircraftDescription(playerSide, "bomber", ["bomber"],
      ["antiShipBomb"], true, 0, wpMax)
    indicator_icon = "ship"
    mgSetBool("variables/is_target_ship", true)
  }
  else if (ground_type == "carrier") {
    bombersCountMin = 8 * bombTargetsCount - 4
    bombersCountMax = 32 * bombTargetsCount - 4
    playerBomberPlane = getAircraftDescription(playerSide, "bomber", ["bomber"],
      ["antiShipBomb"], true, 0, wpMax)
    indicator_icon = "ship"
    mgSetBool("variables/is_target_ship", true)
  }
  else
    return

  mgReplace("mission_settings/briefing/part", "icontype", "carrier", ground_type)
  mgReplace("triggers", "icon", "air", indicator_icon)
  mgSetInt("variables/count_to_kill", 1)

  if (indicator_icon != "ship") {
    mgReplace("mission_settings/briefing/part", "target", "target_waypoint_bombers", "#bomb_targets")
    mgReplace("mission_settings/briefing/part", "lookAt", "target_waypoint_bombers", "#bomb_targets")
    mgReplace("mission_settings/briefing/part", "point", "target_waypoint_bombers", "#bomb_targets")
  }

  if (playerBomberPlane == "" || enemyFighterPlane == "" || allyFighterPlane == "")
    return

  local bombersCount = min(rndRangeInt(bombersCountMin, bombersCountMax), 20)
  if (bombersCount < 4)
    bombersCount = 0

  let allyFighterCountMin = (bombersCount / 2 + 2) * planeCost
  let allyFighterCountMax = (bombersCount + 4) * planeCost
  let allyFightersCount = clamp(rndRangeInt(allyFighterCountMin, allyFighterCountMax), 4, 24)

  let enemyTotalCountMin = (bombersCount * 0.5 + allyFightersCount + 4) * 0.5 / planeCost
  let enemyTotalCountMax = (bombersCount + allyFightersCount + 4) / planeCost
  let enemyTotalCount = clamp(rndRangeInt(enemyTotalCountMin, enemyTotalCountMax), 8, 44)

  let enemyWaveCount = enemyTotalCount < 12 ? 1
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
  } while (enemyWaveCount_temp > 0)


  local enemyTotalCount_temp = enemyTotalCount
  enemyWaveCount_temp = enemyWaveCount
  let enemyPlanesInWave = enemyTotalCount_temp / enemyWaveCount_temp
  local enemy1Count = 0
  local enemy2Count = 0
  local enemy3Count = 0

  if (wave1 == 1) {
    enemy1Count = max(enemyPlanesInWave * rndRange(2 / 3.0, 3 / 2.0), 4)
    enemyTotalCount_temp = enemyTotalCount_temp - enemy1Count
    enemyWaveCount_temp = enemyWaveCount_temp - 1
  }
  if (wave2 == 1 && enemyWaveCount_temp > 0) {
    enemy2Count = max(enemyTotalCount_temp / (enemyWaveCount_temp) * rndRange(2 / 3.0, 3 / 2.0), 4)
    enemyTotalCount_temp = enemyTotalCount_temp - enemy2Count
  }
  if (wave3 == 1 && enemyWaveCount_temp > 0)
    enemy3Count = max(enemyTotalCount_temp, 4)


  let playerSpeed = 300 * 1000 / 60.0
  let enemy1Speed = getDistancePerMinute(enemyFighterPlane)
  let enemy2Speed = getDistancePerMinute(enemyFighterPlane)
  let enemy3Speed = getDistancePerMinute(enemyFighterPlane)

  let timeToTarget = rndRange(120 + wave1 * 45 + wave2 * 45, 120 + wave1 * 60 + wave2 * 60) / 60.0
  let timeToEvac = rndRange(90 + wave3 * 60, 90 + wave3 * 90) / 60.0
  let timeToEnemy1 = wave1 == 1 ? rndRange(30, timeToTarget * 60 / 4.0) / 60.0 : 0
  let timeToEnemy2 = rndRange(30 + timeToEnemy1 * 30, timeToTarget * 60 / 4.0 + timeToEnemy1 * 60) / 60.0
  let timeToEnemy3 = rndRange(30, 60) / 60.0
  let rndHeight = rndRange(2000, 4000)

  if (timeToTarget > timeToEvac)
    mgSetDistToAction(playerSpeed * timeToTarget + 2000)
  else
    mgSetDistToAction(playerSpeed * timeToEvac + 2000)

  mgSetupAirfield(bombtargets, playerSpeed * timeToTarget + 3000)
  let startLookAt = mgCreateStartLookAt()
  let enemy1Angle = rndRange(-90, 90)
  let enemy2Angle = rndRange(-90, 90)
  let evacAngle = rndRange(-10, 10)

  mgSetupArea("player_start", bombtargets, startLookAt, 180, playerSpeed * timeToTarget, rndHeight)
  mgSetupArea("target_waypoint_bombers", bombtargets, "", 0, 0, rndHeight)
  mgSetupArea("target_waypoint_fighters", bombtargets, "", 0, 0, rndHeight + 500)
  mgSetupArea("evac", bombtargets, "player_start", evacAngle, playerSpeed * timeToEvac + 3000, 1000)
  mgSetupArea("evac_forCut", "evac", bombtargets, 0, 2000, 1000)
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

  mgSetupArmada("#player.bomber", "player_start", Point3(0, 0, 0), bombtargets, "", 4, 4, playerBomberPlane)
  mgSetupArmada("#player_cut.any", "player_start", Point3(0, 0, 0), bombtargets, "", 4, 4, playerBomberPlane)
  gmMarkCutsceneArmadaLooksLike("#player_cut.any", "#player.bomber")
  mgSetupArmada("#ally01.bomber", "player_start", Point3(1000, -300, 0), bombtargets,
    "#ally_bombers_group", bombersCount, bombersCount, playerBomberPlane)
  mgSetupArmada("#ally02.fighter", "player_start", Point3(500, 500, 0), bombtargets,
    "#ally_fighters_group", allyFightersCount, allyFightersCount, allyFighterPlane)

  if (wave1 == 1)
    mgSetupArmada("#enemy01.fighter", "enemy1_start", Point3(0, 0, 0), "#player.bomber",
      "#enemy_fighters_group01", enemy1Count, enemy1Count, enemyFighterPlane)
  if (wave2 == 1) {
    mgSetupArmada("#enemy02.fighter", "enemy2_start", Point3(0, 0, 0), "#player.bomber",
      "#enemy_fighters_group02", enemy2Count, enemy2Count, enemyFighterPlane)
    mgSetInt("variables/enemy2_time", timeToEnemy1 * 60)
  }
  if (wave3 == 1)
    mgSetupArmada("#enemy03.fighter", "enemy3_start", Point3(0, 0, 0), "#player.bomber",
      "#enemy_fighters_group03", enemy3Count, enemy3Count, enemyFighterPlane)

  mgSetMinMaxAircrafts("player", "", 1, 8)
  mgSetMinMaxAircrafts("ally", "fighter", 0, 24)
  mgSetMinMaxAircrafts("ally", "bomber", 0, 20)
  mgSetMinMaxAircrafts("enemy", "fighter", 0, 44)


  let mission_mult = sqrt(enemyTotalCount / 20.0 + 0.05)
  let ally_all_count = allyFightersCount + (bombersCount - 4) * 0.5
  let missionWpCost = warpointCalculate(mission_preset_name, ally_all_count, enemyTotalCount, 1,
    playerBomberPlane, mission_mult)
  mgSetInt("mission_settings/mission/wpAward", missionWpCost)
  mgSetEffShootingRate(0.1)

  if (playerBomberPlane == "")
    return

  slidesReplace(mgGetLevelName(), mgGetMissionSector(), ground_type)
  mgSetBool("variables/training_mode", isFreeFlight)

 
  if (mgFullLogs())
    debug_dump_stack()

  mgAcceptMission()
}

function genBombingVehiclesMission(isFreeFlight) {
  generateBombingMission(isFreeFlight, "tank",
    function(enemySide) {
      mgSetStr("mission_settings/mission/name", "dynamic_bombing_vehicles")
      return mgCreateGroundUnits(enemySide, false, false,
        {
          heavy_vehicles = "#bomb_targets"
          light_vehicles = "#bomb_target_cover"
          infantry = "#bomb_target_cover"
          air_defence = "#bomb_target_cover"
          anti_tank = "#bomb_target_cover"
          bombtarget = "#bomb_target_cover"
          ships = "#bomb_target_cover"
          carriers = "#bomb_target_cover"
        })
    }
  )
}

function genBombingAntiTankMission(isFreeFlight) {
  generateBombingMission(isFreeFlight, "artillery",
    function(enemySide) {
      mgSetStr("mission_settings/mission/name", "dynamic_bombing_anti_tank")
      return mgCreateGroundUnits(enemySide, false, false,
        {
          heavy_vehicles = "#bomb_target_cover"
          light_vehicles = "#bomb_target_cover"
          infantry = "#bomb_target_cover"
          air_defence = "#bomb_target_cover"
          anti_tank = "#bomb_targets"
          bombtarget = "#bomb_target_cover"
          ships = "#bomb_target_cover"
          carriers = "#bomb_target_cover"
        })
    }
  )
}

function genBombingBuildingsMission(isFreeFlight) {
  generateBombingMission(isFreeFlight, "building",
    function(enemySide) {
      mgSetStr("mission_settings/mission/name", "dynamic_bombing_buildings")
      return mgCreateGroundUnits(enemySide, false, false,
        {
          heavy_vehicles = "#bomb_target_cover"
          light_vehicles = "#bomb_target_cover"
          infantry = "#bomb_target_cover"
          air_defence = "#bomb_target_cover"
          anti_tank = "#bomb_target_cover"
          bombtarget = "#bomb_targets"
          ships = "#bomb_target_cover"
          carriers = "#bomb_target_cover"
        })
    }
  )
}

function genBombingShipsMission(isFreeFlight) {
  generateBombingMission(isFreeFlight, "destroyer",
    function(enemySide) {
      mgSetStr("mission_settings/mission/name", "dynamic_bombing_ships")
      return mgCreateGroundUnits(enemySide, false, false,
        {
          heavy_vehicles = "#bomb_target_cover"
          light_vehicles = "#bomb_target_cover"
          infantry = "#bomb_target_cover"
          air_defence = "#bomb_target_cover"
          anti_tank = "#bomb_target_cover"
          bombtarget = "#bomb_target_cover"
          ships = "#bomb_targets"
          carriers = "#bomb_target_cover"
        })
    }
  )
}

function genBombingCarrierMission(isFreeFlight) {
  generateBombingMission(isFreeFlight, "carrier",
    function(enemySide) {
      mgSetStr("mission_settings/mission/name", "dynamic_bombing_carrier")
      return mgCreateGroundUnits(enemySide, false, true,
        {
          heavy_vehicles = "#bomb_target_cover"
          light_vehicles = "#bomb_target_cover"
          infantry = "#bomb_target_cover"
          air_defence = "#bomb_target_cover"
          anti_tank = "#bomb_target_cover"
          bombtarget = "#bomb_target_cover"
          ships = "#bomb_target_cover"
          carriers = "#bomb_targets"
        })
    }
  )
}

return {
  genBombingVehiclesMission
  genBombingAntiTankMission
  genBombingBuildingsMission
  genBombingShipsMission
  genBombingCarrierMission
}
