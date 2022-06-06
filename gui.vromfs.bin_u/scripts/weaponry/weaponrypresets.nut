let { blkOptFromPath } = require("%sqStdLibs/helpers/datablockUtils.nut")

const TIERS_NUMBER = 13
const MAX_PRESETS_NUM = 20
const CUSTOM_PRESET_PREFIX = "custom"
let CHAPTER_ORDER = ["NONE", "FAVORITE", "UNIVERSAL", "AIR_TO_AIR", "AIR_TO_GROUND", "AIR_TO_SEA", "ARMORED", "CUSTOM"]
let CHAPTER_FAVORITE_IDX = CHAPTER_ORDER.findindex(@(p) p == "FAVORITE")
let CHAPTER_NEW_IDX = CHAPTER_ORDER.findindex(@(p) p == "CUSTOM")

let isEqualWeapon = @(a, b) a.slot == b.slot
  && a.tier == b.tier
  && a.presetId == b.presetId
  && a?.blk == b?.blk
  && a?.dm == b?.dm

let getTierIdxBySlot = @(slot) TIERS_NUMBER - 1 - slot

let function addSlotWeaponsFromPreset(res, slotBlk, preset) {
  foreach (weapon in (preset % "Weapon")) {
    let slotWeapon = ::u.copy(weapon)
    slotWeapon.presetId = preset.name
    slotWeapon.slot = slotBlk.index
    slotWeapon.tier = slotBlk?.tier ?? getTierIdxBySlot(slotBlk.index)
    slotWeapon.iconType = preset?.iconType
    foreach (dependentWeapon in (preset % "DependentWeaponPreset"))
      slotWeapon.dependentWeaponPreset <- dependentWeapon
    foreach (bannedWeapon in (preset % "BannedWeaponPreset"))
      slotWeapon.bannedWeaponPreset  <- bannedWeapon
    slotWeapon.reqModification = preset?.reqModification
    let idx = res.findindex(@(w) isEqualWeapon(w, slotWeapon))
    if (idx == null)
      res.append(slotWeapon)
    else
      res[idx].bullets = (res[idx]?.bullets ?? 1) + (slotWeapon?.bullets ?? 1)
  }
}

let getUnitWeaponSlots = @(blk)(blk?.WeaponSlots == null ? [] : blk.WeaponSlots % "WeaponSlot")
// For now weapon data can be two different types
// depends of whether or not unit config contains the weaponPilons block.
let function getWeaponsByTypes(unitBlk, weaponsBlk, isCommon = true) {
  let res = []
  local slots = getUnitWeaponSlots(unitBlk)             // All unit weapons
  if (!isCommon)
    slots = slots.filter(@(s) s?.tier != null)// Pesets weapon only
  if (slots.len() > 0) {// CUSTOM data type
    let unitName = unitBlk?.model // warning disable: -declared-never-used
    foreach (wp in (weaponsBlk % "Weapon")) {
      let slotIdx = wp.slot
      let slot = slots.findvalue(@(s) s.index == slotIdx)
      if (!slot) {
        ::script_net_assert_once("WeaponSlots", $"WeaponSlot index does not exist")
        continue
      }
      let presetName = wp.preset
      let curPreset = (slot % "WeaponPreset").findvalue(@(s) s.name == presetName)
      if (curPreset == null) {
        ::script_net_assert_once("WeaponSlots", $"WeaponPreset does not exist")
        continue
      }

      addSlotWeaponsFromPreset(res, slot, curPreset)
    }
  }
  // !!!FIX ME: Processing old format of weapons data should be removed over time when all units presets get ability to be customized.
  else// PLAIN data type
    foreach (weapon in (weaponsBlk % "Weapon"))
      ::u.appendOnce((::u.copy(weapon)), res)

  return res
}

let getPresetWeaponsByPath = @(unitBlk, blkPath) (blkPath == "" || blkPath == null) ? []
  : getWeaponsByTypes(unitBlk, blkOptFromPath(blkPath), false)

let getUnitPresets = @(unitBlk)  (unitBlk?.weapon_presets != null)
  ? (unitBlk.weapon_presets % "preset") : []

let getPresetWeaponsByName = @(unitBlk, name)
  getPresetWeaponsByPath(unitBlk, getUnitPresets(unitBlk).findvalue(@(p) p.name == name)?.blk)

let getPresetWeapons = @(unitBlk, weapon) weapon == null ? []
  : "weaponsBlk" in weapon ? getWeaponsByTypes(unitBlk, weapon.weaponsBlk)
  : getPresetWeaponsByName(unitBlk, weapon.name)

let function getSlotWeapons(slotBlk) {
  let res = []
  if (slotBlk == null)
    return res

  foreach (preset in ((slotBlk % "WeaponPreset")))
    addSlotWeaponsFromPreset(res, slotBlk, preset)
  return res
}

let function getUnitWeapons(unitBlk) {// Pesets weapon only
  let res = []
  let slots = getUnitWeaponSlots(unitBlk).filter(@(s) s?.tier != null)
  if(slots.len() > 0)
    foreach (slot in slots)
      res.extend(getSlotWeapons(slot))
  else
    foreach (preset in getUnitPresets(unitBlk))
      foreach (weapon in getPresetWeaponsByPath(unitBlk, preset.blk)) {
          let w = ::u.copy(weapon)
          w.presetId <- preset.name
          ::u.appendOnce(w, res)
        }

  return res
}

let function getDefaultPresetId(unitBlk) {
  foreach (block in getUnitPresets(unitBlk))
    if (block.name.indexof("default") != null || block?.tags?.free)
      return block.name
  return null
}

let createNameCustomPreset = @(idx) ::loc("shop/slotbarPresets/item", { number = idx + 1 })

let getDefaultCustomPresetParams = @(idx) {
  name              = $"{CUSTOM_PRESET_PREFIX}{idx}"
  customNameText    = createNameCustomPreset(idx)
  tiers             = {}
}

let isCustomPreset = @(preset) (preset.name ?? "").indexof(CUSTOM_PRESET_PREFIX) != null

return {
  TIERS_NUMBER
  MAX_PRESETS_NUM
  CHAPTER_ORDER
  CHAPTER_NEW_IDX
  CHAPTER_FAVORITE_IDX
  CUSTOM_PRESET_PREFIX
  getUnitWeapons
  getUnitPresets
  getWeaponsByTypes
  getPresetWeapons
  getDefaultPresetId
  getUnitWeaponSlots
  getDefaultCustomPresetParams
  isCustomPreset
  getSlotWeapons
  getPresetWeaponsByPath
}
