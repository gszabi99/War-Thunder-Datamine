//-file:plus-string
//checked for explicitness
#no-root-fallback
#explicit-this

let { Point3 } = require("dagor.math")
let { getEnemyPlaneByWpCost, planeCostCalculate, warpointCalculate, slidesReplace
} = require("%scripts/dynamic/misGenFuncTools.nut")
let { sqrt } = require("%sqstd/math.nut")
let { debug_dump_stack } = require("dagor.debug")
let { mgBeginMission, mgGetPlayerSide, mgAcceptMission, mgFullLogs, mgSetInt,
  mgGetEnemySide, mgCreateStartPoint, mgCreateStartLookAt, mgSetupArmada,
  mgSetupArea, rndRange, rndRangeInt, getDistancePerMinute, getAircraftCost,
  getAnyPlayerFighter, mgReplace, mgSetupAirfield, mgRemoveStrParam,
  gmMarkCutsceneArmadaLooksLike, mgSetEffShootingRate, mgGetMissionSector,
  mgGetLevelName, mgEnsurePointsInMap, mgSetMinMaxAircrafts
} = require("dynamicMission")
let { get_warpoints_blk } = require("blkGetters")

let function genCombatPatrolMission(_isFreeFlight) {
  let mission_preset_name = "dogfight_preset01"
  mgBeginMission($"gameData/missions/dynamic_campaign/objectives/{mission_preset_name}.blk")
  let startPos = mgCreateStartPoint(0)
  let playerSide = mgGetPlayerSide()
  let enemySide = mgGetEnemySide()

//planes cost and warpoint ratio calculate
  let ws = get_warpoints_blk()
  local wpMax = ws.dynPlanesMaxCost
  let playerFighterPlane = getAnyPlayerFighter(0, wpMax)
  local playerPlaneCost = getAircraftCost(playerFighterPlane)
  if (playerPlaneCost == 0)
    playerPlaneCost = 250

  let enemyFighterPlane = getEnemyPlaneByWpCost(playerPlaneCost, enemySide)
  local enemyPlaneCost = getAircraftCost(enemyFighterPlane)
  if (enemyPlaneCost == 0)
    enemyPlaneCost = 250

  let planeCost = planeCostCalculate(playerPlaneCost, enemyPlaneCost)

  if (playerFighterPlane == "" || enemyFighterPlane == "")
    return

  let playerSpeed = getDistancePerMinute(playerFighterPlane)
  let enemy1FighterPlane = enemyFighterPlane
  let enemy1FighterSpeed = getDistancePerMinute(enemy1FighterPlane)
  let enemy2FighterPlane = getEnemyPlaneByWpCost(playerPlaneCost, enemySide)
  let enemy2FighterSpeed = getDistancePerMinute(enemy1FighterPlane)
  let enemy3FighterPlane = getEnemyPlaneByWpCost(playerPlaneCost, enemySide)
  let enemy3FighterSpeed = getDistancePerMinute(enemy1FighterPlane)

  let ally1FighterPlane = getEnemyPlaneByWpCost(playerPlaneCost, playerSide)
  let ally1FighterSpeed = getDistancePerMinute(ally1FighterPlane)
  let ally2FighterPlane = getEnemyPlaneByWpCost(playerPlaneCost, playerSide)
  let ally2FighterSpeed = getDistancePerMinute(ally2FighterPlane)
  let ally3FighterPlane = getEnemyPlaneByWpCost(playerPlaneCost, playerSide)
  let ally3FighterSpeed = getDistancePerMinute(ally3FighterPlane)

  let maxWpTime = max(60 + 40 / (playerSpeed / 2000.0), 120)
  let wpTime1 = rndRange(60, maxWpTime) / 60.0
  let wpTime2 = rndRange(60, maxWpTime) / 60.0
  let wpTime3 = rndRange(60, maxWpTime) / 60.0
  let wpDist1 = playerSpeed * 1.0 * wpTime1
  let wpDist2 = playerSpeed * 1.0 * wpTime2
  let wpDist3 = playerSpeed * 1.0 * wpTime3

  wpMax = rndRangeInt(2, 4)
  let rndHeight = rndRange(1000, 2000)
  mgSetInt("variables/wp_max", wpMax)

  let enemyTotal = clamp(rndRangeInt(4 * (wpMax - 1), 32) / planeCost, 4 * (wpMax - 1), 32)
  let enemyPerWp = enemyTotal / (wpMax - 1)

  local allyWp1Count = 0
  local allyWp2Count = 0
  local allyWp3Count = 0
  local enemyWp1Count = 0
  local enemyWp2Count = 0
  local enemyWp3Count = 0
  local noEnemy = 0

  mgSetupAirfield(startPos, wpDist1 + 3000)
  let startLookAt = mgCreateStartLookAt()
  mgSetupArea("waypoint00", startPos, startLookAt, 180, 0, rndHeight)
  mgSetupArea("waypoint01", startPos, startLookAt, 180 + rndRange(-60, 60), playerSpeed * rndRange(30, 60) / 60.0, rndHeight)
  mgSetupArea("waypoint02", "waypoint01", startPos, rndRange(-60, 60), -wpDist1, 0)
  mgSetupArea("enemy_evac01", "waypoint02", "waypoint01", 90, 60000, 0)

  let offsetPoints = ["waypoint00", "waypoint01", "waypoint02"]

  local lastWp = "waypoint02"
  if (wpMax > 2) {
    mgSetupArea("waypoint03", "waypoint02", "waypoint01", rndRange(-60, 60), -wpDist2, 0)
    mgSetupArea("enemy_evac02", "waypoint03", "waypoint02", 90, 60000, 0)
    lastWp = "waypoint03"
    offsetPoints.append("waypoint03")
  }
  else
    mgRemoveStrParam("mission_settings/briefing/part", "waypoint03")

  if (wpMax > 3) {
    mgSetupArea("waypoint04", "waypoint03", "waypoint02", rndRange(-60, 60), -wpDist3, 0)
    mgSetupArea("enemy_evac03", "waypoint04", "waypoint03", 90, 60000, 0)
    lastWp = "waypoint04"
    offsetPoints.append("waypoint04")
  }
  else
    mgRemoveStrParam("mission_settings/briefing/part", "waypoint04")

  mgSetupArea("evac", lastWp, startPos, 0, playerSpeed * rndRange(0.5, 1.5) + 2500, 0)
  mgReplace("mission_settings/briefing/part", "point", "waypoint_end", lastWp)
  offsetPoints.append("evac")
  mgEnsurePointsInMap(offsetPoints)

  mgSetupArea("evac_forCut", "evac", startPos, 0, 2000, 0)

  let battle_point_wp01Time = rndRange(40, wpTime1 * 60 - 20) / 60.0
  local battle_point_wp01Dist = playerSpeed * battle_point_wp01Time
  let battle_point_wp02Time = rndRange(40, wpTime2 * 60 - 20) / 60.0
  let battle_point_wp02Dist = playerSpeed * battle_point_wp02Time
  let battle_point_wp03Time = rndRange(40, wpTime3 * 60 - 20) / 60.0
  let battle_point_wp03Dist = playerSpeed * battle_point_wp03Time

  battle_point_wp01Dist = max(battle_point_wp01Dist, 3000)
  local enemySet = 0

  local allyFromStartCount = (enemyPerWp - 4) * rndRange(0, 1) * planeCost
  if (allyFromStartCount < 2)
    allyFromStartCount = 0
  else if (allyFromStartCount < 4)
    allyFromStartCount = 4
  if (allyFromStartCount > enemyPerWp)
    allyFromStartCount = enemyPerWp

  local allySet = (allyFromStartCount + 4) / planeCost

  for (local j = 1; j <= (wpMax - 1); j++) {
    local event = rndRangeInt(1, 6)
    local point = ""
    local lookAt = ""
    local squad = ""

    local dist = 0
    local time = 0
    local enemySpeed = 0
    local enemyPlane = 0
    local allyPlane = 0
    local allySpeed = 0

    local enemyWpCount = 0
    local allyWpCount = 0

    if (j == (wpMax - 1))
      noEnemy = -2

    let enemyAllyRatio = enemySet - allySet

    enemyWpCount = clamp(-enemyAllyRatio / planeCost * rndRange(0.75, 1.25), 4, enemyPerWp * 1.25)
    allyWpCount = clamp(enemyAllyRatio * planeCost * rndRange(0.75, 1.25), 4, enemyPerWp * 1.25)
    if (enemyAllyRatio <= -1 && enemyAllyRatio >= -enemyPerWp / 2)
      event = rndRangeInt(1, 6 + noEnemy)

    if (enemyAllyRatio < -enemyPerWp / 2)
      event = rndRangeInt(1, 3)

    if (enemyAllyRatio >= 1)
      event = rndRangeInt(4, 6 + noEnemy)

    if (enemyAllyRatio > -1 && enemyAllyRatio < 1)
      event = rndRangeInt(4, 5 + (noEnemy / 2))

    if (event < 4)
      allyWpCount = 0
    else if (event > 4) {
      enemyWpCount = 0
      noEnemy = -2
    }
    else {
      enemyWpCount = clamp((enemyPerWp * rndRange(0.5, 1) - enemyAllyRatio) / planeCost, 4, enemyPerWp)
      allyWpCount = clamp((enemyWpCount + enemyAllyRatio) * rndRange(0.75, 1.25) * planeCost, 4, enemyPerWp)
    }

    switch (j) {
      case 1: {
        dist = battle_point_wp01Dist
        time = battle_point_wp01Time
        enemySpeed = enemy1FighterSpeed
        enemyPlane = enemy1FighterPlane
        allyPlane = ally1FighterPlane
        allySpeed = ally1FighterSpeed
        if (allyFromStartCount > 0)
          mgSetupArmada("#ally07.fighter", "waypoint00", Point3(-300, 0, 0), "waypoint01",
            "#ally_fromstart", allyFromStartCount, allyFromStartCount, playerFighterPlane)
      }
      break
      case 2: {
        dist = battle_point_wp02Dist
        time = battle_point_wp02Time
        enemySpeed = enemy2FighterSpeed
        enemyPlane = enemy2FighterPlane
        allyPlane = ally2FighterPlane
        allySpeed = ally2FighterSpeed
      }
      break
      case 3: {
        dist = battle_point_wp03Dist
        time = battle_point_wp03Time
        enemySpeed = enemy3FighterSpeed
        enemyPlane = enemy3FighterPlane
        allyPlane = ally3FighterPlane
        allySpeed = ally3FighterSpeed
      }
      break
    }

    mgSetupArea("battle_point_wp0" + j, "waypoint0" + j, "waypoint0" + (j + 1), 0, dist, 0)
    mgSetupArea("forAttack_wp0" + j + "_moveTo", "battle_point_wp0" + j, "waypoint0" + (j + 1), rndRange(-30, 30),
      30000, rndRange(-500, 0))
    mgSetupArea("headOnCourse_wp0" + j, "battle_point_wp0" + j, "waypoint0" + (j + 1), rndRange(-60, 60),
      enemySpeed * time, rndRange(-500, 500))
    mgSetupArea("fromBack_wp0" + j, "waypoint0" + j, "waypoint0" + (j - 1), rndRange(-30, 30),
      enemySpeed * 0.2, 3000)
    mgSetupArea("battle_enemy_wp0" + j, "battle_point_wp0" + j, "waypoint0" + (j + 1), 90,
      enemySpeed * 20 / 60, rndRange(-500, 500))
    mgSetupArea("battle_ally_wp0" + j, "battle_point_wp0" + j, "waypoint0" + (j + 1), -90,
      allySpeed * 20 / 60, rndRange(-500, 500))
    mgSetupArea("reinforsment_enemy_wp0" + j, "battle_point_wp0" + j, "waypoint0" + (j + 1), rndRange(45, 135),
      enemySpeed * rndRange(30, 90) / 60.0, rndRange(-500, 500))
    mgSetupArea("reinforsment_ally_wp0" + j, "battle_point_wp0" + j, "waypoint0" + (j + 1), rndRange(-45, -135),
      allySpeed * rndRange(30, 90) / 60.0, rndRange(-500, 500))

    let k = event

    switch (k) {
      case 1: {
        point = "headOnCourse_wp0" + j
        lookAt = "waypoint0" + j
        squad = "#enemy_attack_player_wp0" + j
      }
      break
      case 2: {
        point = "battle_point_wp0" + j
        lookAt = "waypoint0" + (j + 1)
        squad = "#enemy_move_wp0" + j
      }
      break
      case 3: {
        point = "fromBack_wp0" + j
        lookAt = "waypoint0" + j
        squad = "#enemy_attack_player_wp0" + j
      }
      break
      case 4: {
        point = "battle_enemy_wp0" + j
        lookAt = "battle_point_wp0" + j
        squad = "#enemy_battle_wp0" + j
        mgSetupArmada("#ally0" + j + ".fighter", "battle_ally_wp0" + j, Point3(0, 0, 0), "waypoint0" + j,
          "#ally_battle_wp0" + j, allyWpCount, allyWpCount, allyPlane)
      }
      break
      case 5: {
        mgSetupArmada("#ally0" + j + ".fighter", "fromBack_wp0" + j, Point3(0, 0, 0), "waypoint0" + j,
          "#ally_move_wp0" + j, allyWpCount, allyWpCount, allyPlane)
      }
      break
      case 6: {
        allyWpCount = 0
      }
      break
    }

    let enemyReinfCount = enemyWpCount * rndRange(0, 0.25)
    let allyReinfCount = allyWpCount * rndRange(0, 0.25)

    if (event < 5) {
      mgSetupArmada("#enemy0" + j + ".fighter", point, Point3(0, 0, 0), lookAt,
        squad, enemyWpCount, enemyWpCount, enemyPlane)
      let reinf = rndRange(0, 1)
      if (reinf > 0.75 && reinf < 0.90 && enemyReinfCount >= 3)
        mgSetupArmada("#enemy0" + (j + 3) + ".fighter", "reinforsment_enemy_wp0" + j, Point3(0, 0, 0), lookAt,
          "#enemy_reinforcements0" + j, enemyReinfCount, enemyReinfCount, enemyPlane)
      if (reinf > 0.85 && allyReinfCount >= 4)
        mgSetupArmada("#ally0" + (j + 3) + ".fighter", "reinforsment_ally_wp0" + j, Point3(0, 0, 0), lookAt,
          "#ally_reinforcements0" + j, allyReinfCount, allyReinfCount, allyPlane)
    }
    else
      enemyWpCount = 0

    enemySet = (enemyWpCount + enemyReinfCount) * planeCost
    allySet = allySet + (allyWpCount + allyReinfCount) / planeCost

    if (enemyWpCount > 0) {
      let res1 = (enemySet - allySet * 3 / 2)
      let res2 = (allySet - enemySet * 3 / 2)
      enemySet = (res1 - res2 / 2)
      allySet = (res2 - res1 / 2)
      if (enemySet < 0)
        enemySet = 0
      if (allySet < 0)
        allySet = 0
    }

    switch (j) {
      case 1: {
        enemyWp1Count = enemyWpCount
        allyWp1Count = allyWpCount
      }
      break
      case 2: {
        enemyWp2Count = enemyWpCount
        allyWp2Count = allyWpCount
      }
      break
      case 3: {
        enemyWp3Count = enemyWpCount
        allyWp3Count = allyWpCount
      }
      break
    }
  }

  let enemyTotalCount = enemyWp1Count + enemyWp2Count + enemyWp3Count
  let allyTotalCount = allyWp1Count + allyWp2Count + allyWp3Count + allyFromStartCount

  mgSetupArmada("#player.fighter", "waypoint00", Point3(0, 0, 0), "waypoint01", "", 4, 4, playerFighterPlane)
  mgSetupArmada("#player_cut.any", "waypoint00", Point3(0, 0, 0), "waypoint01", "", 4, 4, playerFighterPlane)
  gmMarkCutsceneArmadaLooksLike("#player_cut.any", "#player.fighter")

  let mission_mult = sqrt(enemyTotalCount / 15.0)

  mgSetMinMaxAircrafts("player", "", 1, 8)
  mgSetMinMaxAircrafts("ally", "fighter", 0, 44)
  mgSetMinMaxAircrafts("enemy", "fighter", 0, 44)

//mission warpoint cost calculate
  let missionWpCost = warpointCalculate(mission_preset_name, allyTotalCount, enemyTotalCount, planeCost,
    playerFighterPlane, mission_mult)
  mgSetInt("mission_settings/mission/wpAward", missionWpCost)

  mgSetEffShootingRate(0.5)

  if (playerFighterPlane == "" || enemyFighterPlane == "")
    return

  slidesReplace(mgGetLevelName(), mgGetMissionSector(), "air")

  //mgDebugDump("E:/dagor2/skyquake/develop/gameBase/gameData/missions/dynamic_campaign/objectives/testPatrol_temp.blk")
  if (mgFullLogs())
    debug_dump_stack()

  mgAcceptMission()
}

return {
  genCombatPatrolMission
}
