from "%scripts/dagui_library.nut" import *
let { get_modifications_blk, get_wpcost_blk } = require("blkGetters")
let { shopIsModificationEnabled } = require("chardResearch")
let { appendOnce, copy } = require("%sqStdLibs/helpers/u.nut")
let { S_UNDEFINED, S_AIRCRAFT, S_HELICOPTER, S_TANK, S_SHIP, S_BOAT, compareWeaponFunc,
  mkTankCrewMemberDesc, mkGunnerDesc, mkPilotDesc, mkEngineDesc, mkTransmissionDesc, mkDriveTurretDesc,
  mkAircraftFuelTankDesc, mkWeaponDesc, mkAmmoDesc, mkTankArmorPartDesc, mkCoalBunkerDesc, mkSensorDesc,
  mkCountermeasureDesc, mkApsSensorDesc, mkApsLauncherDesc, mkAvionicsDesc, mkCommanderPanoramicSightDesc,
  mkFireDirecirOrRangefinderDesc, mkFireControlRoomOrBridgeDesc, mkPowerSystemDesc, mkFireControlSystemDesc,
  mkHydraulicsSystemDesc, mkElectronicEquipmentDesc, mkSimpleDescByPartType
} = require("%globalScripts/modeXrayLib.nut")
let { measureType } = require("%scripts/measureType.nut")
let { getCurrentGameModeEdiff } = require("%scripts/gameModes/gameModeManagerState.nut")
let { getParametersByCrewId } = require("%scripts/crew/crewSkillParameters.nut")
let { skillParametersRequestType } = require("%scripts/crew/skillParametersRequestType.nut")
let { isCaliberCannon, getCommonWeapons, getLastPrimaryWeapon,
  getPrimaryWeaponsList, getWeaponNameByBlkPath, getTurretGuidanceSpeedMultByDiff
} = require("%scripts/weaponry/weaponryInfo.nut")
let { getUnitWeapons } = require("%scripts/weaponry/weaponryPresets.nut")
let { isModAvailableOrFree } = require("%scripts/weaponry/modificationInfo.nut")
let { getWeaponXrayDescText } = require("%scripts/weaponry/weaponryDescription.nut")
let { getFmFile } = require("%scripts/unit/unitParams.nut")

let unitTypeToSimpleUnitTypeMap = {
  [ES_UNIT_TYPE_AIRCRAFT] = S_AIRCRAFT,
  [ES_UNIT_TYPE_HELICOPTER] = S_HELICOPTER,
  [ES_UNIT_TYPE_TANK] = S_TANK,
  [ES_UNIT_TYPE_SHIP] = S_SHIP,
  [ES_UNIT_TYPE_BOAT] = S_BOAT,
}

let getSimpleUnitType = @(unit) unitTypeToSimpleUnitTypeMap?[unit?.esUnitType] ?? S_UNDEFINED

