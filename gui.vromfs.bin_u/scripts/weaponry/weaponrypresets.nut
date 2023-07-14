//checked for plus_string
from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")

let { blkOptFromPath } = require("%sqStdLibs/helpers/datablockUtils.nut")

const MIN_TIERS_COUNT = 13
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
  && a?.flash == b?.flash
  && a?.emitter == b?.emitter

let function addSlotWeaponsFromPreset(res, slotBlk, preset, tiersCount, isEqualFunc = isEqualWeapon) {
  foreach (weapon in (preset % "Weapon")) {
    let slotWeapon = u.copy(weapon)
    slotWeapon.presetId = preset.name
    slotWeapon.slot = slotBlk.index
    slotWeapon.tier = slotBlk?.tier ?? (tiersCount - 1 - slotBlk.index)
    slotWeapon.iconType = preset?.iconType
    slotWeapon.showInWeaponMenu  = preset?.showInWeaponMenu ?? false
    foreach (dependentWeapon in (preset % "DependentWeaponPreset"))
      slotWeapon.dependentWeaponPreset <- dependentWeapon
    foreach (bannedWeapon in (preset % "BannedWeaponPreset"))
      slotWeapon.bannedWeaponPreset  <- bannedWeapon
    slotWeapon.reqModification = preset?.reqModification
    let idx = res.findindex(@(w) isEqualFunc(w, slotWeapon))
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
    slots = slots.filter(@(s) s?.tier != null) // Pesets weapon only
  if (slots.len() > 0) { // CUSTOM data type
    let unitName = unitBlk?.model // warning disable: -declared-never-used
    foreach (wp in (weaponsBlk % "Weapon")) {
      let slotIdx = wp.slot
      let slot = slots.findvalue(@(s) s.index == slotIdx)
      if (!slot) {
        logerr($"[WeaponSlots] Unit {unitName}: WeaponSlot index {slotIdx} does not exist")
        continue
      }
      let presetName = wp.preset
      let curPreset = (slot % "WeaponPreset").findvalue(@(s) s.name == presetName)
      if (curPreset == null) {
        logerr($"[WeaponSlots] Unit {unitName}, preset {presetName}: WeaponPreset does not exist")
        continue
      }

      addSlotWeaponsFromPreset(res, slot, curPreset, unitBlk?.WeaponSlots?.weaponsSlotCount ?? MIN_TIERS_COUNT)
    }
  }
  // !!!FIX ME: Processing old format of weapons data should be removed over time when all units presets get ability to be customized.
  else // PLAIN data type
    foreach (weapon in (weaponsBlk % "Weapon"))
      u.appendOnce((u.copy(weapon)), res)

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

let function getSlotWeapons(slotBlk, tiersCount = MIN_TIERS_COUNT) {
  let res = []
  if (slotBlk == null)
    return res

  foreach (preset in ((slotBlk % "WeaponPreset")))
    addSlotWeaponsFromPreset(res, slotBlk, preset, tiersCount)
  return res
}

let function getUnitWeapons(unitBlk) { // Pesets weapon only
  let res = []
  let slots = getUnitWeaponSlots(unitBlk).filter(@(s) s?.tier != null)
  if (slots.len() > 0)
    foreach (slot in slots)
      res.extend(getSlotWeapons(slot, unitBlk?.WeaponSlots?.weaponsSlotCount ?? MIN_TIERS_COUNT))
  else
    foreach (preset in getUnitPresets(unitBlk))
      foreach (weapon in getPresetWeaponsByPath(unitBlk, preset.blk)) {
          let w = u.copy(weapon)
          w.presetId <- preset.name
          u.appendOnce(w, res)
      }

  return res
}

let isEqualEditSlots = @(a, b) a.slot == b.slot
  && a.tier == b.tier
  && a.presetId == b.presetId
  && a?.blk == b?.blk

let function getSlotsWeaponsForEditPreset(unitBlk) {
  let res = []
  let slots = getUnitWeaponSlots(unitBlk).filter(@(s) s?.tier != null)
  foreach (slot in slots) {
    let slotWeapons = []
    foreach (preset in (slot % "WeaponPreset"))
      addSlotWeaponsFromPreset(slotWeapons, slot, preset, unitBlk?.WeaponSlots?.weaponsSlotCount ?? MIN_TIERS_COUNT, isEqualEditSlots)
    res.extend(slotWeapons)
  }

  return res
}

let function getWeaponBlkParams(weaponBlkPath, weaponBlkCache, params = {}) {
  let self = callee()
  let { containersCount = 1, containerMassKg = 0 } = params
  local { bulletsCount = 1 } = params

  let weaponBlk = weaponBlkCache?[weaponBlkPath] ?? blkOptFromPath(weaponBlkPath)
  weaponBlkCache[weaponBlkPath] <- weaponBlk

  bulletsCount = bulletsCount * (weaponBlk?.bullets ?? 1)
  if (weaponBlk?.container && ("blk" in weaponBlk)) {
    let containerParams = {
      bulletsCount,
      containersCount = weaponBlk?.bullets ?? 1
      containerMassKg = containerMassKg + (weaponBlk?.mass ?? 0) * containersCount
    }

    return self(weaponBlk.blk, weaponBlkCache, containerParams)
  }

  return {
    weaponBlk
    weaponBlkPath
    bulletsCount
    containerMassKg
  }
}

let function getUnitWeaponsByTier(unit, blkPath, tierId) {
    let unitBlk = ::get_full_unit_blk(unit.name)
    let tiersCount = unitBlk?.WeaponSlots?.weaponsSlotCount ?? MIN_TIERS_COUNT

    return unit.hasWeaponSlots
    ? (getSlotWeapons(getUnitWeaponSlots(unitBlk).findvalue(
        @(s) s?.tier == tierId), tiersCount).filter(@(w) getWeaponBlkParams(w.blk, {}).weaponBlkPath == blkPath)
        ?? [])
    : null
  }

let function getUnitWeaponsByPreset(unit, blkPath, presetName) {
  let unitBlk = ::get_full_unit_blk(unit.name)
  if (unit.hasWeaponSlots) {
    local res = []
    foreach (slot in getUnitWeaponSlots(unitBlk))
      foreach (weapon in getSlotWeapons(slot, unitBlk?.WeaponSlots?.weaponsSlotCount ?? MIN_TIERS_COUNT))
        if (getWeaponBlkParams(weapon.blk, {}).weaponBlkPath == blkPath
          && weapon.presetId == presetName)
          res.append(weapon)
    return res
  }

  return getPresetWeaponsByPath(unitBlk, getUnitPresets(unitBlk).findvalue(
    @(p) p.name == presetName).blk).filter(@(w) w.blk == blkPath) ?? []
}

let function getDefaultPresetId(unitBlk) {
  foreach (block in getUnitPresets(unitBlk))
    if (block.name.indexof("default") != null || block?.tags?.free)
      return block.name
  return null
}

let createNameCustomPreset = @(idx) loc("shop/slotbarPresets/item", { number = idx + 1 })

let getDefaultCustomPresetParams = @(idx) {
  name              = $"{CUSTOM_PRESET_PREFIX}{idx}"
  customNameText    = createNameCustomPreset(idx)
  tiers             = {}
}

let isCustomPreset = @(preset) (preset.name ?? "").indexof(CUSTOM_PRESET_PREFIX) != null

return {
  MIN_TIERS_COUNT
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
  getWeaponBlkParams
  getUnitWeaponsByTier
  getUnitWeaponsByPreset
  getSlotsWeaponsForEditPreset
}
