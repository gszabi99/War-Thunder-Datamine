from "math" import max, min, sqrt, clamp

let { Point3 } = require("dagor.math")
let { getEnemyPlaneByWpCost, planeCostCalculate, warpointCalculate, slidesReplace
} = require("%scripts/dynamic/misGenFuncTools.nut")
let { debug_dump_stack } = require("dagor.debug")
let { mgBeginMission, mgGetPlayerSide, mgAcceptMission, mgFullLogs, mgSetStr, mgSetInt,
  mgSetReal, mgSetBool, mgGetEnemySide, mgCreateStartLookAt, mgCreateGroundUnits,
  mgGetUnitsCount, mgSetupArmada, mgSetupArea, rndRange, rndRangeInt, getDistancePerMinute,
  getAircraftCost, getAnyPlayerFighter, mgReplace, mgSetupAirfield, mgSetDistToAction,
  getAircraftDescription, gmMarkCutsceneArmadaLooksLike, mgSetEffShootingRate, mgGetMissionSector,
  mgGetLevelName, mgSetMinMaxAircrafts
} = require("dynamicMission")

function generateAssaultDefMission(isFreeFlight, createGroundUnitsProc) {
  let mission_preset_name = "ground_defense_preset02"
  mgBeginMission($"gameData/missions/dynamic_campaign/objectives/{mission_preset_name}.blk")
  let playerSide = mgGetPlayerSide()
  let enemySide = mgGetEnemySide()
  let bombtargets = createGroundUnitsProc(playerSide)
  local enemyAssaultPlane = ""


  let wpMax = 1000000
  let playerFighterPlane = getAnyPlayerFighter(0, wpMax)
  local playerPlaneCost = getAircraftCost(playerFighterPlane)
  if (playerPlaneCost == 0)
    playerPlaneCost = 250

  let enemyFighterPlane = getEnemyPlaneByWpCost(playerPlaneCost, enemySide)
  local enemyPlaneCost = getAircraftCost(enemyFighterPlane)
  if (enemyPlaneCost == 0)
    enemyPlaneCost = 250

  let planeCost = planeCostCalculate(playerPlaneCost, enemyPlaneCost)

  local bombersCount = 0
  local countToFail = 1

  local ground_type = ""
  local squad_type = ""
  local mission_name = ""
  local indicator_icon = ""
  let tanks_count = mgGetUnitsCount("#bomb_targets_tanks")
  let light_count = mgGetUnitsCount("#bomb_targets_light")
  let art_count = mgGetUnitsCount("#bomb_targets_art")
  let ships_count = mgGetUnitsCount("#bomb_targets_ships")


  if (tanks_count > 0 && tanks_count > light_count && tanks_count > art_count) {
    bombersCount = rndRangeInt(tanks_count * 3, tanks_count * 6)
    ground_type = "tank"
    squad_type = "#bomb_targets_tanks"
    enemyAssaultPlane = getAircraftDescription(enemySide, "assault", ["can_be_assault"],
      ["antiTankBomb", "antiTankRocket"], false, 0, wpMax)
    mission_name = "dynamic_defense_ga_tank"
    indicator_icon = "tank"
    countToFail = tanks_count / 2
  }
  else if (light_count > 0 && light_count > art_count) {
    bombersCount = rndRangeInt(light_count * 2, light_count * 4)
    ground_type = "truck"
    squad_type = "#bomb_targets_light"
    enemyAssaultPlane = getAircraftDescription(enemySide, "assault", ["can_be_assault"],
      ["rocket", "bomb", "cannon"], false, 0, wpMax)
    mission_name = "dynamic_defense_ga_vehicles"
    indicator_icon = "truck"
    countToFail = light_count / 2
  }
  else if (art_count > 0) {
    bombersCount = rndRangeInt(art_count * 2, art_count * 4)
    ground_type = "artillery"
    squad_type = "#bomb_targets_art"
    enemyAssaultPlane = getAircraftDescription(enemySide, "assault", ["can_be_assault"],
      ["rocket", "bomb", "cannon"], false, 0, wpMax)
    mission_name = "dynamic_defense_ga_anti_tank"
    indicator_icon = "cannon"
    countToFail = art_count / 2
  }
  else if (ships_count > 0) {
    bombersCount = rndRangeInt(ships_count * 4, ships_count * 8)
    ground_type = "destroyer"
    squad_type = "#bomb_targets_ships"
    enemyAssaultPlane = getAircraftDescription(enemySide, "assault", ["can_be_assault"],
      ["antiShipBomb", "antiShipRocket"], false, 0, wpMax)
    mission_name = "dynamic_defense_ga_ships"
    indicator_icon = "ship"
    countToFail = ships_count / 2
  }
  else
    return

  if (playerFighterPlane == "" || enemyFighterPlane == "" || enemyAssaultPlane == "")
    return

  countToFail = max(countToFail, 1)
  mgReplace("mission_settings/briefing/part", "icontype", "carrier", ground_type)
  mgReplace("mission_settings/briefing/part", "point", "#bomb_targets", squad_type)
  mgReplace("mission_settings/briefing/part", "target", "#bomb_targets", squad_type)
  mgReplace("triggers", "object", "#bomb_targets", squad_type)
  mgReplace("triggers", "target", "#bomb_targets", squad_type)
  mgSetStr("mission_settings/mission/name", mission_name)
  mgReplace("triggers", "icon", "air", indicator_icon)
  mgSetInt("variables/count_to_fail", countToFail)

  if (indicator_icon != "ship") {
    mgReplace("mission_settings/briefing/part", "target", "target_waypoint_bombers", squad_type)
    mgReplace("mission_settings/briefing/part", "lookAt", "target_waypoint_bombers", squad_type)
  }
  bombersCount = clamp(bombersCount, 8, 24)

  let enemyWaveCount = bombersCount < 13 ? 1
    : bombersCount < 20 ? rndRangeInt(1, 2)
    : 2
  mgSetInt("variables/wave_max", enemyWaveCount)

  local enemy1BombersCount = bombersCount / enemyWaveCount
  if (enemyWaveCount > 1)
    enemy1BombersCount = enemy1BombersCount * rndRange(0.75, 1.25)
  enemy1BombersCount = max(enemy1BombersCount, 4)
  local enemy2BombersCount = bombersCount - enemy1BombersCount
  if (enemyWaveCount > 1)
    enemy2BombersCount = max(enemy2BombersCount, 4)

  let enemy1FighersCount = enemy1BombersCount * rndRange(0.75, 1) / 1.2
  let enemy2FighersCount = enemy2BombersCount * rndRange(0.75, 1) / 1.2
  let enemyFightersCount = min(enemy1FighersCount + enemy2FighersCount, 20)

  let allyFighterCountMin = (bombersCount * 0.5 + enemyFightersCount) * 0.5 * planeCost - 4
  let allyFighterCountMax = (bombersCount + enemyFightersCount) * planeCost - 4

  local allyFighterCount = min(rndRangeInt(allyFighterCountMin, allyFighterCountMax), 40)
  if (allyFighterCount < 4)
    allyFighterCount = 0

  let rndHeight = rndRange(1500, 3000)
  let enemySpeed = getDistancePerMinute(enemyAssaultPlane)


  let timeToEnemy1 = rndRange(60, 120) / 60.0
  let timeToEnemy2 = rndRange(120, 150) / 60.0

  mgSetDistToAction(-enemySpeed * timeToEnemy2)
  mgSetupAirfield(bombtargets, 6000)
  let startLookAt = mgCreateStartLookAt()

  mgSetInt("variables/timeTo_enemy2", timeToEnemy1 * 60 + rndRangeInt(120, 240))
  mgSetReal("variables/enemy1_onRadar", enemySpeed * timeToEnemy1 * 0.75)
  mgSetReal("variables/enemy2_onRadar", enemySpeed * (timeToEnemy2 - timeToEnemy1 * 0.75))

  let enemy1Angle = rndRange(-45, 45)
  let enemy2Angle = rndRange(-45, 45)
  let evacAngle = rndRange(-10, 10)

  mgSetupArea("player_start", bombtargets, startLookAt, 180, rndRange(4500, 6000), rndHeight + 500)
  mgSetupArea("target_waypoint_bombers", bombtargets, "", 0, 0, rndHeight)
  mgSetupArea("target_waypoint_fighters", bombtargets, "", 0, 0, rndHeight + 500)

  mgSetupArea("evac", bombtargets, startLookAt, evacAngle, 60000, rndHeight)
  mgSetupArea("evac_forCut", bombtargets, startLookAt, 0, 2000, rndHeight)

  mgSetupArea("enemy1_start", bombtargets, startLookAt, enemy1Angle,
    enemySpeed * timeToEnemy1, rndHeight)

  mgSetupArea("enemy2_start", bombtargets, startLookAt, enemy2Angle,
    enemySpeed * timeToEnemy2, rndHeight)


  mgSetupArmada("#player.fighter", "player_start", Point3(0, 0, 0), bombtargets, "", 4, 4, playerFighterPlane)
  mgSetupArmada("#player_cut.any", "player_start", Point3(0, 0, 0), bombtargets, "", 4, 4, playerFighterPlane)
  gmMarkCutsceneArmadaLooksLike("#player_cut.any", "#player.fighter")

  mgSetupArmada("#enemy03.assault", "enemy1_start", Point3(0, 0, 0), bombtargets,
    "#enemy_assault_group01", enemy1BombersCount, enemy1BombersCount, enemyAssaultPlane)
  mgSetupArmada("#enemy01.fighter", "enemy1_start", Point3(-200, 500, 0), bombtargets,
    "#enemy_fighter_group01", enemy1FighersCount, enemy1FighersCount, enemyFighterPlane)
  if (enemyWaveCount > 1) {
    mgSetupArmada("#enemy04.assault", "enemy2_start", Point3(0, 0, 0), bombtargets,
      "#enemy_assault_group02", enemy2BombersCount, enemy2BombersCount, enemyAssaultPlane)
    mgSetupArmada("#enemy02.fighter", "enemy2_start", Point3(-200, 500, 0), bombtargets,
      "#enemy_fighter_group02", enemy2FighersCount, enemy2FighersCount, enemyFighterPlane)
  }

  if (allyFighterCount != 0)
    mgSetupArmada("#ally01.fighter", "#player.fighter", Point3(-500, 500, 0), bombtargets,
      "#ally_fighters_group", allyFighterCount, allyFighterCount, playerFighterPlane)

  mgSetMinMaxAircrafts("player", "", 1, 8)
  mgSetMinMaxAircrafts("ally", "fighter", 0, 40)
  mgSetMinMaxAircrafts("enemy", "fighter", 0, 24)
  mgSetMinMaxAircrafts("enemy", "assault", 8, 24)


  let mission_mult = sqrt(bombersCount / 11.0 + 0.05)
  let missionWpCost = warpointCalculate(mission_preset_name, allyFighterCount,
    enemyFightersCount + bombersCount * 0.5, planeCost, playerFighterPlane, mission_mult)
  mgSetInt("mission_settings/mission/wpAward", missionWpCost)

  mgSetEffShootingRate(0.1)

  if (playerFighterPlane == "")
    return

  slidesReplace(mgGetLevelName(), mgGetMissionSector(), ground_type)

  mgSetBool("variables/training_mode", isFreeFlight)

  
  if (mgFullLogs())
    debug_dump_stack()

  mgAcceptMission()
}

function genAssaultDefenseMission(isFreeFlight) {
  generateAssaultDefMission(isFreeFlight,
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
          carriers = "#bomb_target_cover"
        })
    }
  )
}

return {
  genAssaultDefenseMission
}