let xrayDescCtorsMap = {
  
  commander = mkTankCrewMemberDesc
  driver = mkTankCrewMemberDesc
  loader = mkTankCrewMemberDesc
  machine_gunner = mkTankCrewMemberDesc
  gunner = mkGunnerDesc
  pilot = mkPilotDesc
  
  engine = mkEngineDesc
  transmission = mkTransmissionDesc
  drive_turret_h = mkDriveTurretDesc
  drive_turret_v = mkDriveTurretDesc
  tank = mkAircraftFuelTankDesc
  
  main_caliber_turret = mkWeaponDesc
  auxiliary_caliber_turret = mkWeaponDesc
  aa_turret = mkWeaponDesc
  mg = mkWeaponDesc
  gun = mkWeaponDesc
  mgun = mkWeaponDesc
  cannon = mkWeaponDesc
  mask = mkWeaponDesc
  gun_mask = mkWeaponDesc
  gun_barrel = mkWeaponDesc
  cannon_breech = mkWeaponDesc
  tt = mkWeaponDesc
  torpedo = mkWeaponDesc
  main_caliber_gun = mkWeaponDesc
  auxiliary_caliber_gun = mkWeaponDesc
  depth_charge = mkWeaponDesc
  mine = mkWeaponDesc
  aa_gun = mkWeaponDesc
  
  elevator = mkAmmoDesc
  ammo_turret = mkAmmoDesc
  ammo_body = mkAmmoDesc
  ammunition_storage = mkAmmoDesc
  ammunition_storage_shells = mkAmmoDesc
  ammunition_storage_charges = mkAmmoDesc
  ammunition_storage_aux = mkAmmoDesc
  
  firewall_armor = mkTankArmorPartDesc
  composite_armor_hull = mkTankArmorPartDesc
  composite_armor_turret = mkTankArmorPartDesc
  ex_era_hull = mkTankArmorPartDesc
  ex_era_turret = mkTankArmorPartDesc
  coal_bunker = mkCoalBunkerDesc
  
  radar = mkSensorDesc
  antenna_target_location = mkSensorDesc
  antenna_target_tagging = mkSensorDesc
  antenna_target_tagging_mount = mkSensorDesc
  optic_gun = mkSensorDesc
  countermeasure = mkCountermeasureDesc
  aps_sensor = mkApsSensorDesc
  aps_launcher = mkApsLauncherDesc
  ex_aps_launcher = mkApsLauncherDesc
  
  electronic_block = mkAvionicsDesc
  optic_block = mkAvionicsDesc
  cockpit_countrol = mkAvionicsDesc
  ircm = mkAvionicsDesc
  
  commander_panoramic_sight = mkCommanderPanoramicSightDesc
  fire_director = mkFireDirecirOrRangefinderDesc
  rangefinder = mkFireDirecirOrRangefinderDesc
  fire_control_room = mkFireControlRoomOrBridgeDesc
  bridge = mkFireControlRoomOrBridgeDesc
  power_system = mkPowerSystemDesc
  fire_control_system = mkFireControlSystemDesc
  turret_hydraulics = mkHydraulicsSystemDesc
  electronic_equipment = mkElectronicEquipmentDesc
  
  autoloader = mkSimpleDescByPartType
  driver_controls = mkSimpleDescByPartType
  gun_trunnion = mkSimpleDescByPartType
  fuel_tank_exterior = mkSimpleDescByPartType
}

let getModEffectMul = @(commonData, modId, effectId)
  shopIsModificationEnabled(commonData.unitName, modId) ? 1.0
   : (get_modifications_blk()?.modifications[modId].effects[effectId] ?? 1.0)

function findAnyModEffectValueBlk(commonData, effectId) {
  let { unitBlk, unitName, isDebugBatchExportProcess } = commonData
  for (local b = 0; b < (unitBlk?.modifications.blockCount() ?? 0); b++) {
    let modBlk = unitBlk.modifications.getBlock(b)
    let value = modBlk?.effects[effectId]
    if (value != null
      && (isDebugBatchExportProcess || shopIsModificationEnabled(unitName, modBlk.getBlockName())))
        return value
  }
  return null
}

function findModEffectValuesString(commonData, effectId) {
  let { unitBlk, unitName, isDebugBatchExportProcess } = commonData
  let res = []
  for (local b = 0; b < (unitBlk?.modifications.blockCount() ?? 0); b++) {
    let modBlk = unitBlk.modifications.getBlock(b)
    let modEffectsBlk = modBlk?.effects
    if (!modEffectsBlk)
      continue
    let effects = (modEffectsBlk % effectId)
    if (effects.len() && (isDebugBatchExportProcess || shopIsModificationEnabled(unitName, modBlk.getBlockName())))
      res.extend(effects)
  }
  return res
}

function getUnitFmBlk(commonData) {
  let { unitDataCache, unitName, unitBlk } = commonData
  if ("fmBlk" not in unitDataCache)
    unitDataCache.fmBlk <- getFmFile(unitName, unitBlk)
  return unitDataCache.fmBlk
}

