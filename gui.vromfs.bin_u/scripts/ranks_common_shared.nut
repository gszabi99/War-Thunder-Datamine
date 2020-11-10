local { blkFromPath } = require("sqStdLibs/helpers/datablockUtils.nut")
local format = require("string").format

::DS_UT_AIRCRAFT <- "Air"
::DS_UT_TANK <- "Tank"
::DS_UT_SHIP <- "Ship"
::DS_UT_INVALID <- "Invalid"

::ds_unit_type_names <- {
  [::ES_UNIT_TYPE_AIRCRAFT] = DS_UT_AIRCRAFT,
  [::ES_UNIT_TYPE_TANK] = DS_UT_TANK,
  [::ES_UNIT_TYPE_BOAT] = DS_UT_SHIP,
  [::ES_UNIT_TYPE_SHIP] = DS_UT_SHIP,
  [::ES_UNIT_TYPE_HELICOPTER] = DS_UT_AIRCRAFT
}

::mapWpUnitClassToWpUnitType <- {
  exp_bomber = DS_UT_AIRCRAFT
  exp_fighter = DS_UT_AIRCRAFT
  exp_assault = DS_UT_AIRCRAFT
  exp_tank = DS_UT_TANK
  exp_heavy_tank = DS_UT_TANK
  exp_tank_destroyer = DS_UT_TANK
  exp_SPAA = DS_UT_TANK
  exp_torpedo_boat = DS_UT_SHIP
  exp_gun_boat = DS_UT_SHIP
  exp_torpedo_gun_boat = DS_UT_SHIP
  exp_submarine_chaser = DS_UT_SHIP
  exp_destroyer = DS_UT_SHIP
  exp_cruiser = DS_UT_SHIP
  exp_naval_ferry_barge = DS_UT_SHIP
  exp_helicopter = DS_UT_AIRCRAFT
}

::dsClassToMatchingClass <-
{
  [DS_UT_AIRCRAFT] = "aircraft",
  [DS_UT_TANK] = "tank",
  [DS_UT_SHIP] = "ship"
}

global enum EDifficulties
{
  ARCADE = 0,
  REALISTIC = 1,
  HARDCORE = 2,
  TANK_ARCADE = 3,
  TANK_REALISTIC = 4,
  TANK_HARDCORE = 5,
  SHIP_ARCADE = 6,
  SHIP_REALISTIC = 7,
  SHIP_HARDCORE = 8,

  TOTAL = 9
}

global const EDIFF_SHIFT = 3

::EDifficultiesStr <- {
  [EDifficulties.ARCADE] = "Arcade",
  [EDifficulties.REALISTIC] = "Historical",
  [EDifficulties.HARDCORE] = "Simulation",
  [EDifficulties.TANK_ARCADE] = "TankArcade",
  [EDifficulties.TANK_REALISTIC] = "TankHistorical",
  [EDifficulties.TANK_HARDCORE] = "TankSimulation",
  [EDifficulties.SHIP_ARCADE] = "ShipArcade",
  [EDifficulties.SHIP_REALISTIC] = "ShipHistorical",
  [EDifficulties.SHIP_HARDCORE] = "ShipSimulation",
}

::EDifficultiesEconRankStr <- {
  [EDifficulties.ARCADE] = "Arcade",
  [EDifficulties.REALISTIC] = "Historical",
  [EDifficulties.HARDCORE] = "Simulation",
  [EDifficulties.TANK_ARCADE] = "Arcade",
  [EDifficulties.TANK_REALISTIC] = "Historical",
  [EDifficulties.TANK_HARDCORE] = "Simulation",
  [EDifficulties.SHIP_ARCADE] = "Arcade",
  [EDifficulties.SHIP_REALISTIC] = "Historical",
  [EDifficulties.SHIP_HARDCORE] = "Simulation",
}

::spawn_score_tbl <- {}

::CAN_USE_EDIFF <- false

::cur_mission_mode <- -1

