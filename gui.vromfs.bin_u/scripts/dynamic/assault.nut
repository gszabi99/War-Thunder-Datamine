from "math" import min, sqrt, clamp

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

let function generateGAttackMission(isFreeFlight, createGroundUnitsProc) {
  let mission_preset_name = "ground_attack_preset01"
  mgBeginMission($"gameData/missions/dynamic_campaign/objectives/{mission_preset_name}.blk")
  let playerSide = mgGetPlayerSide()
  let enemySide = mgGetEnemySide()
  let bombtargets = createGroundUnitsProc(enemySide)

  local playerAssaultPlane = ""

  local bombersCount = 0
  local ground_type = ""
  local squad_type = ""
  local mission_name = ""
  local indicator_icon = ""
  let tanks_count = mgGetUnitsCount("#bomb_targets_tanks")
  let light_count = mgGetUnitsCount("#bomb_targets_light")
  let art_count = mgGetUnitsCount("#bomb_targets_art")
  let ships_count = mgGetUnitsCount("#bomb_targets_ships")

//planes cost calculate
  let wpMax = 1000000
  let allyFighterPlane = getAnyFighter(playerSide, 0, wpMax)
  local playerPlaneCost = getAircraftCost(allyFighterPlane)
  if (playerPlaneCost == 0)
    playerPlaneCost = 250

  let enemyFighterPlane = getEnemyPlaneByWpCost(playerPlaneCost, enemySide)
  local enemyPlaneCost = getAircraftCost(enemyFighterPlane)
  if (enemyPlaneCost == 0)
    enemyPlaneCost = 250

  let planeCost = planeCostCalculate(playerPlaneCost, enemyPlaneCost)
  local time_mult = 2
//mission type and bombers count setup
  if (tanks_count > 0 && tanks_count > light_count && tanks_count > art_count) {
    bombersCount = rndRangeInt(tanks_count * 2, tanks_count * 5) - 4
    ground_type = "tank"
    mgSetInt("variables/count_to_kill", 1)
    mgSetBool("variables/tank_mission", true)
    squad_type = "#bomb_targets_tanks"
    mission_name = "dynamic_assault_tanks"
    indicator_icon = "tank"
    playerAssaultPlane = getAircraftDescription(playerSide, "assault", ["can_be_assault"],
      ["antiTankBomb", "antiTankRocket"], true, 0, wpMax)
    time_mult = 4
  }
  else if (light_count > 0 && light_count > art_count) {
    bombersCount = rndRangeInt(light_count, light_count * 3) - 4
    ground_type = "truck"
    mgSetInt("variables/count_to_kill", 4)
    squad_type = "#bomb_targets_light"
    mission_name = "dynamic_assault_lightV"
    indicator_icon = "truck"
    playerAssaultPlane = getAircraftDescription(playerSide, "assault", ["can_be_assault"],
      ["rocket", "bomb", "cannon"], true, 0, wpMax)
  }
  else if (art_count > 0) {
    bombersCount = rndRangeInt(art_count, art_count * 3) - 4
    ground_type = "artillery"
    mgSetInt("variables/count_to_kill", 4)
    squad_type = "#bomb_targets_art"
    mission_name = "dynamic_assault_artillery"
    indicator_icon = "cannon"
    playerAssaultPlane = getAircraftDescription(playerSide, "assault", ["can_be_assault"],
      ["rocket", "bomb", "cannon"], true, 0, wpMax)
  }
  else if (ships_count > 0) {
    bombersCount = rndRangeInt(ships_count * 4, ships_count * 8) - 4
    ground_type = "destroyer"
    mgSetInt("variables/count_to_kill", 1)
    squad_type = "#bomb_targets_ships"
    mission_name = "dynamic_assault_ships"
    indicator_icon = "ship"
    playerAssaultPlane = getAircraftDescription(playerSide, "assault", ["can_be_assault"],
      ["antiShipBomb", "antiShipRocket"], true, 0, wpMax)
    time_mult = 4
    mgSetBool("variables/is_target_ship", true)
  }
  else
    return

  time_mult = time_mult * 60

  mgSetInt("variables/failTimer", time_mult)

  mgReplace("mission_settings/briefing/part", "icontype", "carrier", ground_type)
  mgReplace("mission_settings/briefing/part", "point", "#bomb_targets", squad_type)
  mgReplace("mission_settings/briefing/part", "target", "#bomb_targets", squad_type)
  mgReplace("triggers", "object", "#bomb_targets", squad_type)
  mgReplace("triggers", "target", "#bomb_targets", squad_type)
  mgSetStr("mission_settings/mission/name", mission_name)
  mgReplace("triggers", "icon", "air", indicator_icon)

  if (indicator_icon != "ship") {
    mgReplace("mission_settings/briefing/part", "target", "target_waypoint_bombers", squad_type)
    mgReplace("mission_settings/briefing/part", "lookAt", "target_waypoint_bombers", squad_type)
    mgReplace("mission_settings/briefing/part", "point", "target_waypoint_bombers", squad_type)
  }

  if (playerAssaultPlane == "" || allyFighterPlane == "" || enemyFighterPlane == "")
    return

  bombersCount = min(bombersCount, 20)
//ally and enemy fighters calculate
  let allyFighterCountMax = (bombersCount + 4) * planeCost
  let allyFightersCount = clamp(rndRangeInt(4, allyFighterCountMax), 4, 24)
  let enemyTotalCountMin = (bombersCount * 0.5 + allyFightersCount + 4) * 0.5 / planeCost
  let enemyTotalCountMax = (bombersCount + allyFightersCount + 4) / planeCost
  let enemyTotalCount = clamp(rndRangeInt(enemyTotalCountMin, enemyTotalCountMax), 8, 44)
  let rndHeight = rndRange(2000, 4000)
//battle distance calculate
  let playerSpeed = getDistancePerMinute(playerAssaultPlane)
  let enemySpeed = getDistancePerMinute(enemyFighterPlane)

  let timeToTarget = rndRange(60, 120) / 60.0
  let timeToEnemy1 = rndRange(30, timeToTarget * 60 / 2.0) / 60.0

  mgSetDistToAction(playerSpeed * timeToTarget + 2000)
  mgSetupAirfield(bombtargets, playerSpeed * timeToTarget + 3000)
  let startLookAt = mgCreateStartLookAt()
  let enemy1Angle = rndRange(-90, 90)
  let evacAngle = rndRange(-10, 10)
//points placing
  mgSetupArea("player_start", bombtargets, startLookAt, 180, playerSpeed * timeToTarget, rndHeight)
  mgSetupArea("ally_start", bombtargets, startLookAt, 180, playerSpeed * timeToTarget + 200, rndHeight)
  mgSetupArea("target_waypoint_bombers", bombtargets, "", 0, 0, rndHeight)
  mgSetupArea("target_waypoint_fighters", bombtargets, "", 0, 0, rndHeight + 200)
  mgSetupArea("evac", bombtargets, "player_start", evacAngle, playerSpeed * timeToTarget, rndHeight)
  mgSetupArea("evac_forCut", "evac", bombtargets, 0, 2000, 0)

  mgSetupArea("enemy1_pointToFight", "player_start", bombtargets, 0,
    playerSpeed * timeToEnemy1, rndHeight + rndRange(0, 2000))
  mgSetupArea("enemy1_start", "enemy1_pointToFight", bombtargets, enemy1Angle,
    enemySpeed * timeToEnemy1, 0)

  mgSetupArea("enemy2_start", bombtargets, "player_start", 180,
    3000, rndHeight + 500)


//armada setup
  mgSetupArmada("#player.assault", "player_start", Point3(0, 0, 0), bombtargets, "", 4, 4, playerAssaultPlane)
  mgSetupArmada("#player_cut.any", "player_start", Point3(0, 0, 0), bombtargets, "", 4, 4, playerAssaultPlane)
  gmMarkCutsceneArmadaLooksLike("#player_cut.any", "#player.assault")

  if (bombersCount > 4) {
    mgSetupArmada("#ally01.assault", "ally_start", Point3(0, 0, 0), bombtargets,
      "#ally_assault_group", bombersCount, bombersCount, playerAssaultPlane)
    bombersCount = mgGetUnitsCount("#ally01.assault")
  }
  else
    bombersCount = 0

  mgSetupArmada("#ally02.fighter", "ally_start", Point3(0, 200, 0), bombtargets,
    "#ally_fighters_group", allyFightersCount, allyFightersCount, allyFighterPlane)

  local enemy2Count = enemyTotalCount
  if (enemyTotalCount > 16 && timeToTarget > 1.5) {
    let enemy1Count = clamp(rndRangeInt(enemyTotalCount / 2 * 0.75, enemyTotalCount / 2 * 1.25),
      4, enemyTotalCount - 4)
    mgSetupArmada("#enemy01.fighter", "enemy1_start", Point3(0, 0, 0), "#player.assault",
      "#enemy_group01", enemy1Count, enemy1Count, enemyFighterPlane)
    enemy2Count = enemyTotalCount - enemy1Count
  }

  mgSetupArmada("#enemy02.fighter", "enemy2_start", Point3(0, 0, 0), "#player.assault",
    "#enemy_group01", enemy2Count, enemy2Count, enemyFighterPlane)

  mgSetMinMaxAircrafts("player", "", 1, 8)
  mgSetMinMaxAircrafts("ally", "fighter", 0, 24)
  mgSetMinMaxAircrafts("ally", "assault", 0, 20)
  mgSetMinMaxAircrafts("enemy", "fighter", 0, 44)


//mission warpoint cost calculate
  let mission_mult = sqrt(bombersCount / 20.0 + 0.05)
  let ally_all_count = allyFightersCount + (bombersCount) * 0.5 - 4
  let missionWpCost = warpointCalculate(mission_preset_name, ally_all_count, enemyTotalCount, planeCost,
    playerAssaultPlane, mission_mult)
  mgSetInt("mission_settings/mission/wpAward", missionWpCost)

  mgSetEffShootingRate(0.4)

  if (playerAssaultPlane == "")
    return

  slidesReplace(mgGetLevelName(), mgGetMissionSector(), ground_type)

  mgSetBool("variables/training_mode", isFreeFlight)

  //mgDebugDump("E:/dagor2/skyquake/develop/gameBase/gameData/missions/dynamic_campaign/objectives/testAssault_temp.blk")
  if (mgFullLogs())
    debug_dump_stack()

  mgAcceptMission()
}

