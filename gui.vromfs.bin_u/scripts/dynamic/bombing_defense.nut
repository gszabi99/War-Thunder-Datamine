from "math" import max, min, sqrt, clamp

let { Point3 } = require("dagor.math")
let { getEnemyPlaneByWpCost, planeCostCalculate, warpointCalculate, slidesReplace
} = require("%scripts/dynamic/misGenFuncTools.nut")
let { debug_dump_stack } = require("dagor.debug")
let { mgBeginMission, mgGetPlayerSide, mgAcceptMission, mgFullLogs, mgSetStr, mgSetInt,
  mgSetReal, mgSetBool, mgGetEnemySide, mgCreateStartLookAt, mgCreateGroundUnits,
  mgGetUnitsCount, mgSetupArmada, mgSetupArea, rndRange, rndRangeInt, getDistancePerMinute,
  getAircraftCost, getAnyPlayerFighter, mgReplace, mgSetupAirfield, mgSetDistToAction,
  getAircraftDescription, gmMarkCutsceneArmadaLooksLike, mgSetEffShootingRate,
  mgGetMissionSector, mgGetLevelName, mgSetMinMaxAircrafts
} = require("dynamicMission")
let { get_warpoints_blk } = require("blkGetters")

let function generateBombingDefMission(isFreeFlight, createGroundUnitsProc) {
  let mission_preset_name = "ground_defense_preset01"
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
  if (playerPlaneCost == 0) {
    playerPlaneCost = 250
  }

  let enemyFighterPlane = getEnemyPlaneByWpCost(playerPlaneCost, enemySide)
  local enemyPlaneCost = getAircraftCost(enemyFighterPlane)
  if (enemyPlaneCost == 0) {
    enemyPlaneCost = 250
  }

  let planeCost = planeCostCalculate(playerPlaneCost, enemyPlaneCost)

//bombers count
  local bombersCount = 0

  local ground_type = ""
  local squad_type = ""
  local mission_name = ""
  let tanks_count = mgGetUnitsCount("#bomb_targets_tanks")
  let light_count = mgGetUnitsCount("#bomb_targets_light")
  let art_count = mgGetUnitsCount("#bomb_targets_art")
  let ships_count = mgGetUnitsCount("#bomb_targets_ships")
  let carrier_count = mgGetUnitsCount("#bomb_targets_carrier")
  local indicator_icon = ""
  local countToFail = 1

  if (tanks_count > 0 && tanks_count > light_count && tanks_count > art_count) {
    countToFail = tanks_count / 2
    bombersCount = rndRangeInt(tanks_count * 3, tanks_count * 6)
    ground_type = "tank"
    squad_type = "#bomb_targets_tanks"
    enemyBomberPlane = getAircraftDescription(enemySide, "bomber", ["bomber"],
      ["antiTankBomb"], false, 0, wpMax)
    mission_name = "dynamic_defense_tank"
    indicator_icon = "tank"
  }
  else if (light_count > 0 && light_count > art_count) {
    countToFail = light_count / 2
    bombersCount = rndRangeInt(light_count * 2, light_count * 4)
    ground_type = "truck"
    squad_type = "#bomb_targets_light"
    enemyBomberPlane = getAircraftDescription(enemySide, "bomber", ["bomber"],
      ["bomb"], false, 0, wpMax)
    mission_name = "dynamic_defense_vehicles"
    indicator_icon = "truck"
  }
  else if (art_count > 0) {
    countToFail = art_count / 2
    bombersCount = rndRangeInt(art_count * 2, art_count * 4)
    ground_type = "artillery"
    squad_type = "#bomb_targets_art"
    enemyBomberPlane = getAircraftDescription(enemySide, "bomber", ["bomber"],
      ["bomb"], false, 0, wpMax)
    mission_name = "dynamic_defense_anti_tank"
    indicator_icon = "cannon"
  }
  else if (carrier_count > 0) {
    countToFail = carrier_count
    bombersCount = rndRangeInt(carrier_count * 8, carrier_count * 32)
    ground_type = "carrier"
    squad_type = "#bomb_targets_carrier"
    enemyBomberPlane = getAircraftDescription(enemySide, "bomber", ["bomber"],
      ["antiShipBomb"], false, 0, wpMax)
    mission_name = "dynamic_defense_carrier"
    indicator_icon = "ship"
  }
  else if (ships_count > 0) {
    countToFail = ships_count * 2 / 3
    bombersCount = rndRangeInt(ships_count * 4, ships_count * 8)
    ground_type = "destroyer"
    squad_type = "#bomb_targets_ships"
    enemyBomberPlane = getAircraftDescription(enemySide, "bomber", ["bomber"],
      ["antiShipBomb"], false, 0, wpMax)
    mission_name = "dynamic_defense_ships"
    indicator_icon = "ship"
  }
  else
    return

  if (playerFighterPlane == "" || enemyFighterPlane == "" || enemyBomberPlane == "")
    return

  countToFail = max(countToFail, 1)
  mgReplace("mission_settings/briefing/part", "icontype", "carrier", ground_type)
  mgReplace("mission_settings/briefing/part", "point", "#bomb_targets", squad_type)
  mgReplace("mission_settings/briefing/part", "target", "#bomb_targets", squad_type)
  mgReplace("triggers", "object", "#bomb_targets", squad_type)
  mgReplace("triggers", "target", "#bomb_targets", squad_type)
  mgReplace("triggers", "icon", "air", indicator_icon)
  mgSetStr("mission_settings/mission/name", mission_name)
  mgSetInt("variables/count_to_fail", countToFail)

  if (indicator_icon != "ship") {
    mgReplace("mission_settings/briefing/part", "target", "target_waypoint_bombers", squad_type)
    mgReplace("mission_settings/briefing/part", "lookAt", "target_waypoint_bombers", squad_type)
  }

  bombersCount = clamp(bombersCount, 8, 32)
//enemy waves and fighter count calculate
  let waveCount = bombersCount < 16 ? 1
    : bombersCount < 24 ? rndRangeInt(1, 2)
    : rndRangeInt(2, 3)
  mgSetInt("variables/wave_max", waveCount)

  let enemyFightersCountMin = bombersCount * 0.5 / 1.3 / planeCost
  let enemyFightersCountMax = bombersCount / 1.3 / planeCost
  let enemyFightersCount = clamp(rndRangeInt(enemyFightersCountMin, enemyFightersCountMax), 4, 24)
  let allyFighterCountMin = (bombersCount * 0.5 + enemyFightersCount) * 0.3 * planeCost - 4
  let allyFighterCountMax = (bombersCount + enemyFightersCount) * 0.6 * planeCost - 4
  local allyCount = min(rndRangeInt(allyFighterCountMin, allyFighterCountMax), 32)
  if (allyCount < 4)
    allyCount = 0

//enemy planes in each wave
  local bombersCount_temp = bombersCount
  local enemyFightersCount_temp = enemyFightersCount
  let bombersInWave = bombersCount_temp / waveCount
  let fightersInWave = enemyFightersCount_temp / waveCount

  local enemy1BombersCount = 0
  local enemy2BombersCount = 0
  local enemy3BombersCount = 0
  local enemy1FightersCount = 0
  local enemy2FightersCount = 0
  local enemy3FightersCount = 0

  if (waveCount == 1) {
    enemy1BombersCount = bombersCount
    enemy1FightersCount = enemyFightersCount
  }
  else if (waveCount > 1) {
    enemy1BombersCount = max(bombersInWave * rndRange(0.7, 1.3), 4)
    enemy1FightersCount = max(fightersInWave * rndRange(0.7, 1.3), 4)
    bombersCount_temp = bombersCount_temp - enemy1BombersCount
    enemyFightersCount_temp = enemyFightersCount_temp - enemy1FightersCount

    if (waveCount < 3) {
      enemy2BombersCount = bombersCount_temp
      enemy2FightersCount = enemyFightersCount_temp
    }
    else {
      enemy2BombersCount = bombersInWave * rndRange(0.7, 1.3)
      enemy2FightersCount = fightersInWave * rndRange(0.7, 1.3)

      bombersCount_temp = bombersCount_temp - enemy2BombersCount
      enemyFightersCount_temp = enemyFightersCount_temp - enemy2FightersCount

      enemy3BombersCount = bombersCount_temp
      enemy3FightersCount = enemyFightersCount_temp
    }

    enemy2BombersCount = max(enemy2BombersCount, 4)
    enemy2FightersCount = max(enemy2FightersCount, 4)
    enemy3BombersCount = max(enemy3BombersCount, 4)
    enemy3FightersCount = max(enemy3FightersCount, 4)
  }


//battle distance calculate
  local countTime = 1
  if (bombersCount / waveCount > 15)
    countTime = 1.33
  if (bombersCount / waveCount > 23)
    countTime = 1.5

  let rndHeight = rndRange(1500, 3000)
  let playerSpeed = getDistancePerMinute(playerFighterPlane)
  let enemyBomberSpeed = 250 * 1000 / 60.0
  let enemy1TimeToRadar = rndRange(20, 30) / 60.0
  let speedRatio = clamp(playerSpeed * 1.0 / enemyBomberSpeed, 1, 2)
  let timeToEnemy1 = rndRange(90.0 * countTime / speedRatio, 120.0 * countTime / speedRatio) / 60.0
  let enemy1Dist = enemy1TimeToRadar * enemyBomberSpeed + enemyBomberSpeed * timeToEnemy1
    + playerSpeed * timeToEnemy1

  mgSetDistToAction(-enemy1Dist)
  mgSetupAirfield(bombtargets, 6000)
  let startLookAt = mgCreateStartLookAt()
  mgSetReal("variables/enemy1_onRadar", enemy1Dist - enemy1TimeToRadar * enemyBomberSpeed)
  mgSetupArea("player_start", bombtargets, startLookAt, 180,
    rndRange(enemy1TimeToRadar * playerSpeed * 0.5, enemy1TimeToRadar * playerSpeed),
    rndHeight + 500)
  mgSetupArea("ally_start", bombtargets, startLookAt, rndRange(140, 160),
    rndRange(enemy1TimeToRadar * playerSpeed * 0.5, enemy1TimeToRadar * playerSpeed),
    rndHeight + 500)
  mgSetupArea("target_waypoint_bombers", bombtargets, "", 0, 0, rndHeight)
  mgSetupArea("target_waypoint_fighters", bombtargets, "", 0, 0, rndHeight + 500)
  mgSetupArea("evac", bombtargets, startLookAt, 0, 60000, rndHeight)
  mgSetupArea("evac_forCut", bombtargets, startLookAt, 0, 2000, rndHeight)

  let enemy1Angle = rndRange(-45, 45)
  let enemy2Angle = rndRange(-45, 45)
  let enemy3Angle = rndRange(-45, 45)
  mgSetupArea("enemy1_start", bombtargets, startLookAt, enemy1Angle, enemy1Dist, rndHeight)
  mgSetupArea("enemy2_start", bombtargets, startLookAt, enemy2Angle, enemy1Dist, rndHeight)
  mgSetupArea("enemy3_start", bombtargets, startLookAt, enemy3Angle, enemy1Dist, rndHeight)

  let enemy2Time = enemy1Dist / enemyBomberSpeed * 60 + rndRange(0, 30)
  let enemy3Time = enemy1Dist / enemyBomberSpeed * 60 + rndRange(0, 30)
  mgSetInt("variables/enemy2_time", enemy2Time)
  mgSetInt("variables/enemy3_time", enemy3Time)

//armada setup
  mgSetupArmada("#player.fighter", "player_start", Point3(0, 0, 0), bombtargets, "", 4, 4, playerFighterPlane)
  mgSetupArmada("#player_cut.any", "player_start", Point3(0, 0, 0), bombtargets, "", 4, 4, playerFighterPlane)
  gmMarkCutsceneArmadaLooksLike("#player_cut.any", "#player.fighter")

  mgSetupArmada("#enemy04.bomber", "enemy1_start", Point3(0, 0, 0), bombtargets,
    "#enemy_bomber_group01", enemy1BombersCount, enemy1BombersCount, enemyBomberPlane)
  mgSetupArmada("#enemy_cut.any", "enemy1_start", Point3(0, -100, 0), bombtargets,
    "", 6, 6, enemyBomberPlane)
  gmMarkCutsceneArmadaLooksLike("#enemy_cut.any", "#enemy04.bomber")

  mgSetupArmada("#enemy01.fighter", "enemy1_start", Point3(-200, 500, 0), bombtargets,
    "#enemy_fighter_group01", enemy1FightersCount, enemy1FightersCount, enemyFighterPlane)
  if (waveCount > 1) {
    mgSetupArmada("#enemy05.bomber", "enemy2_start", Point3(0, 0, 0), bombtargets,
      "#enemy_bomber_group02", enemy2BombersCount, enemy2BombersCount, enemyBomberPlane)
    mgSetupArmada("#enemy02.fighter", "enemy2_start", Point3(-200, 500, 0), bombtargets,
      "#enemy_fighter_group02", enemy2FightersCount, enemy2FightersCount, enemyFighterPlane)
  }
  if (waveCount > 2) {
    mgSetupArmada("#enemy06.bomber", "enemy3_start", Point3(0, 0, 0), bombtargets,
      "#enemy_bomber_group03", enemy3BombersCount, enemy3BombersCount, enemyBomberPlane)
    mgSetupArmada("#enemy03.fighter", "enemy3_start", Point3(-200, 500, 0), bombtargets,
      "#enemy_fighter_group03", enemy3FightersCount, enemy3FightersCount, enemyFighterPlane)
  }

  if (allyCount != 0)
    mgSetupArmada("#ally01.fighter", "ally_start", Point3(200, 0, 0), bombtargets,
      "#ally_fighters_group", allyCount, allyCount, playerFighterPlane)

  mgSetMinMaxAircrafts("player", "", 1, 8)
  mgSetMinMaxAircrafts("ally", "fighter", 0, 32)
  mgSetMinMaxAircrafts("enemy", "fighter", 0, 24)
  mgSetMinMaxAircrafts("enemy", "bomber", 8, 32)

//mission warpoint cost calculate
  let mission_mult = sqrt(bombersCount / 15.0 + 0.05)
  let missionWpCost = warpointCalculate(mission_preset_name, allyCount / 0.6,
    enemyFightersCount + bombersCount * 0.5, planeCost, playerFighterPlane, mission_mult)
  mgSetInt("mission_settings/mission/wpAward", missionWpCost)

  mgSetEffShootingRate(0.1)

  if (playerFighterPlane == "")
    return

  slidesReplace(mgGetLevelName(), mgGetMissionSector(), ground_type)

  mgSetBool("variables/training_mode", isFreeFlight)

//  mgDebugDump("E:/dagor2/skyquake/develop/gameBase/gameData/missions/dynamic_campaign/objectives/testBombingDefense_temp.blk")
  if (mgFullLogs())
    debug_dump_stack()

  mgAcceptMission()
}

let function genBombingDefenseMission(isFreeFlight) {
  generateBombingDefMission(isFreeFlight,
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
  genBombingDefenseMission
}