::get_team_name_by_mp_team <- function get_team_name_by_mp_team(team)
{
  switch (team)
  {
  case ::MP_TEAM_A:
    return "teamA"
  case ::MP_TEAM_B:
    return "teamB"
  case ::MP_TEAM_NEUTRAL:
    return "teamNeutral"
  }
  return "unknown"
}

::get_mp_team_by_team_name <- function get_mp_team_by_team_name(teamName)
{
  switch (teamName)
  {
    case "teamA":
      return ::MP_TEAM_A
    case "teamB":
      return ::MP_TEAM_B
  }
  return ::MP_TEAM_NEUTRAL
}

::get_mission_mode <- function get_mission_mode()
{
  if (::cur_mission_mode >= 0)
    return ::cur_mission_mode
  local mission_name = ::get_selected_mission()
  local mission_mode = (mission_name && ::get_mission_type(mission_name)) || 0
  dagor.debug("get_mission_mode "+mission_name+" mission_mode "+mission_mode)
  ::cur_mission_mode = mission_mode
  return mission_mode
}

::get_emode_name <- function get_emode_name(ediff)
{
  return ::EDifficultiesStr[(ediff in ::EDifficultiesStr) ? ediff : EDifficulties.ARCADE]
}

::get_econRank_emode_name <- function get_econRank_emode_name(ediff)
{
  return ::EDifficultiesEconRankStr[(ediff in ::EDifficultiesEconRankStr) ? ediff : EDifficulties.ARCADE]
}

::clear_spawn_score <- function clear_spawn_score()
{
  ::spawn_score_tbl = {}
}

::getWpcostUnitClass <- function getWpcostUnitClass(unitId)
{
  local cost = ::get_wpcost_blk()
  return (unitId && unitId != "") ? (cost?[unitId]?.unitClass ?? "exp_zero") : "exp_zero"
}

::unitHasTag <- function unitHasTag(unitId, tag)
{
  return ::get_unittags_blk()?[unitId]?.tags?[tag] == true
}

::get_ds_ut_name_unit_type <- function get_ds_ut_name_unit_type(unitType)
{
  return ::ds_unit_type_names?[unitType] ?? DS_UT_INVALID
}

::get_unit_type_by_unit_name <- function get_unit_type_by_unit_name(unitId)
{
  return ::mapWpUnitClassToWpUnitType?[::getWpcostUnitClass(unitId)] ?? DS_UT_INVALID
}

::round <- function round(value, digits=0)
{
  local mul = ::pow(10, digits)
  return ::floor(0.5 + value.tofloat()*mul) / mul
}

::calc_battle_rating_from_rank <- function calc_battle_rating_from_rank(economicRank)
{
  return ::round(economicRank / 3.0 + 1, 1)
}

::get_battle_rating_string_from_rank <- function get_battle_rating_string_from_rank(economicRank)
{
  return ::format("%.1f", ::calc_battle_rating_from_rank(economicRank))
}

::get_unit_blk_economic_rank_by_mode <- function get_unit_blk_economic_rank_by_mode(unitBlk, ediff)
{
  local mode_name = ::get_econRank_emode_name(ediff)
  return unitBlk?["economicRank" + mode_name] ?? 0
}

::player_activity_coef <- function player_activity_coef(score, time)
{
  local mis = ::get_current_mission_info_cached()
  local ws = ::get_warpoints_blk()
  local mScoreBase = ws?.mScoreBase ?? 1.0
  local mScorePow = ws?.mScorePow ?? 0.0
  local standartMissionTime = ws?.standartMissionTime ?? 600.0
  local standartMissionTimePow = ws?.standartMissionTimePow ?? 1.0

  local customScoreMul = mis?.customScoreMul ?? 1.0
  local customScore = score * customScoreMul

  local scoreToTime = 0.0
  if (time > standartMissionTime)
    time = standartMissionTime + ::pow(time-standartMissionTime, standartMissionTimePow)

  if (time > 0.01)
    scoreToTime = ::pow(customScore.tofloat(), mScorePow)/time

  local activity_coef = (1.0 - ::pow(mScoreBase, scoreToTime))

  dagor.debug("player_activity_coef: "+activity_coef+" score "+score+" time "+time+" customScore "+customScore+" mScoreBase "+mScoreBase+ " scoreToTime "+scoreToTime+" mScorePow "+mScorePow+" customScoreMul "+customScoreMul)

  return ::round(activity_coef, 2);
}

