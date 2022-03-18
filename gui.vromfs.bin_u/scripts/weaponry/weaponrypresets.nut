let { blkOptFromPath } = require("sqStdLibs/helpers/datablockUtils.nut")

const TIERS_NUMBER = 13

let getUnitWeaponSlots = @(blk)(blk?.WeaponSlots == null ? [] : blk.WeaponSlots % "WeaponSlot")
// For now weapon data can be two different types
// depends of whether or not unit config contains the weaponPilons block.
let function getWeaponsByTypes(weaponsBlk, unitBlk, isCommon = true) {
  let res = []
  local slots = getUnitWeaponSlots(unitBlk)             // All unit weapons
  if (!isCommon)
    slots = slots.filter(@(_) _?.tier != null)// Pesets weapon only
  if (slots.len() > 0)// CUSTOM data type
    foreach (wp in (weaponsBlk % "Weapon")) {
      let slot = slots.findvalue(@(_) _.index == wp.slot)
      if (!slot) {
        ::script_net_assert_once("WeaponSlots", $"WeaponSlot index {wp.slot} does not exist")
        continue
      }
      let curPreset = (slot % "WeaponPreset").findvalue(@(_) _.name == wp.preset)
      if (curPreset == null) {
        ::script_net_assert_once("WeaponSlots", $"WeaponPreset name {wp.preset} does not exist")
        continue
      }

      foreach (weapon in (curPreset % "Weapon")) {
        let slotWeapon = ::u.copy(weapon)
        slotWeapon.slot = wp.slot
        slotWeapon.presetId = wp.preset
        ::u.appendOnce(slotWeapon, res)
      }
    }
  // !!!FIX ME: Processing old format of weapons data should be removed over time when all units presets get ability to be customized.
  else// PLAIN data type
    foreach (weapon in (weaponsBlk % "Weapon"))
      ::u.appendOnce((::u.copy(weapon)), res)

  return res
}

let getPresetWeapons = @(blkPath, unitBlk)(blkPath == "" || blkPath == null) ? []
  : getWeaponsByTypes(blkOptFromPath(blkPath), unitBlk, false)

let getUnitPresets = @(blk)  (blk?.weapon_presets != null) ? (blk.weapon_presets % "preset") : []

let getWeaponsByPresetName = @(unitBlk, name)
  getPresetWeapons(getUnitPresets(unitBlk)?.findvalue(@(_) _.name == name).blk, unitBlk)

let function getUnitWeapons(unitBlk) {
  let res = []
  let slots = getUnitWeaponSlots(unitBlk).filter(@(_) _?.tier != null)// Pesets weapon only
  if(slots.len() > 0)
    foreach (slot in slots)
      foreach (preset in ((slot % "WeaponPreset")))
        foreach (weapon in (preset % "Weapon")) {
          let w = ::u.copy(weapon)
          w.presetId <- preset.name
          ::u.appendOnce(w, res)
        }
  else
    foreach (preset in getUnitPresets(unitBlk))
      foreach (weapon in getPresetWeapons(preset.blk, unitBlk)) {
          let w = ::u.copy(weapon)
          w.presetId <- preset.name
          ::u.appendOnce(w, res)
        }

  return res
}

let function getDefaultPresetId(blk) {
  foreach (block in getUnitPresets(blk))
    if (block.name.indexof("default") != null || block?.tags?.free)
      return block.name
  return null
}

let getTierIdxBySlot = @(slot) TIERS_NUMBER - 1 - slot

return {
  TIERS_NUMBER
  getUnitWeapons
  getUnitPresets
  getWeaponsByTypes
  getWeaponsByPresetName
  getDefaultPresetId
  getTierIdxBySlot
}
