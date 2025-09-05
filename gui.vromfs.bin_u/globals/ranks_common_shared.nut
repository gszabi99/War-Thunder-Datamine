

let DataBlock = require("DataBlock")
let { file_exists } = require("dagor.fs")
let math = require("math")
let { blkFromPath } = require("%sqstd/datablock.nut")
let { interpolateArray, round_by_value } = require("%sqstd/math.nut")
let { get_selected_mission, get_mission_type,
  get_unit_spawn_type, get_user_custom_state } = require("mission")
let { get_current_mission_info_cached, get_wpcost_blk,
  get_warpoints_blk, get_unittags_blk  } = require("blkGetters")

let log = @(...) print(" ".join(vargv))

const DS_UT_AIRCRAFT = "Air"
const DS_UT_TANK = "Tank"
const DS_UT_SHIP = "Ship"
const DS_UT_HUMAN = "Human"
const DS_UT_INVALID = "Invalid"

let ds_unit_type_names = {
  [ES_UNIT_TYPE_AIRCRAFT] = DS_UT_AIRCRAFT,
  [ES_UNIT_TYPE_TANK] = DS_UT_TANK,
  [ES_UNIT_TYPE_BOAT] = DS_UT_SHIP,
  [ES_UNIT_TYPE_SHIP] = DS_UT_SHIP,
  [ES_UNIT_TYPE_HELICOPTER] = DS_UT_AIRCRAFT,
  [ES_UNIT_TYPE_HUMAN] = DS_UT_HUMAN
}

let mapWpUnitClassToWpUnitType = {
  exp_bomber = DS_UT_AIRCRAFT
  exp_fighter = DS_UT_AIRCRAFT
  exp_assault = DS_UT_AIRCRAFT
  exp_tank = DS_UT_TANK
  exp_heavy_tank = DS_UT_TANK
  exp_tank_destroyer = DS_UT_TANK
  exp_SPAA = DS_UT_TANK
  exp_ai_sam_tracking_radar = DS_UT_TANK
  exp_torpedo_boat = DS_UT_SHIP
  exp_gun_boat = DS_UT_SHIP
  exp_torpedo_gun_boat = DS_UT_SHIP
  exp_submarine_chaser = DS_UT_SHIP
  exp_destroyer = DS_UT_SHIP
  exp_cruiser = DS_UT_SHIP
  exp_naval_ferry_barge = DS_UT_SHIP
  exp_helicopter = DS_UT_AIRCRAFT
  exp_human = DS_UT_HUMAN
}

