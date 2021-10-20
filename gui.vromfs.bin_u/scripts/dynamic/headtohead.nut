missionGenFunctions.append( function (isFreeFlight)
{
  local mission_preset_name = "head_to_head_preset01";
  ::mgBeginMission("gameData/missions/dynamic_campaign/objectives/"+mission_preset_name+".blk");
  local playerSide = ::mgGetPlayerSide();
  local enemySide = ::mgGetEnemySide();
  local startPos = "";
  local ws = ::get_warpoints_blk()

  local groundUnitFake = 3//::rndRangeInt(3,6);
  if (groundUnitFake == 1)
  {
   startPos = ::mgCreateGroundUnits(playerSide,
         false, false,
       {
         heavy_vehicles = "#bomb_target_cover"
         light_vehicles = "#bomb_target_cover"
         infantry = "#bomb_target_cover"
         air_defence = "#bomb_target_cover"
         anti_tank = "#bomb_target_cover"
         bombtarget = "#bomb_target_cover"
         ships = "#bomb_target_cover"
         carriers = "#bomb_target_cover"
       }

       )
  } else
  if (groundUnitFake == 2)
    {
   startPos = ::mgCreateGroundUnits(enemySide,
         false, false,
       {
         heavy_vehicles = "#bomb_target_cover"
         light_vehicles = "#bomb_target_cover"
         infantry = "#bomb_target_cover"
         air_defence = "#bomb_target_cover"
         anti_tank = "#bomb_target_cover"
         bombtarget = "#bomb_target_cover"
         ships = "#bomb_target_cover"
         carriers = "#bomb_target_cover"
       }

       )
  } else startPos = ::mgCreateStartPoint(1500);

  if (groundUnitFake < 3 && ::mgGetUnitsCount("#bomb_target_cover") == 0)
  {
    startPos = ::mgCreateStartPoint(1500);
  }


  local allyStartAngle = ::rndRange(-30,30)

  local ally_enable = ::rndRangeInt(0, 40);
  local rndHeight = ::rndRange(0, 2000);
  local timeToFight = ::rndRange(30, 60)/60.0;

//planes cost calculate
  local wpMax = ws.dynPlanesMaxCost;
  local playerFighterPlane = ::getAnyPlayerFighter(0, wpMax);
  local playerPlaneCost = ::getAircraftCost(playerFighterPlane);
  if (playerPlaneCost == 0)
    playerPlaneCost = 250;

  local enemyFighterPlane = ::getEnemyPlaneByWpCost(playerPlaneCost, enemySide);
  local enemyPlaneCost = ::getAircraftCost(enemyFighterPlane);
  if (enemyPlaneCost == 0)
    enemyPlaneCost = 250;

  local planeCost = ::planeCostCalculate(playerPlaneCost, enemyPlaneCost);

  if (playerFighterPlane == "" || enemyFighterPlane == "")
    return;


  local playerSpeed = ::getDistancePerMinute(playerFighterPlane);
  local enemySpeed = ::getDistancePerMinute(enemyFighterPlane);

  ::mgSetDistToAction(playerSpeed*timeToFight+2000);
  ::mgSetupAirfield(startPos, playerSpeed*timeToFight+3000);
  local startLookAt = ::mgCreateStartLookAt();


  ::mgSetupArea("waypoint01", startPos, startLookAt, 180, 0, rndHeight);
  ::mgSetupArea("player_start", "waypoint01", startLookAt, allyStartAngle+180, playerSpeed*timeToFight, 0);
  ::mgSetupArea("enemy_start", "waypoint01", startLookAt, allyStartAngle, enemySpeed*timeToFight, 0);
  ::mgSetupArea("ally_start", "player_start", startLookAt, -10, 200, 0);
  ::mgSetupArea("evac", "waypoint01", "enemy_start", 0, 30000, 0);

  ::mgSetupArmada("#player.fighter", "player_start", Point3(0, 0, 0), "waypoint01", "", 4, 4, playerFighterPlane);
  ::mgSetupArmada("#player_cut.any", "player_start", Point3(0, 0, 0), "waypoint01", "", 4, 4, playerFighterPlane);
  ::gmMarkCutsceneArmadaLooksLike("#player_cut.any", "#player.fighter");




  local allyCountMax = 40*planeCost;
  local allyCount = 0;

  if (allyCountMax > 40) {allyCountMax = 40}

  if (ally_enable > 4 || planeCost > 1.3)
  {
    ::mgSetupArmada("#ally01.fighter", "ally_start", Point3(0, 0, 0),
                  "waypoint01", "ally_all", 4, allyCountMax, playerFighterPlane);
    ally_enable = 1;
    allyCount = ::mgGetUnitsCount("#ally01.fighter");
  }
  else
    ally_enable = 0;


  local enemy_count_min = (2+allyCount*ally_enable*0.5)/planeCost;
  local enemy_count_max = (6+allyCount*ally_enable*1.5)/planeCost;
  local enemyCount = ::rndRangeInt(enemy_count_min, enemy_count_max);
  if (enemyCount < 4){enemyCount = 4}
  if (enemyCount > 44){enemyCount = 44}

  ::mgSetupArmada("#enemy01.fighter", "enemy_start", Point3(0, 0, 0), "waypoint01",
                "enemy_all", enemyCount, enemyCount, enemyFighterPlane);
  ::mgSetupArmada("#enemy_cut.any", "waypoint01", Point3(0, 0, 0), "waypoint01", "", 4, 4, enemyFighterPlane);
  ::gmMarkCutsceneArmadaLooksLike("#enemy_cut.any", "#enemy01.fighter");


  ::mgSetMinMaxAircrafts("player", "", 1, 8);
  ::mgSetMinMaxAircrafts("ally", "fighter", 0, 40);
  ::mgSetMinMaxAircrafts("enemy", "fighter", 1, 44);

  local winCount = enemyCount/5.0;
  if (winCount < 2){winCount = 2}

  local mission_mult = ::sqrt(winCount/4.0+0.05);

  local missionWpCost = warpointCalculate(mission_preset_name, allyCount, enemyCount, planeCost, playerFighterPlane, mission_mult);
  ::mgSetInt("mission_settings/mission/wpAward", missionWpCost);
//  mgDebugDump("E:/dagor2/skyquake/develop/gameBase/gameData/missions/dynamic_campaign/objectives/test_temp.blk");
  ::mgSetEffShootingRate(0.1);

 local sector = ::mgGetMissionSector();
 local level = ::mgGetLevelName();

 local player_plane_name = "";
 local enemy_plane_name = "";
 if (playerFighterPlane != "" && enemyFighterPlane != "")
 {
   player_plane_name = ::mgUnitClassFromDescription(playerFighterPlane);
   enemy_plane_name = ::mgUnitClassFromDescription(enemyFighterPlane);
 }
 else
   return;

 ::slidesReplace(level, sector, player_plane_name, enemy_plane_name, "air");

  if (::mgFullLogs())
    dagor.debug_dump_stack();

  ::mgAcceptMission();
}
);