::isUnitSpecial <- function isUnitSpecial(unit)
{
  return ("costGold" in unit && unit.costGold.tointeger() > 0) ||
         ("premPackAir" in unit && unit.premPackAir)
}

::get_unit_exp_conversion_mul <- function get_unit_exp_conversion_mul(unitName, resUnitName)
{
  local wpcost = ::get_wpcost_blk()

  local unit = wpcost?[unitName]
  local resUnit = wpcost?[resUnitName]
  local prevUnit = resUnit?.reqAir ? wpcost?[resUnit.reqAir] : null

  if (!unit || !resUnit)
    return 1.0

  local blk = ::get_ranks_blk()
  local unit_type = ::get_unit_type_by_unit_name(unitName)
  if (blk?[unit_type] == null)
  {
    dagor.debug("ERROR: ranks.blk is broken "+unit_type)
    return 0
  }

  local diff = get_mission_mode()
  local param_name = ""
  local expMul = 1.0
  if (prevUnit && resUnit.reqAir == unitName && unitName != null)
  {
    param_name = "prevAirExpMulMode"
    expMul *= blk.getReal(param_name+diff.tostring(), 0.0)
    dagor.debug("get_unit_exp_conversion_mul: with research child mul. ExpMul "+expMul+" prevUnit.name "+resUnit.reqAir+" unit.name "+unitName+" resUnitName "+resUnitName)
  }
  else
  {
    local unitEra = unit.rank
    local resUnitEra = resUnit.rank

    local eraDiff = resUnitEra - unitEra
    param_name = "expMulWithTierDiff"
    if (eraDiff < 0)
      if (::isUnitSpecial(unit))
      {
        eraDiff = 0
      }
      else
      {
        param_name += "Minus"
        eraDiff *= -1
      }
    expMul *= blk.getReal(param_name+eraDiff.tostring(), 0.0)
    dagor.debug("get_unit_exp_conversion_mul: with units era difference. ExpMul "+expMul)
  }

  return expMul
}

::calc_public_boost <- function calc_public_boost(bostersArray)
{
  local res = 0.0
  local k = [1.0, 0.6, 0.4, 0.2, 0.1]

  local count = bostersArray.len()
  local countOfK = k.len()
  for (local i = 0; i < count; i++)
  {
    if (i < countOfK)
      res = res + k[i] * bostersArray[i]
    else
    if (k[countOfK-1] * bostersArray[i] > 0.01)
      res = res + k[countOfK-1] * bostersArray[i]
    else
      res = res + 0.01
  }

  return res
}

::calc_personal_boost <- ::calc_public_boost

::get_spawn_score_param <- function get_spawn_score_param(paramName, defaultNum)
{
  local ws = ::get_warpoints_blk()
  local misBlk = ::get_current_mission_info_cached()
  local sessionMRank = misBlk?.ranks?.max ?? 0
  local modeName = get_emode_name(get_mission_mode())
  local overrideBlock = ws?.respawn_points?[modeName]?["override_params_by_session_rank"]
  local overrideBlockName = ""
  if (overrideBlock)
    foreach(name, block in overrideBlock)
      if((sessionMRank >= (block?.minMRank ?? -1)) && (sessionMRank <= (block?.maxMRank ?? -1)))
      {
        overrideBlockName = name
        break
      }

  return misBlk?.customSpawnScore?[paramName]
         ?? overrideBlock?[overrideBlockName]?[paramName]
         ?? overrideBlock?[overrideBlockName]?["respawn_cost_mul_by_exp_class"]?[paramName]
         ?? ws?.respawn_points?[modeName]?[paramName]
         ?? ws?.respawn_points?[modeName]?["respawn_cost_mul_by_exp_class"]?[paramName]
         ?? ws?.respawn_points?[paramName]
         ?? defaultNum
}