let function genAssaultFirstMission(isFreeFlight) {
  generateGAttackMission(isFreeFlight,
    @(enemySide) mgCreateGroundUnits(enemySide, false, false,
      {
        heavy_vehicles = "#bomb_target_cover"
        light_vehicles = "#bomb_targets_light"
        infantry = "#bomb_target_cover"
        air_defence = "#bomb_target_cover"
        anti_tank = "#bomb_targets_art"
        bombtarget = "*"
        ships = "#bomb_target_cover"
        carriers = "#bomb_target_cover"
      })
  )
}

let function genAssaultSecondMission(isFreeFlight) {
  generateGAttackMission(isFreeFlight,
    @(enemySide) mgCreateGroundUnits(enemySide, false, false,
      {
        heavy_vehicles = "#bomb_target_cover"
        light_vehicles = "*"
        infantry = "#bomb_target_cover"
        air_defence = "#bomb_target_cover"
        anti_tank = "*"
        ships = "#bomb_targets_ships"
        carriers = "#bomb_target_cover"
      })
  )
}

let function genAssaultThirdMission(isFreeFlight) {
  generateGAttackMission(isFreeFlight,
    @(enemySide) mgCreateGroundUnits(enemySide, false, false,
      {
        heavy_vehicles = "#bomb_targets_tanks"
        light_vehicles = "#bomb_target_cover"
        infantry = "#bomb_target_cover"
        air_defence = "#bomb_target_cover"
        anti_tank = "#bomb_target_cover"
        bombtarget = "*"
        ships = "#bomb_target_cover"
        carriers = "#bomb_target_cover"
      })
  )
}

return {
  genAssaultFirstMission
  genAssaultSecondMission
  genAssaultThirdMission
}