function getUnitWeaponsList(commonData) {
  let { unitDataCache } = commonData
  if ("weaponBlkList" not in unitDataCache) {
    let { unitBlk, unit } = commonData
    let weaponBlkList = []
    if (unitBlk != null) {
      let primaryList = [ getLastPrimaryWeapon(unit) ]
      let unitName = unit.name
      foreach (modName in getPrimaryWeaponsList(unit))
        appendOnce(modName, primaryList)

      foreach (modName in primaryList)
        foreach (weapon in getCommonWeapons(unitBlk, modName, unitName))
          if (weapon?.blk && !weapon?.dummy)
            appendOnce(weapon, weaponBlkList, false, compareWeaponFunc)

      let weapons = getUnitWeapons(unitName, unitBlk)
      foreach (weap in weapons)
        if (weap?.blk && !weap?.dummy)
          appendOnce(copy(weap),weaponBlkList, false, compareWeaponFunc)
    }
    unitDataCache.weaponBlkList <- weaponBlkList
  }
  return unitDataCache.weaponBlkList
}

function getCrewSkillsBase(commonData) {
  let { unitDataCache, unit, difficulty } = commonData
  if ("crewSkillsBase" not in unitDataCache)
    unitDataCache.crewSkillsBase <- unit == null ? null
      : skillParametersRequestType.BASE_VALUES.getParameters(-1, unit)[difficulty.crewSkillName]
  return unitDataCache.crewSkillsBase
}

function getCrewSkillsCur(commonData) {
  let { unitDataCache, unit, difficulty, crewId } = commonData
  if ("crewSkillsCur" not in unitDataCache)
    unitDataCache.crewSkillsCur <- unit == null ? null
      : skillParametersRequestType.CURRENT_VALUES.getParameters(crewId ?? -1, unit)[difficulty.crewSkillName]
  return unitDataCache.crewSkillsCur
}

function getCrewSkillsTop(commonData) {
  let { unitDataCache, unit, difficulty } = commonData
  if ("crewSkillsTop" not in unitDataCache)
    unitDataCache.crewSkillsTop <- unit == null ? null
      : skillParametersRequestType.MAX_VALUES.getParameters(-1, unit)[difficulty.crewSkillName]
  return unitDataCache.crewSkillsTop
}

let getAircraftFuelTankPartInfo = @(commonData, partName) commonData.unit?.info[partName] ?? commonData.unit?.info.tanks_params

let getWeaponDescTextByWeaponInfoBlk = @(commonData, weaponInfoBlk)
  getWeaponXrayDescText(weaponInfoBlk, commonData.unit, getCurrentGameModeEdiff())

let getProp_maxSpeed = @(commonData)
  commonData.unit?.modificators[commonData.difficulty.crewSkillName]?.maxSpeed ?? 0.0
let getProp_horsePowers = @(commonData)
  commonData.unit?.modificators[commonData.difficulty.crewSkillName]?.horsePowers ?? 0.0
let getProp_maxHorsePowersRPM = @(commonData)
  commonData.unit?.modificators[commonData.difficulty.crewSkillName]?.maxHorsePowersRPM ?? 0.0
let getProp_thrust = @(commonData)
  commonData.unit?.modificators[commonData.difficulty.crewSkillName]?.thrust ?? 0.0

let getProp_tankMainTurretSpeedYaw = @(commonData)
  commonData.unit?.modificators[commonData.difficulty.crewSkillName]?.turnTurretSpeed ?? 0.0
let getProp_tankMainTurretSpeedYawTop = @(commonData)
  getCrewSkillsTop(commonData)?.tank_gunner.tracking.turnTurretSpeed ?? 0.0
let getProp_tankMainTurretSpeedPitch = @(commonData)
  commonData.unit?.modificators[commonData.difficulty.crewSkillName]?.turnTurretSpeedPitch ?? 0.0
