from "%scripts/dagui_library.nut" import *

let { isWeaponAux, getLastWeapon, getLastPrimaryWeapon } = require("%scripts/weaponry/weaponryInfo.nut")
let { getModificationByName } = require("%scripts/weaponry/modificationInfo.nut")
let { getWeaponInfoText, makeWeaponInfoData } = require("%scripts/weaponry/weaponryDescription.nut")
let { blkFromPath, blkOptFromPath } = require("%sqstd/datablock.nut")
let { getPresetWeapons, getWeaponBlkParams } = require("%scripts/weaponry/weaponryPresets.nut")
let { getFullUnitBlk } = require("%scripts/unit/unitParams.nut")
let { getUpgradeTypeByItem } = require("%scripts/weaponry/weaponryTypes.nut")

const USE_DELAY_EXPLOSION_DEFAULT = true

function getUnitMassPerSecValue(unit, showLocalState = true, lastWeapon = null) {
  let lastPrimaryWeaponName = showLocalState ? getLastPrimaryWeapon(unit) : ""
  let lastPrimaryWeapon = getModificationByName(unit, lastPrimaryWeaponName)
  let weapons = unit.getWeapons()

  local massPerSecValue = lastPrimaryWeapon?.mass_per_sec_diff ?? 0

  if (weapons.len() == 0)
    return massPerSecValue

  lastWeapon = lastWeapon ?? (showLocalState ? getLastWeapon(unit.name) : "")

  foreach (_idx, weapon in weapons) {
    if (lastWeapon != weapon.name || isWeaponAux(weapon))
      continue
    if ("mass_per_sec" in weapon)
      return massPerSecValue + weapon.mass_per_sec
    break
  }

  if (lastWeapon == "")
    massPerSecValue += weapons[0]?.mass_per_sec ?? 0

  return massPerSecValue
}

function getUnitWeaponPresetsCount(unit) {
  return unit.getWeapons().filter(@(w) !isWeaponAux(w)).len()
}

function getCurrentPreset(unit) {
  let secondaryWep = getLastWeapon(unit?.name ?? "")
  return secondaryWep != "" ? unit.getWeapons().findvalue(@(w) w.name == secondaryWep) : null
}

function bombNbr(unit) {
  if (unit == null)
    return -1

  return getCurrentPreset(unit)?.bombsNbr ?? -1
}

function isUnitHaveSecondaryWeapons(unit) {
  local foundWeapon = false
  foreach (weapon in unit.getWeapons())
    if (!isWeaponAux(weapon))
      if (foundWeapon)
        return true
      else
        foundWeapon = true

  let weaponInfoParams = { isPrimary = false, weaponPreset = 0, needTextWhenNoWeapons = false }
  return "" != getWeaponInfoText(unit, makeWeaponInfoData(unit, weaponInfoParams))
}

function isShipWithoutPurshasedTorpedoes(unit) {
  if (!unit?.isShipOrBoat())
    return false

  local torpedoes = null
  if (isUnitHaveSecondaryWeapons(unit))
    torpedoes = unit.getWeapons().findvalue(@(weapon) weapon.name == "torpedoes")    

  if (!torpedoes)
    return false

  if (getUpgradeTypeByItem(torpedoes).getAmount(unit, torpedoes) > 0)
    return false

  return true
}

let availablePrimaryWeaponsMod = {}
let defaultPrimaryWeaponsMod = {
  flares = null,
  chaffs = null
}