::get_unit_spawn_score_weapon_mul <- function get_unit_spawn_score_weapon_mul(unitname, weapon)
{
  local wpcost = ::get_wpcost_blk()

  local unitClass = wpcost?[unitname]?.unitClass
  if (unitClass == null)
    return 1.0

  if (unitClass == "exp_helicopter" && wpcost?[unitname]?.weapons?[weapon]?.isATGM)
    return get_spawn_score_param("spawnCostMulForHelicopterWithATGM", 1.0)

  if (unitClass == "exp_fighter" && wpcost?[unitname]?.weapons?[weapon]?.isAntiTankWeap)
    return get_spawn_score_param("spawnCostMulForFighterWithBombs", 1.0)

  return 1.0
}

// return non-empty string for errors
::validate_custom_mission_last_error <- ""

::validate_custom_mission <- function validate_custom_mission(misblk)
{
  ::validate_custom_mission_last_error = ""

  local err = function(str)
  {
    if (::validate_custom_mission_last_error != "")
      ::validate_custom_mission_last_error += "\n"
    ::validate_custom_mission_last_error += str;
  }

  local md = misblk?.mission_settings?.mission
  if (!dd_file_exist(md?.level ?? ""))
    err("Unknown location " + (md?.level ?? "null"))
  local levelBlk = (md?.level ?? "").slice(0, -3) + "blk"
  if (!dd_file_exist(levelBlk))
    err(levelBlk + " not found");

  //TODO: weather
  //TODO: timeofday

  local units_include = misblk?.mission_settings?.units_include
  if (units_include != null)
    for (local i = 0; i < units_include.blockCount(); i++)
    {
      local inc = units_include.getBlock(i);
      if (inc.filename != null)
      {
        if ((inc.filename == "") || (!dd_file_exist(inc.filename)))
          err("Wrong units include: "+inc.filename)
      }
    }


  local typeToPath = {
    armada = "gameData/flightModels",
    infantry = "gameData/units/infantry",
    tracked_vehicles = "gameData/units/tracked_vehicles",
    wheeled_vehicles = "gameData/units/wheeled_vehicles",
    structures = "gameData/units/structures",
    air_defence = "gameData/units/air_defence",
    ships = "gameData/units/ships",
    objectGroups = "gameData/objectGroups",
    tankModels = "gameData/units/tankModels"
  }

  if ("imports" in misblk && "import_record" in misblk.imports)
    err("import_record in imports not supported in user missions")

  local units = misblk?.units ?? ::DataBlock()
  for (local i = 0; i < units.blockCount(); i++)
  {
    local unit = units.getBlock(i);
    local unitType = unit.getBlockName();
    local unitClass = unit?.unit_class
    if (unitType in typeToPath)
    {
      local path = unitClass ? (typeToPath[unitType] + "/"+unitClass+".blk") : ""
      if (!dd_file_exist(path))
        err($"Unknown unit_class {unitClass} of unit {unit?.name}")
      else
      {
        local preset = unit?.weapons
        if (preset != null && preset != "")
        {
          local unitBlk = blkFromPath(path)
          if (unitBlk?.weapon_presets == null)
            err($"No weapon presets in {path}")
          else
          {
            local presets = unitBlk.weapon_presets % "preset"
            local found = false
            foreach (p in presets)
              if (p?.name == preset)
              {
                if (dd_file_exist(p?.blk ?? ""))
                {
                  found = true;
                  break;
                }
                else
                  err($"Not found: {p?.blk}")
              }
            if (!found)
              err($"Unknown weapon preset {preset} in unit {unit?.name}")
          }
        }
      }
      //TODO: weapon presets
    }
  }
  dagor.debug(::validate_custom_mission_last_error);
  return ::validate_custom_mission_last_error;
}