let getProp_tankMainTurretSpeedPitchTop = @(commonData)
  getCrewSkillsTop(commonData)?.tank_gunner.tracking.turnTurretSpeedPitch ?? 0.0

let getProp_tankReloadTime = @(commonData)
  getCrewSkillsCur(commonData)?.loader.loading_time_mult.tankLoderReloadingTime ?? 0.0
let getProp_tankReloadTimeTop = @(commonData)
  getCrewSkillsTop(commonData)?.loader.loading_time_mult.tankLoderReloadingTime ?? 0.0

let getProp_shipReloadTimeMainDef = @(commonData, weaponName)
  get_wpcost_blk()?[commonData.unitName][$"shipMainCaliberReloadTime_{weaponName}"] ?? 0.0
let getProp_shipReloadTimeMainCur = @(commonData, weaponName)
  getParametersByCrewId(commonData.crewId, commonData.unitName)?[commonData.difficulty.crewSkillName]
    .ship_artillery.main_caliber_loading_time[$"weapons/{weaponName}"] ?? 0.0
let getProp_shipReloadTimeMainTop = @(commonData, weaponName)
  getCrewSkillsTop(commonData)?.ship_artillery.main_caliber_loading_time[$"weapons/{weaponName}"] ?? 0.0
let getProp_shipReloadTimeMainBase = @(commonData, weaponName)
  getCrewSkillsBase(commonData)?.ship_artillery.main_caliber_loading_time[$"weapons/{weaponName}"] ?? 0.0

let getProp_shipReloadTimeAuxDef = @(commonData, weaponName)
  get_wpcost_blk()?[commonData.unitName][$"shipAuxCaliberReloadTime_{weaponName}"] ?? 0.0
let getProp_shipReloadTimeAuxCur = @(commonData, weaponName)
  getParametersByCrewId(commonData.crewId, commonData.unitName)?[commonData.difficulty.crewSkillName]
    .ship_artillery.aux_caliber_loading_time[$"weapons/{weaponName}"] ?? 0.0
let getProp_shipReloadTimeAuxTop = @(commonData, weaponName)
  getCrewSkillsTop(commonData)?.ship_artillery.aux_caliber_loading_time[$"weapons/{weaponName}"] ?? 0.0
let getProp_shipReloadTimeAuxBase = @(commonData, weaponName)
  getCrewSkillsBase(commonData)?.ship_artillery.aux_caliber_loading_time[$"weapons/{weaponName}"] ?? 0.0

let getProp_shipReloadTimeAaDef = @(commonData, weaponName)
  get_wpcost_blk()?[commonData.unitName][$"shipAntiAirCaliberReloadTime_{weaponName}"] ?? 0.0
let getProp_shipReloadTimeAaCur = @(commonData, weaponName)
  getParametersByCrewId(commonData.crewId, commonData.unitName)?[commonData.difficulty.crewSkillName]
    .ship_artillery.antiair_caliber_loading_time[$"weapons/{weaponName}"] ?? 0.0
let getProp_shipReloadTimeAaTop = @(commonData, weaponName)
  getCrewSkillsTop(commonData)?.ship_artillery.antiair_caliber_loading_time[$"weapons/{weaponName}"] ?? 0.0
let getProp_shipReloadTimeAaBase = @(commonData, weaponName)
  getCrewSkillsBase(commonData)?.ship_artillery.antiair_caliber_loading_time[$"weapons/{weaponName}"] ?? 0.0

let getMul_shipDistancePrecisionError = @(commonData)
  getModEffectMul(commonData, "ship_rangefinder", "shipDistancePrecisionErrorMult")

let getShipTurretBoostHorz = @(commonData)
  getTurretGuidanceSpeedMultByDiff(commonData.ediff)?.arcadeTurretBoostHorz ?? 1.0
let getShipTurretBoostVert = @(commonData)
  getTurretGuidanceSpeedMultByDiff(commonData.ediff)?.arcadeTurretBoostVert ?? 1.0