enum EDifficulties {
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

const EDIFF_SHIFT = 3

let EDifficultiesStr = {
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

let EDifficultiesEconRankStr = {
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

local cur_mission_mode = -1
let reset_cur_mission_mode = @() cur_mission_mode = -1

function get_team_name_by_mp_team(team) {
  if (team == MP_TEAM_A)
    return "teamA"
  if (team == MP_TEAM_B)
    return "teamB"
  if (team == MP_TEAM_NEUTRAL)
    return "teamNeutral"
  return "unknown"
}

function get_mp_team_by_team_name(teamName) {
  if (teamName == "teamA")
    return MP_TEAM_A
  if (teamName == "teamB")
    return MP_TEAM_B
  return MP_TEAM_NEUTRAL
}

function get_mission_mode() {
  if (cur_mission_mode >= 0)
    return cur_mission_mode
  let mission_name = get_selected_mission()
  let mission_mode = mission_name != null ? get_mission_type(mission_name) : 0
  log($"get_mission_mode {mission_name} mission_mode {mission_mode}")
  cur_mission_mode = mission_mode
  return mission_mode
}

function get_emode_name(ediff) {
  return EDifficultiesStr[(ediff in EDifficultiesStr) ? ediff : EDifficulties.ARCADE]
}

function get_econRank_emode_name(ediff) {
  return EDifficultiesEconRankStr[(ediff in EDifficultiesEconRankStr) ? ediff : EDifficulties.ARCADE]
}

function getWpcostUnitClass(unitId) {
  let cost = get_wpcost_blk()
  return (unitId && unitId != "") ? (cost?[unitId]?.unitClass ?? "exp_zero") : "exp_zero"
}

function unitHasTag(unitId, tag) {
  return get_unittags_blk()?[unitId]?.tags?[tag] == true
}

function get_ds_ut_name_unit_type(unitType) {
  return ds_unit_type_names?[unitType] ?? DS_UT_INVALID
}

function get_unit_type_by_unit_name(unitId) {
  return mapWpUnitClassToWpUnitType?[getWpcostUnitClass(unitId)] ?? DS_UT_INVALID
}

function get_unit_blk_economic_rank_by_mode(unitBlk, ediff) {
  let modeName = get_emode_name(ediff)
  let diffName = get_econRank_emode_name(ediff)
  return unitBlk?[$"economicRank{modeName}"] ?? unitBlk?[$"economicRank{diffName}"] ?? 0
}

function isUnitSpecial(unit) {
  return ("costGold" in unit && unit.costGold.tointeger() > 0) ||
         ("premPackAir" in unit && unit.premPackAir)
}

function calc_public_boost(bostersArray) {
  local res = 0.0
  let k = [1.0, 0.6, 0.4, 0.2, 0.1]

  let count = bostersArray.len()
  let countOfK = k.len()
  for (local i = 0; i < count; i++) {
    if (i < countOfK)
      res = res + k[i] * bostersArray[i]
    else if (k[countOfK - 1] * bostersArray[i] > 1.0)
      res = res + k[countOfK - 1] * bostersArray[i]
    else
      res = res + 1.0
  }
  res = round_by_value(res, 1.0) 
  return res
}

function get_spawn_score_param(paramName, defaultNum) {
  let ws = get_warpoints_blk()
  let misBlk = get_current_mission_info_cached()
  let sessionMRank = misBlk?.ranks.max ?? 0
  let modeName = get_emode_name(get_mission_mode())
  let overrideBlock = ws?.respawn_points?[modeName]?["override_params_by_session_rank"]
  local overrideBlockName = ""
  if (overrideBlock)
    foreach (name, block in overrideBlock)
      if ((sessionMRank >= (block?.minMRank ?? -1)) && (sessionMRank <= (block?.maxMRank ?? -1))) {
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


function getSpawnScoreWeaponMulParamValue(unitName, unitClass, paramName) {
  let weaponMulBlk = get_warpoints_blk()?.respawn_points.WeaponMul
  return weaponMulBlk?[unitName][paramName]
    ?? weaponMulBlk?[unitClass][paramName]
    ?? weaponMulBlk?["Common"][paramName]
}

function getSpawnScoreWeaponMulByParams(unitName, unitClass, massParams, atgmParams, aamParams) {
  local weaponMul = 1.0
  local bombRocketMul = 1.0
  local bombRocketMulMax = 1.0
  if (massParams.totalBombRocketMass > 0) {
    let bombRocketWeaponBlk = getSpawnScoreWeaponMulParamValue(unitName, unitClass, "BombRocketWeapon")
    if (bombRocketWeaponBlk?.mass != null) {
      bombRocketMul += (interpolateArray((bombRocketWeaponBlk % "mass"), massParams.totalBombRocketMass) - 1.0)
      bombRocketMulMax = math.max(bombRocketMulMax, bombRocketWeaponBlk.getParamValue(bombRocketWeaponBlk.paramCount() - 1).y)
    }
  }
  if (massParams.totalNapalmBombMass > 0) {
    let napalmBombWeaponBlk = getSpawnScoreWeaponMulParamValue(unitName, unitClass, "NapalmBombWeapon")
    if (napalmBombWeaponBlk?.mass != null) {
      bombRocketMul += (interpolateArray((napalmBombWeaponBlk % "mass"), massParams.totalNapalmBombMass) - 1.0)
      bombRocketMulMax = math.max(bombRocketMulMax, napalmBombWeaponBlk.getParamValue(napalmBombWeaponBlk.paramCount() - 1).y)
    }
  }
  if (massParams.totalGuidedBombMass > 0) {
    let guidedBombWeaponBlk = getSpawnScoreWeaponMulParamValue(unitName, unitClass, "GuidedBombWeapon")
    if (guidedBombWeaponBlk?.mass != null) {
      bombRocketMul += (interpolateArray((guidedBombWeaponBlk % "mass"), massParams.totalGuidedBombMass) - 1.0)
      bombRocketMulMax = math.max(bombRocketMulMax, guidedBombWeaponBlk.getParamValue(guidedBombWeaponBlk.paramCount() - 1).y)
    }
  }
  if (massParams.totalTorpedoMass > 0) {
    let torpedoWeaponBlk = getSpawnScoreWeaponMulParamValue(unitName, unitClass, "TorpedoWeapon")
    if (torpedoWeaponBlk?.mass != null) {
      bombRocketMul += (interpolateArray((torpedoWeaponBlk % "mass"), massParams.totalTorpedoMass) - 1.0)
      bombRocketMulMax = math.max(bombRocketMulMax, torpedoWeaponBlk.getParamValue(torpedoWeaponBlk.paramCount() - 1).y)
    }
  }
  weaponMul = math.min(bombRocketMul, bombRocketMulMax)
  if (atgmParams.visibilityTypeArr.len() > 0) {
    let atgmVisibilityTypeMulBlk = getSpawnScoreWeaponMulParamValue(unitName, unitClass, "AtgmVisibilityTypeMul")
    foreach (atgmVisibilityType in atgmParams.visibilityTypeArr) {
      weaponMul = math.max(weaponMul, atgmVisibilityTypeMulBlk?[atgmVisibilityType] ?? 0.0)
    }
    let maxDistance = atgmParams.maxDistance
    if (maxDistance > 0) {
      let atgmMaxDistanceMulBlk = getSpawnScoreWeaponMulParamValue(unitName, unitClass, "AtgmMaxDistanceMul")
      if (atgmMaxDistanceMulBlk?.dist != null) {
        weaponMul *= interpolateArray((atgmMaxDistanceMulBlk % "dist"), maxDistance)
      }
    }
    if (atgmParams.hasProximityFuse) {
      let atgmHasProximityFuseMul = getSpawnScoreWeaponMulParamValue(unitName, unitClass, "atgmHasProximityFuseMul")
      if (atgmHasProximityFuseMul != null) {
        weaponMul *= getSpawnScoreWeaponMulParamValue(unitName, unitClass, "atgmHasProximityFuseMul")
      }
    }
  }
  if (aamParams.guidanceTypeArr.len() > 0) {
    let aamGuidanceTypeMulBlk = getSpawnScoreWeaponMulParamValue(unitName, unitClass, "AamGuidanceTypeMul")
    foreach (aamGuidanceType in aamParams.guidanceTypeArr) {
      weaponMul = math.max(weaponMul, aamGuidanceTypeMulBlk?[aamGuidanceType] ?? 0.0)
    }
  }
  if (massParams.maxRocketTntMass > 0) {
    let largeRocketTntMass = getSpawnScoreWeaponMulParamValue(unitName, unitClass, "largeRocketTntMass")
    let largeRocketMul = getSpawnScoreWeaponMulParamValue(unitName, unitClass, "largeRocketMul")
    if (largeRocketTntMass != null && largeRocketMul != null && massParams.maxRocketTntMass >= largeRocketTntMass) {
      weaponMul = math.max(weaponMul, largeRocketMul)
    }
  }
  return weaponMul
}

function getCustomWeaponPresetParams(unitname, weaponTable) {
  let resTable = {
    massParams = { totalBombRocketMass = 0, totalNapalmBombMass = 0, totalGuidedBombMass = 0, totalTorpedoMass = 0, maxRocketTntMass = 0 }
    atgmParams = { visibilityTypeArr = [], maxDistance = 0, hasProximityFuse = false }
    aamParams = { guidanceTypeArr = [] }
  }

  let weaponsBlk = get_wpcost_blk()?[unitname].weapons
  if (weaponsBlk == null)
    return resTable

  foreach (weaponName, count in weaponTable) {
    let totalBombRocketMass = weaponsBlk?[weaponName].totalBombRocketMass ?? 0
    let totalNapalmBombMass = weaponsBlk?[weaponName].totalNapalmBombMass ?? 0
    let totalGuidedBombMass = weaponsBlk?[weaponName].totalGuidedBombMass ?? 0
    let totalTorpedoMass = weaponsBlk?[weaponName].totalTorpedoMass ?? 0
    let maxRocketTntMass = weaponsBlk?[weaponName].maxRocketTntMass ?? 0
    let atgmVisibilityType = weaponsBlk?[weaponName].atgmVisibilityType ?? ""
    let atgmMaxDistance = weaponsBlk?[weaponName].atgmMaxDistance ?? 0
    let atgmHasProximityFuse = weaponsBlk?[weaponName].atgmHasProximityFuse ?? false
    let aamGuidanceType = weaponsBlk?[weaponName].aamGuidanceType ?? ""

    resTable.massParams.totalBombRocketMass += (totalBombRocketMass * count)
    resTable.massParams.totalNapalmBombMass += (totalNapalmBombMass * count)
    resTable.massParams.totalGuidedBombMass += (totalGuidedBombMass * count)
    resTable.massParams.totalTorpedoMass += (totalTorpedoMass * count)
    resTable.massParams.maxRocketTntMass = math.max(maxRocketTntMass, resTable.massParams.maxRocketTntMass)

    if (atgmVisibilityType != "" && resTable.atgmParams.visibilityTypeArr.indexof(atgmVisibilityType) == null) {
      resTable.atgmParams.visibilityTypeArr.append(atgmVisibilityType)
    }
    resTable.atgmParams.maxDistance = math.max(atgmMaxDistance, resTable.atgmParams.maxDistance)
    if (atgmHasProximityFuse) {
      resTable.atgmParams.hasProximityFuse = true
    }

    if (aamGuidanceType != "" && resTable.aamParams.guidanceTypeArr.indexof(aamGuidanceType) == null) {
      resTable.aamParams.guidanceTypeArr.append(aamGuidanceType)
    }
  }

  return resTable
}

function getSpawnTypeByWeapon(unitname, weapon, bulletArray, presetTbl) {
  let misBlk = get_current_mission_info_cached()
  if (!misBlk?.useSpawnTypeByWeaponForSpawnScore)
    return ""

  let wpcost = get_wpcost_blk()
  let unitType = get_unit_type_by_unit_name(unitname)
  let unitClass = wpcost?[unitname].unitClass
  if (unitType != DS_UT_AIRCRAFT || unitClass == "exp_helicopter") 
    return ""

  local hasArmorPiercingBelt = false
  if (get_spawn_score_param("useSpawnCostMulForBullet", false)) {
    foreach (bulletOrGun in bulletArray) {
      let spawnCostMul = wpcost?[unitname].modifications[bulletOrGun].spawnCostMul
        ?? wpcost?[unitname].defaultBeltParam[bulletOrGun].spawnCostMul ?? 1.0
      if (spawnCostMul > 1.0) {
        hasArmorPiercingBelt = true
        break
      }
    }
  }

  local hasAirToSurfaceWeapon = false
  let weaponBlk = wpcost?[unitname].weapons[weapon]
  if (weaponBlk != null) {
    hasAirToSurfaceWeapon = weaponBlk?.totalBombRocketMass != null
      || weaponBlk?.totalNapalmBombMass != null || weaponBlk?.totalGuidedBombMass != null
      || weaponBlk?.totalTorpedoMass != null || weaponBlk?.atgmVisibilityType != null
  }
  else if (presetTbl?.presetWeapons != null && presetTbl.presetWeapons.len() > 0) {
    let weaponsBlk = get_wpcost_blk()?[unitname].weapons
    if (weaponsBlk != null) {
      foreach (weaponName, _count in presetTbl.presetWeapons) {
        hasAirToSurfaceWeapon = weaponsBlk?[weaponName].totalBombRocketMass != null
          || weaponsBlk?[weaponName].totalNapalmBombMass != null || weaponsBlk?[weaponName].totalGuidedBombMass != null
          || weaponsBlk?[weaponName].totalTorpedoMass != null || weaponsBlk?[weaponName].atgmVisibilityType != null

        if (hasAirToSurfaceWeapon)
          break
      }
    }
  }

  let spawnType = (hasArmorPiercingBelt || hasAirToSurfaceWeapon) ? "bomber" : "exp_fighter"
  return spawnType
}

function get_spawn_score_type_mul(userId, unitname, weapon, bulletArray, presetTbl) {
  local spawnMul = 1.0

  let misBlk = get_current_mission_info_cached()
  let persistentCost = misBlk?.customSpawnScore.persistent_costs[unitname] ?? 0
  if (persistentCost > 0) {
    log($"get_spawn_score_type_mul unit {unitname} in persistent_costs; spawnMul = {spawnMul}")
    return spawnMul
  }

  let spawnPow = get_spawn_score_param("spawn_pow", 1.0)
  let spawnTypeByWeapon = getSpawnTypeByWeapon(unitname, weapon, bulletArray, presetTbl)
  let spawnType = spawnTypeByWeapon != "" ? spawnTypeByWeapon : get_unit_spawn_type(unitname)

  if (spawnType) {
    let userStateBlk = get_user_custom_state(userId, false)
    if (spawnType in userStateBlk?.numSpawnByType) {
      let spawnTypeMul = userStateBlk.numSpawnByType[spawnType]
      spawnMul = 1.0 + spawnTypeMul.tofloat()
    }
    spawnMul = math.pow(spawnMul, spawnPow)
  }
  let spawnTypeParamName = spawnTypeByWeapon != "" ? "spawnTypeByWeapon" : "spawnType"
  log($"get_spawn_score_type_mul {userId} {unitname}: {spawnTypeParamName} = {spawnType},",
    $"spawnPow = {spawnPow}; spawnMul = {spawnMul}")
  return spawnMul
}

function get_unit_spawn_score_weapon_mul(unitname, weapon, bulletArray, presetTbl = {}) {
  let wpcost = get_wpcost_blk()
  let unitClass = wpcost?[unitname]?.unitClass
  if (unitClass == null)
    return 1.0

  local bulletsMul = 1.0
  if (get_spawn_score_param("useSpawnCostMulForBullet", false)) {
    foreach (bulletOrGun in bulletArray) {
      let spawnCostMul = wpcost?[unitname].modifications[bulletOrGun].spawnCostMul
        ?? wpcost?[unitname].defaultBeltParam[bulletOrGun].spawnCostMul ?? 1.0
      bulletsMul += (spawnCostMul - 1.0)
    }
  }

  local weaponMul = 1.0
  if (get_spawn_score_param("useSpawnCostMulForWeapon", false)) {
    let weaponBlk = wpcost?[unitname].weapons[weapon]
    if (weaponBlk != null) {
      let weaponMulBlk = get_warpoints_blk()?.respawn_points.WeaponMul
      if (weaponMulBlk != null) {
        let massParams = {
          totalBombRocketMass = weaponBlk?.totalBombRocketMass ?? 0
          totalNapalmBombMass = weaponBlk?.totalNapalmBombMass ?? 0
          totalGuidedBombMass = weaponBlk?.totalGuidedBombMass ?? 0
          totalTorpedoMass = weaponBlk?.totalTorpedoMass ?? 0
          maxRocketTntMass = weaponBlk?.maxRocketTntMass ?? 0
        }
        let atgmParams = {
          visibilityTypeArr = (weaponBlk % "atgmVisibilityType") ?? [],
          maxDistance = weaponBlk?.atgmMaxDistance ?? 0,
          hasProximityFuse = weaponBlk?.atgmHasProximityFuse ?? false
        }
        let aamParams = {
          guidanceTypeArr = (weaponBlk % "aamGuidanceType") ?? []
        }
        weaponMul = getSpawnScoreWeaponMulByParams(unitname, unitClass, massParams, atgmParams, aamParams)
      }
    }
    else if (presetTbl?.presetWeapons != null && presetTbl.presetWeapons.len() > 0) {
      let customWeaponPresetParams = getCustomWeaponPresetParams(unitname, presetTbl.presetWeapons)
      weaponMul = getSpawnScoreWeaponMulByParams(
        unitname,
        unitClass,
        customWeaponPresetParams.massParams,
        customWeaponPresetParams.atgmParams,
        customWeaponPresetParams.aamParams
      )
    }
  }

  return 1.0 + (bulletsMul - 1.0) + (weaponMul - 1.0)
}



local validate_custom_mission_last_error = ""

function validate_custom_mission(misblk) {
  validate_custom_mission_last_error = ""

  let err = function(str) {
    if (validate_custom_mission_last_error != "")
      validate_custom_mission_last_error = $"{validate_custom_mission_last_error}\n"
    validate_custom_mission_last_error = $"{validate_custom_mission_last_error}{str}";
  }

  let md = misblk?.mission_settings.mission
  if (!file_exists(md?.level ?? ""))
    err("".concat("Unknown location ", (md?.level ?? "null")))
  let levelBlk = "".concat((md?.level ?? "").slice(0, -3), "blk")
  if (!file_exists(levelBlk))
    err($"{levelBlk} not found");

  
  

  let units_include = misblk?.mission_settings.units_include
  if (units_include != null)
    for (local i = 0; i < units_include.blockCount(); i++) {
      let inc = units_include.getBlock(i);
      if (inc.filename != null) {
        if ((inc.filename == "") || (!file_exists(inc.filename)))
          err($"Wrong units include: {inc.filename}")
      }
    }


  let typeToPath = {
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

  let units = misblk?.units ?? DataBlock()
  for (local i = 0; i < units.blockCount(); i++) {
    let unit = units.getBlock(i);
    let unitType = unit.getBlockName();
    let unitClass = unit?.unit_class
    if (unitType in typeToPath) {
      let path = unitClass ? "".concat(typeToPath[unitType], "/", unitClass, ".blk") : ""
      if (!file_exists(path))
        err($"Unknown unit_class {unitClass} of unit {unit?.name}")
      else {
        let preset = unit?.weapons
        if (preset != null && preset != "") {
          let unitBlk = blkFromPath(path)
          if (unitBlk?.weapon_presets == null)
            err($"No weapon presets in {path}")
          else {
            let presets = unitBlk.weapon_presets % "preset"
            local found = false
            foreach (p in presets)
              if (p?.name == preset) {
                if (file_exists(p?.blk ?? "")) {
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
      
    }
  }
  log(validate_custom_mission_last_error)
  return validate_custom_mission_last_error
}

let cyber_cafe_boost = {
  level = [{ wp = 0, xp = 0 }, { wp = 0.0, xp = 0.05 }, { wp = 0.0, xp = 0.1 }, { wp = 0.1, xp = 0.1 }]
  squad = [{ wp = 0, xp = 0 }, { wp = 0.0, xp = 0.0 }, { wp = 0.0, xp = 0.1 }, { wp = 0.05, xp = 0.1 }, { wp = 0.05, xp = 0.1 }]
  isValid = false
}

local cyber_cafe_max_level = cyber_cafe_boost.level.len() - 1

let get_cyber_cafe_max_level = @() cyber_cafe_max_level

cyber_cafe_boost.loadTables <- function loadTables() {
  if (this.isValid)
    return

  let ws = get_warpoints_blk()

  foreach (idx, param in this.level) {
    param.wp = ws.getReal($"cyberCafeLevelBoost{idx.tostring()}WP", param.wp)
    param.xp = ws.getReal($"cyberCafeLevelBoost{idx.tostring()}XP", param.xp)
  }

  foreach (idx, param in this.squad) {
    param.wp = ws.getReal($"cyberCafeSquadBoost{idx.tostring()}WP", param.wp)
    param.xp = ws.getReal($"cyberCafeSquadBoost{idx.tostring()}XP", param.xp)
  }

  this.isValid = true
}


function calc_boost_for_cyber_cafe(level) {
  cyber_cafe_boost.loadTables()

  if (level > cyber_cafe_max_level)
    level = cyber_cafe_max_level

  return cyber_cafe_boost.level[level]
}


function calc_boost_for_squads_members_from_same_cyber_cafe(numMembers) {
  cyber_cafe_boost.loadTables()

  if (numMembers > 4)
    numMembers = 4

  return cyber_cafe_boost.squad[numMembers]
}

function get_pve_time_award_stage(sessionTime) {
  let ws = get_warpoints_blk()
  let timeAwardStep = ws.getInt("pveTimeAwardStep", 0)
  local timeAwardStage = 0

  if (timeAwardStep > 0) {
    timeAwardStage = ((sessionTime / 60) / timeAwardStep).tointeger()
  }
  log($"get_pve_time_award_stage stage {timeAwardStage} sessionTime {sessionTime} timeAwardStep {timeAwardStep} minutes")
  return timeAwardStage
}


function get_pve_trophy_name(sessionTime, success) {
  let mis = get_current_mission_info_cached()
  let ws = get_warpoints_blk()
  local pveTrophyName = mis.pveTrophyName

  if (pveTrophyName == null || type(pveTrophyName) != "string") {
    log("get_pve_trophy_name. PVE Trophy for this mission is missing or not a string.")
    return null
  }

  if (success) {
    pveTrophyName = $"{pveTrophyName}_win"
  }
  else {
    let maxTrophyStage = ws.getInt("pveTrophyMaxStage", 0)
    local trophyStage = get_pve_time_award_stage(sessionTime)
    if (trophyStage > maxTrophyStage)
      trophyStage = maxTrophyStage
    if (trophyStage <= 0) {
      log($"get_pve_trophy_name. cannot generate trophy name for this amount of time in session: {sessionTime}")
      return null
    }
    pveTrophyName = $"{pveTrophyName}_stage_{trophyStage}"
  }
  log($"get_pve_trophy_name. trophy name {pveTrophyName} success? {success} session time {sessionTime}")
  return pveTrophyName
}

local maxEconomicRank = null
function getMaxEconomicRank() {
  if (maxEconomicRank != null)
    return maxEconomicRank

  maxEconomicRank = get_wpcost_blk()?.economicRankMax
  return maxEconomicRank ?? 29
}

let calcBattleRatingFromRank = @(economicRank) round_by_value(economicRank / 3.0 + 1, 0.1)

return {
  get_unit_blk_battle_rating_by_mode = @(unitBlk, ediff) calcBattleRatingFromRank(get_unit_blk_economic_rank_by_mode(unitBlk, ediff))
  getMaxEconomicRank
  EDifficulties
  EDIFF_SHIFT
  calcBattleRatingFromRank
  mapWpUnitClassToWpUnitType
  EDifficultiesStr
  reset_cur_mission_mode
  get_cyber_cafe_max_level
  get_pve_time_award_stage
  get_pve_trophy_name
  calc_boost_for_cyber_cafe
  calc_boost_for_squads_members_from_same_cyber_cafe
  validate_custom_mission
  get_emode_name
  get_mission_mode
  get_econRank_emode_name
  calc_public_boost
  calc_personal_boost = calc_public_boost
  get_ds_ut_name_unit_type
  get_unit_blk_economic_rank_by_mode
  get_unit_type_by_unit_name
  get_spawn_score_param
  getWpcostUnitClass
  get_mp_team_by_team_name
  get_team_name_by_mp_team
  unitHasTag
  isUnitSpecial
  get_unit_spawn_score_weapon_mul
  get_spawn_score_type_mul
  getSpawnTypeByWeapon

  DS_UT_AIRCRAFT
  DS_UT_TANK
  DS_UT_SHIP
  DS_UT_INVALID
}