::cyber_cafe_boost<-
{
  level=[{wp = 0, xp = 0}, {wp = 0.0, xp = 0.05}, {wp = 0.0, xp = 0.1}, {wp = 0.1, xp = 0.1}]
  squad=[{wp = 0, xp = 0}, {wp = 0.0, xp = 0.0}, {wp = 0.0, xp = 0.1}, {wp = 0.05, xp = 0.1}, {wp = 0.05, xp = 0.1}]
  isValid = false
}
::cyber_cafe_max_level <- ::cyber_cafe_boost.level.len() - 1


cyber_cafe_boost.loadTables <- function loadTables()
{
  if (isValid)
    return

  local ws = ::get_warpoints_blk()

  local idx = 0
  foreach(param in level)
  {
    level[idx].wp = ws.getReal("cyberCafeLevelBoost"+idx.tostring()+"WP", param.wp)
    level[idx].xp = ws.getReal("cyberCafeLevelBoost"+idx.tostring()+"XP", param.xp)
    idx++
  }

  idx = 0
  foreach(param in squad)
  {
    squad[idx].wp = ws.getReal("cyberCafeSquadBoost"+idx.tostring()+"WP", param.wp)
    squad[idx].xp = ws.getReal("cyberCafeSquadBoost"+idx.tostring()+"XP", param.xp)
    idx++
  }

  isValid = true
}


::calc_boost_for_cyber_cafe <- function calc_boost_for_cyber_cafe(level)
{
  ::cyber_cafe_boost.loadTables()

  if (level > ::cyber_cafe_max_level)
    level = ::cyber_cafe_max_level

  return ::cyber_cafe_boost.level[level]
}


::calc_boost_for_squads_members_from_same_cyber_cafe <- function calc_boost_for_squads_members_from_same_cyber_cafe(numMembers)
{
  ::cyber_cafe_boost.loadTables()

  if (numMembers > 4)
    numMembers = 4

  return ::cyber_cafe_boost.squad[numMembers]
}


::get_classiness_mark_name <- function get_classiness_mark_name(egd_diff, stat_group, rank, squad_size)
{
  local diffStr = ::get_name_by_gamemode(egd_diff, false)
  return format("%s_%d_%d_%d", diffStr, stat_group, rank, squad_size)
}

::get_pve_trophy_name <- function get_pve_trophy_name(sessionTime, success)
{
  local mis = ::get_current_mission_info_cached()
  local ws = ::get_warpoints_blk()
  local pveTrophyName = mis.pveTrophyName

  if (pveTrophyName == null || typeof(pveTrophyName) != "string")
  {
    dagor.debug("get_pve_trophy_name. PVE Trophy for this mission is missing or not a string.")
    return null
  }

  if (success)
  {
    pveTrophyName += "_win"
  }
  else
  {
    local maxTrophyStage = ws.getInt("pveTrophyMaxStage", 0)
    local trophyStage = get_pve_time_award_stage(sessionTime)
    if (trophyStage > maxTrophyStage)
      trophyStage = maxTrophyStage
    if (trophyStage <= 0)
    {
      dagor.debug("get_pve_trophy_name. cannot generate trophy name for this amount of time in session: "+sessionTime)
      return null
    }
    pveTrophyName += "_stage_"+trophyStage
  }
  dagor.debug("get_pve_trophy_name. trophy name "+pveTrophyName+" success? "+success+" session time "+sessionTime)
  return pveTrophyName
}

::get_pve_time_award_stage <- function get_pve_time_award_stage(sessionTime)
{
  local ws = ::get_warpoints_blk()
  local timeAwardStep = ws.getInt("pveTimeAwardStep", 0)
  local timeAwardStage = 0

  if (timeAwardStep > 0)
  {
    timeAwardStage = ((sessionTime / 60) / timeAwardStep).tointeger()
  }
  dagor.debug("get_pve_time_award_stage stage "+timeAwardStage+" sessionTime "+sessionTime+" timeAwardStep "+timeAwardStep+" minutes")
  return timeAwardStage
}