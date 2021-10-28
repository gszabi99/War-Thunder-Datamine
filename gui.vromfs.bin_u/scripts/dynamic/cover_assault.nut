::_generateCoverGattackMission <- function _generateCoverGattackMission(isFreeFlight, createGroundUnitsProc)
{
  local mission_preset_name = "cover_gattack_preset01";
  ::mgBeginMission("gameData/missions/dynamic_campaign/objectives/"+mission_preset_name+".blk");
  local playerSide = ::mgGetPlayerSide();
  local enemySide = ::mgGetEnemySide();
  local bombtargets = createGroundUnitsProc(enemySide);

  local enemy1Angle = ::rndRange(-90, 90);
  local evacAngle = ::rndRange(-10, 10);
  local bombersCount = 0;
  local ground_type = "";
  local squad_type = "";
  local tanks_count = ::mgGetUnitsCount("#bomb_targets_tanks");
  local light_count = ::mgGetUnitsCount("#bomb_targets_light");
  local art_count = ::mgGetUnitsCount("#bomb_targets_art");
  local ships_count = ::mgGetUnitsCount("#bomb_targets_ships");

  local allyAssaultPlane = "";

//planes cost and warpoint ratio calculate
  local ws = ::get_warpoints_blk();
  local wpMax = ws.dynPlanesMaxCost;
  local playerFighterPlane = ::getAnyPlayerFighter(0, wpMax);
  local playerPlaneCost = ::getAircraftCost(playerFighterPlane);
  if (playerPlaneCost == 0){playerPlaneCost = 250}

  local enemyFighterPlane = ::getEnemyPlaneByWpCost(playerPlaneCost, enemySide);
  local enemyPlaneCost = ::getAircraftCost(enemyFighterPlane);
  if (enemyPlaneCost == 0){enemyPlaneCost = 250}

  local planeCost = ::planeCostCalculate(playerPlaneCost, enemyPlaneCost);


//mission type and bombers count setup
  if ( tanks_count > 0 && tanks_count > light_count && tanks_count > art_count)
  {
    bombersCount = ::rndRangeInt(tanks_count*3, tanks_count*6);
    ground_type = "tank";
    squad_type = "#bomb_targets_tanks";
    allyAssaultPlane = ::getAircraftDescription(playerSide, "assault", ["can_be_assault"],
                                              ["antiTankBomb", "antiTankRocket"], false, 0, wpMax);
    ::mgSetInt("variables/assault_time", 60);
  }
  else if (light_count > 0 && light_count > art_count)
  {
    bombersCount = ::rndRangeInt(light_count*2, light_count*4);
    ground_type = "truck";
    squad_type = "#bomb_targets_light";
    allyAssaultPlane = ::getAircraftDescription(playerSide, "assault", ["can_be_assault"],
                                              ["rocket", "bomb", "cannon"], false, 0, wpMax);
    ::mgSetInt("variables/assault_time", 120);
  }
  else if (art_count > 0)
  {
    bombersCount = ::rndRangeInt(art_count*2, art_count*4);
    ground_type = "artillery";
    squad_type = "#bomb_targets_art";
    allyAssaultPlane = ::getAircraftDescription(playerSide, "assault", ["can_be_assault"],
                                              ["rocket", "bomb", "cannon"], false, 0, wpMax);
    ::mgSetInt("variables/assault_time", 120);
  }
  else if (ships_count > 0)
  {
    bombersCount = ::rndRangeInt(ships_count*4, ships_count*8);
    ground_type = "destroyer";
    squad_type = "#bomb_targets_ships";
    allyAssaultPlane = ::getAircraftDescription(playerSide, "assault", ["can_be_assault"],
                                              ["antiShipBomb", "antiShipRocket"], false, 0, wpMax);
    ::mgSetInt("variables/assault_time", 60);
  }
  else
    return;

  if (playerFighterPlane == "" || enemyFighterPlane == "" || allyAssaultPlane == "")
    return;

  ::mgReplace("mission_settings/briefing/part", "icontype", "tank", ground_type);
  ::mgReplace("mission_settings/briefing/part", "point", "#bomb_targets", squad_type);
  ::mgReplace("mission_settings/briefing/part", "target", "#bomb_targets", squad_type);
  ::mgReplace("triggers", "object", "#bomb_targets", squad_type);
  ::mgReplace("triggers", "target", "#bomb_targets", squad_type);

  if (ground_type != "destroyer")
  {
    ::mgReplace("mission_settings/briefing/part", "target", "target_waypoint_bombers", squad_type);
    ::mgReplace("mission_settings/briefing/part", "lookAt", "target_waypoint_bombers", squad_type);
    ::mgReplace("mission_settings/briefing/part", "point", "target_waypoint_bombers", squad_type);
  }

  if (bombersCount < 8)
    bombersCount = 8;
  if (bombersCount > 24)
    bombersCount = 24;

//ally and enemy fighters calculate
  local allyFighterCountMin = (bombersCount*0.5)/1.5*planeCost-4;
  local allyFighterCountMax = (bombersCount)/1.5*planeCost-4;
  local allyFightersCount = ::rndRangeInt(allyFighterCountMin, allyFighterCountMax)
  if (allyFightersCount < 4)
    allyFightersCount = 0;
  if (allyFightersCount > 16)
    allyFightersCount = 16;

  local enemyTotalCountMin = (bombersCount*0.5+allyFightersCount+4)*0.5/planeCost;
  local enemyTotalCountMax = (bombersCount+allyFightersCount+4)/planeCost;
  local enemyTotalCount = ::rndRangeInt(enemyTotalCountMin, enemyTotalCountMax);
  if (enemyTotalCount < 8)
    enemyTotalCount = 8;
  if (enemyTotalCount > 44)
    enemyTotalCount = 44;

  local enemy1Count = ::rndRangeInt(enemyTotalCount/2*0.75, enemyTotalCount/2*1.25);
  enemy1Count = ::rndRangeInt(enemyTotalCount/2*0.75, enemyTotalCount/2*1.25);
  if (enemy1Count < 4)
    enemy1Count = 4;
  if (enemy1Count > (enemyTotalCount-4))
    enemy1Count = enemyTotalCount-4;
  local enemy2Count = enemyTotalCount-enemy1Count;


//battle distance calculate
  local rndHeight = ::rndRange(2000, 4000);
  local allySpeed = ::getDistancePerMinute(allyAssaultPlane);
  local enemySpeed = ::getDistancePerMinute(enemyFighterPlane);


  local timeToTarget = ::rndRange(90, 150)/60.0;
  local timeToEnemy1 = ::rndRange(30, timeToTarget*60/3.0)/60.0;

  ::mgSetDistToAction(allySpeed*timeToTarget+2000);
  ::mgSetupAirfield(bombtargets, allySpeed*timeToTarget+3000);
  local startLookAt = ::mgCreateStartLookAt();


//points setup
  ::mgSetupArea("player_start", bombtargets, startLookAt, 180, allySpeed*timeToTarget, rndHeight);
  ::mgSetupArea("ally_assault_start", bombtargets, startLookAt, 180, allySpeed*timeToTarget-300, rndHeight-100);
  ::mgSetupArea("ally_fighter_start", bombtargets, startLookAt, 180, allySpeed*timeToTarget+200, rndHeight);
  ::mgSetupArea("target_waypoint_bombers", bombtargets, "", 0, 0, rndHeight-100);
  ::mgSetupArea("target_waypoint_fighters", bombtargets, "", 0, 0, rndHeight);
  ::mgSetupArea("evac", bombtargets, "player_start", evacAngle, allySpeed*timeToTarget/2.0, rndHeight);
  ::mgSetupArea("evac_forCut", "evac", bombtargets, 0, 2000, 0);
  ::mgSetupArea("ally_evac", bombtargets, "player_start", evacAngle, 90000, 1000);
  ::mgSetupArea("enemy_evac", bombtargets, "player_start", 45, 90000, 1000);

  ::mgSetupArea("enemy1_pointToFight", "player_start", bombtargets, 0,
              allySpeed*timeToEnemy1, rndHeight+::rndRange(0,500));
  ::mgSetupArea("enemy1_start", "enemy1_pointToFight", bombtargets, enemy1Angle,
              enemySpeed*timeToEnemy1, 0);

  ::mgSetupArea("enemy2_start", bombtargets, "player_start", 180,
              3000, rndHeight+500);

//armada setup
  ::mgSetupArmada("#player.fighter", "player_start", Point3(0, 0, 0), bombtargets, "", 4, 4, playerFighterPlane);
  ::mgSetupArmada("#player_cut.any", "player_start", Point3(0, 0, 0), bombtargets, "", 4, 4, playerFighterPlane);
  ::gmMarkCutsceneArmadaLooksLike("#player_cut.any", "#player.fighter");

  ::mgSetupArmada("#ally01.assault", "ally_assault_start", Point3(0, 0, 0), bombtargets,
                "#ally_assault_group", bombersCount, bombersCount, allyAssaultPlane);

  if (allyFightersCount != 0)
    ::mgSetupArmada("#ally02.fighter", "ally_fighter_start", Point3(0, 0, 0), bombtargets,
                  "#ally_fighters_group", allyFightersCount, allyFightersCount, playerFighterPlane);

  ::mgSetupArmada("#enemy01.fighter", "enemy1_start", Point3(0, 0, 0), "#player.fighter",
                "#enemy_group01", enemy1Count, enemy1Count, enemyFighterPlane);

  ::mgSetupArmada("#enemy02.fighter", "enemy2_start", Point3(0, 0, 0), "#player.fighter",
                "#enemy_group01", enemy2Count, enemy2Count, enemyFighterPlane);

  ::mgSetMinMaxAircrafts("player", "", 1, 8);
  ::mgSetMinMaxAircrafts("ally", "fighter", 0, 16);
  ::mgSetMinMaxAircrafts("ally", "bomber", 8, 24);
  ::mgSetMinMaxAircrafts("enemy", "fighter", 0, 44);

//mission warpoint cost calculate
  local mission_mult = ::sqrt(enemyTotalCount/20.0+0.05);
  local missionWpCost = warpointCalculate(mission_preset_name, allyFightersCount+bombersCount*0.5, enemyTotalCount, planeCost,
                                          playerFighterPlane, mission_mult);
  ::mgSetInt("mission_settings/mission/wpAward", missionWpCost);

  ::mgSetEffShootingRate(0.1);

  if (playerFighterPlane == "" || allyAssaultPlane == "")
    return

  ::slidesReplace(::mgGetLevelName(), ::mgGetMissionSector(), "air")

  ::mgSetBool("variables/training_mode", isFreeFlight);
 // mgDebugDump("E:/dagor2/skyquake/develop/gameBase/gameData/missions/dynamic_campaign/objectives/testAssaultCover_temp.blk");
  if (::mgFullLogs())
    dagor.debug_dump_stack();

  ::mgAcceptMission();
}

missionGenFunctions.append( function(isFreeFlight)
{
_generateCoverGattackMission (isFreeFlight, function(nemySide)
      {
       return ::mgCreateGroundUnits(nemySide,
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
)

}
);
