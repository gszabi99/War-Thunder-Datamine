::missionGenFunctions <- [];

::getEnemyPlaneByWpCost <- function getEnemyPlaneByWpCost(playerPlaneCost, enemySide)
{
  let planeWpDiv = ::getPlaneWpDiv();
  let planeWpAdd = ::getPlaneWpAdd();

  local enemyFighterPlaneWpCostMin = playerPlaneCost*(planeWpDiv-1)*1.0/planeWpDiv-planeWpAdd;
  local enemyFighterPlaneWpCostMax = playerPlaneCost*(1+1.0/planeWpDiv)+planeWpAdd;

  local enemyFighterPlane = ::getAnyFighter(enemySide, enemyFighterPlaneWpCostMin, enemyFighterPlaneWpCostMax);
  local enemyPlaneCost = ::getAircraftCost(enemyFighterPlane);

  local i = 0;

  while (enemyPlaneCost >= enemyFighterPlaneWpCostMax && enemyPlaneCost <= enemyFighterPlaneWpCostMin && i < 3)
  {
    if (enemyFighterPlaneWpCostMin > 0)
    {
      enemyFighterPlaneWpCostMin = 2*enemyFighterPlaneWpCostMin-playerPlaneCost;
    }
    else
      enemyFighterPlaneWpCostMax = 2*enemyFighterPlaneWpCostMax-playerPlaneCost;

    enemyFighterPlane = ::getAnyFighter(enemySide, enemyFighterPlaneWpCostMin, enemyFighterPlaneWpCostMax);
    enemyPlaneCost = ::getAircraftCost(enemyFighterPlane);

    i++;
  }

  return enemyFighterPlane;
}


::planeCostCalculate <- function planeCostCalculate(playerPlaneCost, enemyPlaneCost)
{
  let planeWpDiv = ::getPlaneWpDiv();
  let planeWpAdd = ::getPlaneWpAdd();

  local planeCost = (enemyPlaneCost+planeWpAdd*planeWpDiv)*(enemyPlaneCost+planeWpAdd*planeWpDiv)*1.0/
                    ((playerPlaneCost+planeWpAdd*planeWpDiv)*(playerPlaneCost+planeWpAdd*planeWpDiv));
  if (planeCost > 4){planeCost = 4}
  if (planeCost < 0.25){planeCost = 0.25}

  return planeCost;
}

::warpointCalculate <- function warpointCalculate(mission_preset_name, allyCount, enemyCount, planeCost, playerPlane, mission_mult)
{
  if (enemyCount == 0 || planeCost == 0)
    return 0;

  let missionWpBasicCost = ::getMissionCost(mission_preset_name);
  local enemyAllyCoef = (enemyCount*1.0/(allyCount+4))*planeCost;
  if (enemyAllyCoef < 0.5)
    enemyAllyCoef = 0.5;
  if (enemyAllyCoef > 1.5)
    enemyAllyCoef = 1.5;

  local missionWpFighterCoef = ::sqrt(enemyAllyCoef*mission_mult);
  if (missionWpFighterCoef < 0.5)
    missionWpFighterCoef = 0.5;
  if (missionWpFighterCoef > 1.5)
    missionWpFighterCoef = 1.5;

  let zeroWpAddCoef = ::getZeroWpAddCoef();
  let repairCostMult = ::getRepairCostMult();
  local missionWpCost = 0;
  let playerPlaneCost = ::getAircraftCost(playerPlane);

  missionWpCost = (zeroWpAddCoef*missionWpFighterCoef+playerPlaneCost*repairCostMult)*missionWpBasicCost;

  if (missionWpCost > 99)
  {
    missionWpCost = missionWpCost/10;
    missionWpCost = missionWpCost.tointeger()*10;
  }
  if (missionWpCost < 0)
    missionWpCost = 0;

  if (::mgFullLogs())
    dagor.debug_dump_stack();

  return missionWpCost;
}

::slidesReplace <- function slidesReplace(level, sector, target_type)
{

  ::mgReplace("mission_settings/briefing", "picture", "dynamic_missions/berlin_02_01",
    "dynamic_missions/"+level+"_"+sector+"_0"+::rndRangeInt(1,3));

  local target_side = "";
  if (::mgGetPlayerSide() == 1)
  {
    target_side = "axis"
  }
  else
    target_side = "allies"

  if (target_type != "air")
    ::mgReplace("mission_settings/briefing", "picture", "dynamic_missions/mission_targets/ruhr_allies_tank",
      "dynamic_missions/mission_targets/"+level+"_"+target_side+"_"+target_type);

  return
}

::dagor.includeOnce("%scripts/dynamic/headtohead.nut");
::dagor.includeOnce("%scripts/dynamic/combat_patrol.nut");
::dagor.includeOnce("%scripts/dynamic/bombing.nut");
::dagor.includeOnce("%scripts/dynamic/freeflight.nut");
::dagor.includeOnce("%scripts/dynamic/waypointflight.nut");
::dagor.includeOnce("%scripts/dynamic/bombing_intercept.nut");
::dagor.includeOnce("%scripts/dynamic/cover_bombers.nut");
::dagor.includeOnce("%scripts/dynamic/bombing_defense.nut");
::dagor.includeOnce("%scripts/dynamic/assault_defense.nut");
::dagor.includeOnce("%scripts/dynamic/assault.nut");
::dagor.includeOnce("%scripts/dynamic/cover_assault.nut");

::currentMissionNo <- 0;

::beginMissionsGeneration <- function beginMissionsGeneration()
{
  ::currentMissionNo = 0;
}

::generateNextMission <- function generateNextMission(isFreeFlight) // isFreeFlight = Mission Editor
{
  if (::currentMissionNo < ::missionGenFunctions.len())
  {
    ::missionGenFunctions[::currentMissionNo](isFreeFlight);
    ::currentMissionNo++;
    return true;
  }
  return false;
}
