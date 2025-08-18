from "math" import min
let { logerr } = require("dagor.debug")
let { get_wpcost_blk, get_warpoints_blk } = require("blkGetters")

function getPresetRewardMul(unitName, weaponDamage, shouldUsePremMul = true) {
  local presetRewardMul = 1.0
  if (weaponDamage <= 0)
    return presetRewardMul

  let mulsBlk = get_warpoints_blk()?.BombingRewardMultipliers
  let presetDmgMin = mulsBlk?.presetDmgMin ?? 0.0
  let presetDmgMax = mulsBlk?.presetDmgMax ?? 1.0
  let bombingRewardModifier = mulsBlk?.bombingRewardModifier ?? 1.0
  let fighterBombingRewardMul = mulsBlk?.fighterBombingRewardMul ?? 1.0
  let premBombingRewardMul = mulsBlk?.premBombingRewardMul ?? 1.0

  if (presetDmgMin <= 1) {
    logerr("ERROR. BombingRewardMultipliers.presetDmgMin must exist and be bigger than one!")
    return presetRewardMul
  }

  if (presetDmgMax <= presetDmgMin) {
    logerr($"ERROR. BombingRewardMultipliers.presetDmgMin must exist and be bigger than presetDmgMin = {presetDmgMin}")
    return presetRewardMul
  }

  if (bombingRewardModifier <= 1) {
    logerr("ERROR. BombingRewardMultipliers.bombingRewardModifier must exist and be bigger than one!")
    return presetRewardMul
  }

  let presetDmgScale = 1 + (bombingRewardModifier - 1) * (weaponDamage - presetDmgMin) / (presetDmgMax - presetDmgMin)
  presetRewardMul = presetDmgScale * presetDmgMin / weaponDamage

  let wpcostBlk = get_wpcost_blk()
  if (shouldUsePremMul) {
    let isPremUnit = wpcostBlk?[unitName].costGold != null
    if (isPremUnit)
      presetRewardMul *= premBombingRewardMul
  }

  presetRewardMul = min(presetRewardMul, 1.0)

  let unitClass = wpcostBlk?[unitName].unitClass ?? ""
  if (unitClass == "exp_fighter")
    presetRewardMul *= fighterBombingRewardMul

  return presetRewardMul
}

function getWeaponDamage(unitName, presetName, weaponTable) {
  local weaponDamage = 0
  if (weaponTable != null && weaponTable.len() > 0) {
    let weaponsBlk = get_wpcost_blk()?[unitName].weapons
    if (weaponsBlk == null)
      return weaponDamage

    foreach (weaponName, count in weaponTable) {
      weaponDamage += (weaponsBlk?[weaponName].weaponDamage ?? 0) * count
    }
  }
  else {
    weaponDamage = get_wpcost_blk()?[unitName].weapons[presetName].weaponDamage ?? 0
  }

  return weaponDamage
}

return {
  getPresetRewardMul
  getWeaponDamage
}
