let { eachBlock, eachParam } = require("%sqstd/datablock.nut")
let { isModClassExpendable } = require("%scripts/weaponry/modificationInfo.nut")
let { isDataBlock, isString, appendOnce } = require("%sqStdLibs/helpers/u.nut")
let { getPresetWeapons } = require("%scripts/weaponry/weaponryPresets.nut")
let { TRIGGER_TYPE, TRIGGER_TYPE_TO_BIT, ROCKETS_WEAPON_MASK,
  BOMBS_WEAPON_MASK, getTriggerType, isGunnerTrigger
} = require("%scripts/weaponry/weaponryInfo.nut")

let weaponProperties = [
  "reqRank", "reqExp", "mass_per_sec", "mass_per_sec_diff",
  "repairCostCoef", "repairCostCoefArcade", "repairCostCoefHistorical", "repairCostCoefSimulation",
  "caliber", "deactivationIsAllowed", "isTurretBelt", "bulletsIconParam"
]

let reqNames = ["reqWeapon", "reqModification"]

let upgradeNames = ["weaponUpgrade1", "weaponUpgrade2", "weaponUpgrade3", "weaponUpgrade4"]

let function addReqParamsToWeaponry(weaponry, blk) {
  if (!isDataBlock(blk))
    return

  foreach(rp in reqNames) {
    let reqData = []
    if (rp not in blk)
      continue
    foreach (req in (blk % rp))
      if (isString(req) && req.len())
        reqData.append(req)
    if (reqData.len() > 0)
      weaponry[rp] <- reqData
  }
}

let function initWeaponsMask(unit, weapon) {
  let weponryConfig = getPresetWeapons(::get_full_unit_blk(unit.name), weapon)
  local weaponmask = 0
  foreach(weaponBlk in weponryConfig) {
    let trigger = getTriggerType(weaponBlk)
    if (trigger in TRIGGER_TYPE_TO_BIT)
      weaponmask = weaponmask | TRIGGER_TYPE_TO_BIT[trigger]
    else if (isGunnerTrigger(trigger))
      weaponmask = weaponmask | TRIGGER_TYPE_TO_BIT[TRIGGER_TYPE.GUNNER]
  }
  weapon.weaponmask <- weaponmask
  weapon.torpedo <- (weaponmask & TRIGGER_TYPE_TO_BIT[TRIGGER_TYPE.TORPEDOES]) != 0
  weapon.cannon <- (weaponmask & TRIGGER_TYPE_TO_BIT[TRIGGER_TYPE.CANNON]) != 0
  weapon.additionalGuns <- (weaponmask & TRIGGER_TYPE_TO_BIT[TRIGGER_TYPE.ADD_GUN]) != 0
  weapon.frontGun <- (weaponmask & TRIGGER_TYPE_TO_BIT[TRIGGER_TYPE.MACHINE_GUN]) != 0
  weapon.bomb <- (weaponmask & BOMBS_WEAPON_MASK) != 0
  weapon.rocket <- (weaponmask & ROCKETS_WEAPON_MASK) != 0
}

let function initWeaponry(weaponry, blk, esUnitType) {
  let weaponBlk = ::get_modifications_blk()?.modifications?[weaponry.name]
  weaponry.cost <- weaponry?.cost ?? 0
  if (blk?.value != null)
    weaponry.cost = blk.value
  if (blk?.costGold) {
    weaponry.costGold <- blk.costGold
    weaponry.cost = 0
  }
  weaponry.tier <- (blk?.tier.tointeger() ?? 1) || 1
  weaponry.modClass <- blk?.modClass ?? weaponBlk?.modClass ?? ""
  weaponry.image <- weaponry?.image ?? ::get_weapon_image(esUnitType, weaponBlk, blk)
  weaponry.requiresModelReload <- weaponBlk?.requiresModelReload ?? false
  weaponry.isHidden <- blk?.isHidden ?? weaponBlk?.isHidden ?? false
  weaponry.weaponmask <- blk?.weaponmask ?? 0

  if (weaponry.name == "tank_additional_armor")
    weaponry.requiresModelReload <- true

  foreach(p in weaponProperties) {
    let val = blk?[p] ?? weaponBlk?[p]
    if (val != null)
      weaponry[p] <- val
  }

  foreach (param in ["prevModification", "reqInstalledModification"]) {
    let val = blk?[param] ?? weaponBlk?[param]
    if (isString(val) && val.len())
      weaponry[param] <- val
  }
  addReqParamsToWeaponry(weaponry, blk)
}

let function initUnitWeapons(unit, weapons, weaponsBlk = null) {
  let { weaponsContainers, esUnitType } = unit
  foreach (weapon in weapons) {
    let weaponBlk = weaponsBlk?[weapon.name]
    initWeaponry(weapon, weaponBlk, esUnitType)

    if (unit.hasWeaponSlots) //for weapons by slot weapons mask is not inited
      initWeaponsMask(unit, weapon)
    if (weaponsContainers.len() == 0 || (weaponBlk?.sum_weapons == null))
      continue

    let reqParams = {}
    eachParam(weaponBlk.sum_weapons, function(count, name) {
      if (name not in weaponsContainers)
        return
      foreach(rp in reqNames)
        if (rp in weaponsContainers[name]) {
          reqParams[rp] <- reqParams?[rp] ?? []
          foreach (req in weaponsContainers[name][rp])
            appendOnce(req, reqParams[rp])
        }
    })
    weapon.__update(reqParams)
  }
}

let function initWeaponryUpgrades(upgradesTarget, blk) {
  foreach(upgradeName in upgradeNames) {
    if (blk?[upgradeName] == null)
      break

    if (!("weaponUpgrades" in upgradesTarget))
      upgradesTarget.weaponUpgrades <- []
    upgradesTarget.weaponUpgrades.append(::split(blk[upgradeName], "/"))
  }
}

let function initUnitModifications (modifications, modificationsBlk, esUnitType) {
  let errorsTextArray = []
  if (modificationsBlk == null)
    return errorsTextArray

  eachBlock(modificationsBlk, function(modBlk, modName) {
    let mod = { name = modName, type = ::g_weaponry_types.MODIFICATION.type }
    modifications.append(mod)
    initWeaponry(mod, modBlk, esUnitType)
    initWeaponryUpgrades(mod, modBlk)
    if (isModClassExpendable(mod))
      mod.type = ::g_weaponry_types.EXPENDABLES.type

    if (modBlk?.maxToRespawn)
      mod.maxToRespawn <- modBlk.maxToRespawn

    //validate prevModification. it used in gui only.
    if (("prevModification" in mod) && !(modificationsBlk?[mod.prevModification]))
      errorsTextArray.append(format("Not exist prevModification '%s' for '%s' (%s)",
                             delete mod.prevModification, modName, name))
  })
  return errorsTextArray
}

let function initUnitWeaponsContainers(weaponsContainers, weaponsBlk) {
  eachBlock(weaponsBlk, function(weaponBlk, weaponName) {
    if (!(weaponBlk?.isWeaponForCustomSlot ?? false))
      return
    weaponsContainers[weaponName] <- {}
    addReqParamsToWeaponry(weaponsContainers[weaponName], weaponBlk)
  })
}

return {
  initUnitWeapons
  initWeaponryUpgrades
  initUnitModifications
  initUnitWeaponsContainers
}


