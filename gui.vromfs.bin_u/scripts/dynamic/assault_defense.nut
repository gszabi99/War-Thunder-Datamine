::_generateAssaultDefMission <- function _generateAssaultDefMission(isFreeFlight, createGroundUnitsProc)
{
  local mission_preset_name = "ground_defense_preset02";
  ::mgBeginMission("gameData/missions/dynamic_campaign/objectives/"+mission_preset_name+".blk");
  local playerSide = ::mgGetPlayerSide();
  local enemySide = ::mgGetEnemySide();
  local bombtargets = createGroundUnitsProc(playerSide);


  local enemy1Angle = ::rndRange(-45, 45);
  local enemy2Angle = ::rndRange(-45, 45);
  local evacAngle = ::rndRange(-10, 10);

  local enemyAssaultPlane = "";

//planes cost calculate
  local wpMax = 1000000;
  local playerFighterPlane = ::getAnyPlayerFighter(0, wpMax);
  local playerPlaneCost = ::getAircraftCost(playerFighterPlane);
  if (playerPlaneCost == 0)
    playerPlaneCost = 250;

  local enemyFighterPlane = ::getEnemyPlaneByWpCost(playerPlaneCost, enemySide);
  local enemyPlaneCost = ::getAircraftCost(enemyFighterPlane);
  if (enemyPlaneCost == 0){enemyPlaneCost = 250}

  local planeCost = ::planeCostCalculate(playerPlaneCost, enemyPlaneCost);



  local bombersCount = 0;
  local countToFail = 1;

  local ground_type = "";
  local squad_type = "";
  local mission_name = "";
  local indicator_icon = "";
  local tanks_count = ::mgGetUnitsCount("#bomb_targets_tanks");
  local light_count = ::mgGetUnitsCount("#bomb_targets_light");
  local art_count = ::mgGetUnitsCount("#bomb_targets_art");
  local ships_count = ::mgGetUnitsCount("#bomb_targets_ships");

//mission type and bombers count setup
  if ( tanks_count > 0 && tanks_count > light_count && tanks_count > art_count)
  {
    bombersCount = ::rndRangeInt(tanks_count*3, tanks_count*6);
    ground_type = "tank";
    squad_type = "#bomb_targets_tanks";
    enemyAssaultPlane = ::getAircraftDescription(enemySide, "assault", ["can_be_assault"],
                                                  ["antiTankBomb", "antiTankRocket"], false, 0, wpMax);
    mission_name = "dynamic_defense_ga_tank";
    indicator_icon = "tank";
    countToFail = tanks_count/2;
  }
  else if (light_count > 0 && light_count > art_count)
  {
    bombersCount = ::rndRangeInt(light_count*2, light_count*4);
    ground_type = "truck";
    squad_type = "#bomb_targets_light";
    enemyAssaultPlane = ::getAircraftDescription(enemySide, "assault", ["can_be_assault"],
                                               ["rocket", "bomb", "cannon"], false, 0, wpMax);
    mission_name = "dynamic_defense_ga_vehicles";
    indicator_icon = "truck";
    countToFail = light_count/2;
  }
  else if (art_count > 0)
  {
    bombersCount = ::rndRangeInt(art_count*2, art_count*4);
    ground_type = "artillery";
    squad_type = "#bomb_targets_art";
    enemyAssaultPlane = ::getAircraftDescription(enemySide, "assault", ["can_be_assault"],
                                              ["rocket", "bomb", "cannon"], false, 0, wpMax);
    mission_name = "dynamic_defense_ga_anti_tank";
    indicator_icon = "cannon";
    countToFail = art_count/2;
  }
  else if (ships_count > 0)
  {
    bombersCount = ::rndRangeInt(ships_count*4, ships_count*8);
    ground_type = "destroyer";
    squad_type = "#bomb_targets_ships";
    enemyAssaultPlane = ::getAircraftDescription(enemySide, "assault", ["can_be_assault"],
                                            ["antiShipBomb", "antiShipRocket"], false, 0, wpMax);
    mission_name = "dynamic_defense_ga_ships";
    indicator_icon = "ship";
    countToFail = ships_count/2;
  }
  else
    return;

  if (playerFighterPlane == "" || enemyFighterPlane == "" || enemyAssaultPlane == "")
    return;

  if (countToFail < 1)
    countToFail = 1;

  ::mgReplace("mission_settings/briefing/part", "icontype", "carrier", ground_type);
  ::mgReplace("mission_settings/briefing/part", "point", "#bomb_targets", squad_type);
  ::mgReplace("mission_settings/briefing/part", "target", "#bomb_targets", squad_type);
  ::mgReplace("triggers", "object", "#bomb_targets", squad_type);
  ::mgReplace("triggers", "target", "#bomb_targets", squad_type);
  ::mgSetStr("mission_settings/mission/name", mission_name);
  ::mgReplace("triggers", "icon", "air", indicator_icon);
  ::mgSetInt("variables/count_to_fail", countToFail);

  if (indicator_icon != "ship")
  {
    ::mgReplace("mission_settings/briefing/part", "target", "target_waypoint_bombers", squad_type);
    ::mgReplace("mission_settings/briefing/part", "lookAt", "target_waypoint_bombers", squad_type);
  }

  if (bombersCount < 8)
    bombersCount = 8;
  if (bombersCount > 24)
    bombersCount = 24;


//enemy waves and fighter count calculate
  local enemyWaveCount = 0;
  if (bombersCount < 13)
    enemyWaveCount = 1;
  else if (bombersCount < 20)
    enemyWaveCount = ::rndRangeInt(1,2);
  else
    enemyWaveCount = 2;
  ::mgSetInt("variables/wave_max", enemyWaveCount);

  local enemy1BombersCount = bombersCount/enemyWaveCount;
  if (enemyWaveCount > 1)
    enemy1BombersCount = enemy1BombersCount*::rndRange(0.75,1.25);
  if (enemy1BombersCount < 4)
    enemy1BombersCount = 4;
  local enemy2BombersCount = bombersCount - enemy1BombersCount;
  if (enemy2BombersCount < 4  && enemyWaveCount > 1)
    enemy2BombersCount = 4;

  local enemy1FighersCount = enemy1BombersCount*::rndRange(0.75, 1)/1.2;
  local enemy2FighersCount = enemy2BombersCount*::rndRange(0.75, 1)/1.2;
  local enemyFightersCount = enemy1FighersCount + enemy2FighersCount;
  if (enemyFightersCount > 20)
    enemyFightersCount = 20;

  local allyFighterCountMin = (bombersCount*0.5+enemyFightersCount)*0.5*planeCost-4;
  local allyFighterCountMax = (bombersCount+enemyFightersCount)*planeCost-4;

  local allyFighterCount = ::rndRangeInt(allyFighterCountMin, allyFighterCountMax);
  if (allyFighterCount < 4)
    allyFighterCount = 0;
  if (allyFighterCount > 40)
    allyFighterCount = 40;

//battle distance calculate
  local rndHeight = ::rndRange(1500, 3000);
  local enemySpeed = ::getDistancePerMinute(enemyAssaultPlane);


  local timeToEnemy1 = ::rndRange(60, 120)/60.0;
  local timeToEnemy2 = ::rndRange(120, 150)/60.0;

  ::mgSetDistToAction(-enemySpeed*timeToEnemy2);
  ::mgSetupAirfield(bombtargets, 6000);
  local startLookAt = ::mgCreateStartLookAt();

  ::mgSetInt("variables/timeTo_enemy2", timeToEnemy1*60+::rndRangeInt(120, 240));
  ::mgSetReal("variables/enemy1_onRadar", enemySpeed*timeToEnemy1*0.75);
  ::mgSetReal("variables/enemy2_onRadar", enemySpeed*(timeToEnemy2-timeToEnemy1*0.75));


//points placing
  ::mgSetupArea("player_start", bombtargets, startLookAt, 180, ::rndRange(4500, 6000), rndHeight+500);
  ::mgSetupArea("target_waypoint_bombers", bombtargets, "", 0, 0, rndHeight);
  ::mgSetupArea("target_waypoint_fighters", bombtargets, "", 0, 0, rndHeight+500);

  ::mgSetupArea("evac", bombtargets, startLookAt, evacAngle, 60000, rndHeight);
  ::mgSetupArea("evac_forCut", bombtargets, startLookAt, 0, 2000, rndHeight);

  ::mgSetupArea("enemy1_start", bombtargets, startLookAt, enemy1Angle,
              enemySpeed*timeToEnemy1, rndHeight);

  ::mgSetupArea("enemy2_start", bombtargets, startLookAt, enemy2Angle,
              enemySpeed*timeToEnemy2, rndHeight);


//armada setup
  ::mgSetupArmada("#player.fighter", "player_start", Point3(0, 0, 0), bombtargets, "", 4, 4, playerFighterPlane);
  ::mgSetupArmada("#player_cut.any", "player_start", Point3(0, 0, 0), bombtargets, "", 4, 4, playerFighterPlane);
  ::gmMarkCutsceneArmadaLooksLike("#player_cut.any", "#player.fighter");

  ::mgSetupArmada("#enemy03.assault", "enemy1_start", Point3(0, 0, 0), bombtargets,
                "#enemy_assault_group01", enemy1BombersCount, enemy1BombersCount, enemyAssaultPlane);
  ::mgSetupArmada("#enemy01.fighter", "enemy1_start", Point3(-200, 500, 0), bombtargets,
                "#enemy_fighter_group01", enemy1FighersCount, enemy1FighersCount, enemyFighterPlane);
  if (enemyWaveCount > 1)
  {
    ::mgSetupArmada("#enemy04.assault", "enemy2_start", Point3(0, 0, 0), bombtargets,
                  "#enemy_assault_group02", enemy2BombersCount, enemy2BombersCount, enemyAssaultPlane);
    ::mgSetupArmada("#enemy02.fighter", "enemy2_start", Point3(-200, 500, 0), bombtargets,
                  "#enemy_fighter_group02", enemy2FighersCount, enemy2FighersCount, enemyFighterPlane);
  }

  if (allyFighterCount != 0)
    ::mgSetupArmada("#ally01.fighter", "#player.fighter", Point3(-500, 500, 0), bombtargets,
                  "#ally_fighters_group", allyFighterCount, allyFighterCount, playerFighterPlane);

  ::mgSetMinMaxAircrafts("player", "", 1, 8);
  ::mgSetMinMaxAircrafts("ally", "fighter", 0, 40);
  ::mgSetMinMaxAircrafts("enemy", "fighter", 0, 24);
  ::mgSetMinMaxAircrafts("enemy", "assault", 8, 24);

//mission warpoint cost calculate
  local mission_mult = ::sqrt(bombersCount/11.0+0.05);
  local missionWpCost = warpointCalculate(mission_preset_name, allyFighterCount, enemyFightersCount+bombersCount*0.5, planeCost,
                                          playerFighterPlane, mission_mult);
  ::mgSetInt("mission_settings/mission/wpAward", missionWpCost);

  ::mgSetEffShootingRate(0.1);

  if (playerFighterPlane == "")
    return

  ::slidesReplace(::mgGetLevelName(), ::mgGetMissionSector(), ground_type)

  ::mgSetBool("variables/training_mode", isFreeFlight);

  //mgDebugDump("E:/dagor2/skyquake/develop/gameBase/gameData/missions/dynamic_campaign/objectives/testAssaultdef_temp.blk");
  if (::mgFullLogs())
    dagor.debug_dump_stack();

  ::mgAcceptMission();


}


missionGenFunctions.append( function(isFreeFlight)
{
     _generateAssaultDefMission (isFreeFlight, function(playerSide)
       {
         return ::mgCreateGroundUnits(playerSide,
           false, false,
         {
           heavy_vehicles = "#bomb_targets_tanks"
           light_vehicles = "#bomb_targets_light"
           infantry = "#bomb_target_cover"
           air_defence = "#bomb_target_cover"
           anti_tank = "#bomb_targets_art"
           bombtarget = "*"
           ships = "#bomb_targets_ships"
           carriers = "#bomb_target_cover"
         }

         )
       }
     );
}
);