let getMul_shipTurretMainSpeedYaw = @(commonData)
  getModEffectMul(commonData, "new_main_caliber_turrets", "mainSpeedYawK") * getShipTurretBoostHorz(commonData)
let getMul_shipTurretAuxSpeedYaw = @(commonData)
  getModEffectMul(commonData, "new_aux_caliber_turrets", "auxSpeedYawK") * getShipTurretBoostHorz(commonData)
let getMul_shipTurretAaSpeedYaw = @(commonData)
  getModEffectMul(commonData, "new_aa_caliber_turrets", "aaSpeedYawK") * getShipTurretBoostHorz(commonData)
let getMul_shipTurretMainSpeedPitch = @(commonData)
  getModEffectMul(commonData, "new_main_caliber_turrets", "mainSpeedPitchK") * getShipTurretBoostVert(commonData)
let getMul_shipTurretAuxSpeedPitch = @(commonData)
  getModEffectMul(commonData, "new_aux_caliber_turrets", "auxSpeedPitchK") * getShipTurretBoostVert(commonData)
let getMul_shipTurretAaSpeedPitch = @(commonData)
  getModEffectMul(commonData, "new_aa_caliber_turrets", "aaSpeedPitchK") * getShipTurretBoostVert(commonData)

let toStr_speed = @(v) measureType.SPEED.getMeasureUnitsText(v)
let toStr_horsePowers = @(v) measureType.HORSEPOWERS.getMeasureUnitsText(v)
let toStr_thrustKgf = @(v) measureType.THRUST_KGF.getMeasureUnitsText(v)
let toStr_distance = @(v) measureType.DISTANCE.getMeasureUnitsText(v)

let xrayCommonGetters = {
  isCaliberCannon
  getCommonWeapons
  getWeaponNameByBlkPath
  getWeaponDescTextByWeaponInfoBlk
  findAnyModEffectValueBlk
  findModEffectValuesString
  isModAvailableOrFree
  getUnitFmBlk
  getUnitWeaponsList
  getAircraftFuelTankPartInfo

  
  getProp_maxSpeed
  getProp_horsePowers
  getProp_maxHorsePowersRPM
  getProp_thrust
  getProp_tankMainTurretSpeedYaw
  getProp_tankMainTurretSpeedYawTop
  getProp_tankMainTurretSpeedPitch
  getProp_tankMainTurretSpeedPitchTop
  getProp_tankReloadTime
  getProp_tankReloadTimeTop
  getProp_shipReloadTimeMainDef
  getProp_shipReloadTimeMainCur
  getProp_shipReloadTimeMainTop
  getProp_shipReloadTimeMainBase
  getProp_shipReloadTimeAuxDef
  getProp_shipReloadTimeAuxCur
  getProp_shipReloadTimeAuxTop
  getProp_shipReloadTimeAuxBase
  getProp_shipReloadTimeAaDef
  getProp_shipReloadTimeAaCur
  getProp_shipReloadTimeAaTop
  getProp_shipReloadTimeAaBase

  
  getMul_shipDistancePrecisionError
  getMul_shipTurretMainSpeedYaw
  getMul_shipTurretAuxSpeedYaw
  getMul_shipTurretAaSpeedYaw
  getMul_shipTurretMainSpeedPitch
  getMul_shipTurretAuxSpeedPitch
  getMul_shipTurretAaSpeedPitch

  
  toStr_speed
  toStr_horsePowers
  toStr_thrustKgf
  toStr_distance
}

function getDescriptionInXrayMode(partType, params, commonData) {
  let res = {
    partLocId = partType
    desc = []
  }
  return (commonData.unit == null || commonData.unitBlk == null || params?.name == null) ? res
    : res.__update(xrayDescCtorsMap?[partType](partType, params, commonData) ?? {})
}

return {
  getSimpleUnitType
  xrayCommonGetters
  getDescriptionInXrayMode
}
