/*
   void mgBeginMission(const char * templateName)
   void mgAcceptMission()
   void mgDebugDump(const char * fileName)
   void mgSetStr(const char * path, const char * v)
   void mgSetInt(const char * path, int v)
   void mgSetReal(const char * path, float v)
   void mgSetBool(const char * path, bool v)
   void mgAddStr(const char * path, const char * v)
   void mgAddInt(const char * path, int v)
   void mgAddReal(const char * path, float v)
   void mgAddBool(const char * path, bool v)
   const char * mgGetStr(const char * path)
   int mgGetInt(const char * path)
   float mgGetReal(const char * path)
   bool mgGetBool(const char * path)
   void mgCopyBlockContent(const char * srcBlockName, const char * srcPath,
     const char * dstPath)

   srcBlockName = "", "layout"

   mgSetBool("variables/player_var", true);


   void mgCopyBlock(const char * srcBlockName, const char * srcPath, const char * dstPath,
     const char * dstName)

   int mgGetPlayerSide()
   int mgGetEnemySide()
   const char * mgCreateStartPoint(float altitude)
   const char * mgCreateStartLookAt()
   const char * mgCreateGroundUnits(int needSide,
     bool againstFighters, bool needCarriers, SquirrelObject outputSquads)

   {
     heavy_vehicles = ""
     light_vehicles = ""
     infantry = ""
     air_defence = ""
     anti_tank = ""
     bombtarget = ""
     ships = ""
     carriers = ""
   }

   Table mgGetCreatedUnitsCount()

   {
     heavy_vehicles,
     light_vehicles,
     infantry,
     air_defence,
     anti_tank,
     bombtarget,
     ships,
     carriers,
   }


   int mgGetUnitsCount(const char * armadaOrSquadName)

   int mgSetupArmada(const char * armadaName, const char * posName, const Point3 & offset,
                           const char * lookAtName, const char * squadName,
                           int minCount, int maxCount)

   void mgSetupArea(const char * areaName, const char * base, const char * lookAt,
     float angleDeg, float dist, float heightOffset)

   float rndRange(float minVal, float maxVal)

 static const char * getAnyBomber(int side)
 static const char * getAnyFighter(int side)
 static const char * getAnyAssault(int side)
 static float getDistancePerMinute(const char * aircraftName)

 static int getAircraftCost(const char * unitClass)
 dagor.debug_dump_stack()

   getAnyPlayerBomber();
   getAnyPlayerFighter();
   getAnyPlayerAssault();

static int mgReplace(const char * path, const char * paramName, const char * replaceWhat,
   const char * replaceTo)

 static bool mgSetupAirfield(const char * missionTarget, float acceptedRadius)

static void mgRemoveStrParam(const char * path, const char * v)

mgSetDistToAction(float)

bool mgGetMissionAccepted()

 static const char * getAircraftDescription(int side, const char * showType,
   SquirrelObject fmTagsList, SquirrelObject weaponTagsList, bool isPlayer, int warpointsMin, int warpointsMax)

 showType = ("bomber", "fighter", "assault", "any")
 fmTagsList = ( [], ["type_fighter"], ["type_fighter", "pacific"] )
 weaponTagsList = frontGun, cannon, bomb, rocket, heavyRocket, torpedo, antiShip, antiHeavyTanks

static void gmMarkCutsceneArmadaLooksLike(const char * cutsceneArmada,
   const char * looksLikeArmada)

mgSetInt("mission_settings/mission/wpAward", 1000);

 static float getPlaneWpDiv()
 static float getPlaneWpAdd()
 static int getMissionCost(const char *name)

 static void mgSetEffShootingRate(float effShootingRate)

 static const char * mgGetMissionSector()
 static const char * mgGetLevelName()

 static const char * mgUnitClassFromDescription(const char * description)

 mgEnsurePointsInMap(SquirrelObject pointsList) ["wp1", "wp2",..]

 ::is_existing_file("filename", false)

 if (shitHappens) dagor.fatal("text")

 // example: mgSetMinMaxAircrafts("ally", "fighter", 5, 15);
 // example: mgSetMinMaxAircrafts("ally", "assault", 5, 15);
 // example: mgSetMinMaxAircrafts("ally", "bomber", 5, 15);
 // example: mgSetMinMaxAircrafts("enemy", "any", 5, 15);
 // example: mgSetMinMaxAircrafts("player", "", 4, 4);
 // example: mgSetMinMaxAircrafts("ally", "fighter", 5, 15);
 // example: mgSetMinMaxAircrafts("player", "", 4, 4);
 //
 static void mgSetMinMaxAircrafts(const char * allyOrEnemy, const char * fightersOrBombers,
                                  int minCount, int maxCount);


*/

missionGenFunctions.append( function (isFreeFlight) // isFreeFlight = Mission Editor
{
  if (!isFreeFlight){return}
  local playerSide = ::mgGetPlayerSide();

  ::mgBeginMission("gameData/missions/dynamic_campaign/objectives/free_flight_preset02.blk");
  ::mgThisIsFreeFlight();
  local startPos = ::mgCreateStartPoint(1500);

  ::mgSetDistToAction(1000);
  ::mgSetupAirfield(startPos, 0);

  local startLookAt = ::mgCreateStartLookAt();
  local playerAnyPlane = ::getAircraftDescription(playerSide, "any", [], ["frontGun", "cannon", "bomb", "rocket", "torpedo", "antiShip", "antiHeavyTanks"], true, 0, 99999999);
  ::mgSetupArmada("#player.any", startPos, Point3(0, 0, 0), startLookAt, "", 4, 4, playerAnyPlane);

  ::mgSetInt("mission_settings/mission/wpAward", 0);

  ::mgSetMinMaxAircrafts("player", "", 1, 8);

  //mgDebugDump("E:/dagor2/skyquake/develop/gameBase/gameData/missions/dynamic_campaign/objectives/testFreeFlight_temp.blk");
 local sector = ::mgGetMissionSector();
 local level = ::mgGetLevelName();

 local player_plane_name = "";
 local enemy_plane_name = "";
 if (playerAnyPlane != "")
   player_plane_name = ::mgUnitClassFromDescription(playerAnyPlane);
 else
   return;

 ::slidesReplace(level, sector, player_plane_name, enemy_plane_name, "none");

  if (::mgFullLogs())
    dagor.debug_dump_stack();

  ::mgAcceptMission();
}
);