function isAvailablePrimaryWeapon(unit, weaponName) {
  local availableWeapons = availablePrimaryWeaponsMod?[unit.name]
  if (availableWeapons != null)
    return getLastPrimaryWeapon(unit) == availableWeapons[weaponName]

  let unitBlk = getFullUnitBlk(unit.name)
  if (!unitBlk)
    return false

  availableWeapons = clone defaultPrimaryWeaponsMod
  if (unitBlk?.modifications != null) {
    let modificationsCount = unitBlk.modifications.blockCount()
    for (local i = 0; i < modificationsCount; i++) {
      let modification = unitBlk.modifications.getBlock(i)
      let modName = modification.getBlockName()
      let commonWeapons = modification?.effects.commonWeapons
      if (commonWeapons == null)
        continue
      foreach (weap in (commonWeapons % "Weapon")) {

        let weapons = []
        if (unitBlk?.WeaponSlots != null) {
          foreach (weaponSlot in (unitBlk.WeaponSlots % "WeaponSlot")) {
            if (weap?.slot == weaponSlot?.index) {
              foreach (weaponPreset in (weaponSlot % "WeaponPreset")) {
                if (weap?.preset == weaponPreset?.name) {
                  foreach (weapon in (weaponPreset % "Weapon"))
                    weapons.append(weapon)
                  break
                }
              }
              break
            }
          }
        }
        else
          weapons.append(weap)

        foreach (weapon in weapons) {
          if (!weapon?.blk || weapon?.dummy)
            continue
          let weapBlk = blkFromPath(weapon.blk)
          if (availableWeapons != null && (weapBlk?.rocket.isFlare ?? false))
            availableWeapons.flares = modName
          if (availableWeapons != null && (weapBlk?.rocket.isChaff ?? false))
            availableWeapons.chaffs = modName
          if (availableWeapons != null && (weapBlk?.bullet.rocket.isChaff ?? false))
            availableWeapons.chaffs = modName
          if (availableWeapons != null && (weapBlk?.bullet.rocket.isFlare ?? false))
            availableWeapons.flares = modName
        }
      }
    }
  }
  availablePrimaryWeaponsMod[unit.name] <- availableWeapons
  return getLastPrimaryWeapon(unit) == availableWeapons[weaponName]
}

function hasCountermeasures(unit) {
  if (unit == null)
    return false

  return (getCurrentPreset(unit)?.hasCountermeasures ?? false)
    || isAvailablePrimaryWeapon(unit, "flares") || isAvailablePrimaryWeapon(unit, "chaffs")
}

function hasBombDelayExplosion(unit) {
  if (!unit?.isAir() && !unit?.isHelicopter())
    return false

  let curPreset = getCurrentPreset(unit)
  if (!curPreset?.bomb)
    return false

  let unitBlk = getFullUnitBlk(unit.name)
  let weapons = getPresetWeapons(unitBlk, curPreset)
  let weaponCache = {}

  foreach(weapon in weapons) {
    let params = getWeaponBlkParams(weapon.blk, weaponCache)
    if ((params?.weaponBlk.bomb.useDelayExplosion ?? USE_DELAY_EXPLOSION_DEFAULT))
      return true
  }

  return false
}

let unitSensorsCache = {}
function isUnitWithSensorType(unit, sensorType) {
  if (!unit)
    return false
  let unitName = unit.name
  if (unitName in unitSensorsCache)
    return unitSensorsCache[unitName]?[sensorType] ?? false

  unitSensorsCache[unitName] <- {}
  let unitBlk = getFullUnitBlk(unit.name)
  if (unitBlk?.sensors)
    foreach (sensor in (unitBlk.sensors % "sensor")) {
      let sensType = blkOptFromPath(sensor?.blk)?.type ?? ""
      if (sensType != "")
        unitSensorsCache[unitName][sensType] <- true
    }
  return unitSensorsCache[unitName]?[sensorType] ?? false
}

let isUnitWithRadar = @(unit) isUnitWithSensorType(unit, "radar")

let isUnitWithRwr = @(unit) isUnitWithSensorType(unit, "rwr")

return {
  getUnitMassPerSecValue
  getUnitWeaponPresetsCount
  getCurrentPreset
  bombNbr
  isUnitHaveSecondaryWeapons
  isShipWithoutPurshasedTorpedoes
  hasCountermeasures
  hasBombDelayExplosion
  isUnitWithRadar
  isUnitWithRwr
}