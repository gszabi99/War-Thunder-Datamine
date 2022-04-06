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

let getTierIdxBySlot = @(slot) TIERS_NUMBER - 1 - slot

let function addSlotWeaponsFromPreset(res, slotBlk, preset) {
  foreach (weapon in (preset % "Weapon")) {
    let slotWeapon = ::u.copy(weapon)
    slotWeapon.presetId = preset.name
    slotWeapon.slot = slotBlk.index
    slotWeapon.tier = slotBlk?.tier ?? getTierIdxBySlot(slotBlk.index)
    slotWeapon.iconType = preset?.iconType
    let idx = res.findindex(@(w) isEqualWeapon(w, slotWeapon))
    if (idx == null)
      res.append(slotWeapon)
    else
      res[idx].bullets = (res[idx].bullets ?? 1) + (slotWeapon?.bullets ?? 1)
  }
}

let getUnitWeaponSlots = @(blk)(blk?.WeaponSlots == null ? [] : blk.WeaponSlots % "WeaponSlot")
// For now weapon data can be two different types
// depends of whether or not unit config contains the weaponPilons block.
let function getWeaponsByTypes(unitBlk, weaponsBlk, isCommon = true) {
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

      addSlotWeaponsFromPreset(res, slot, curPreset)
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
  getPresetWeaponsByPath(unitBlk, getUnitPresets(unitBlk).findvalue(@(_) _.name == name)?.blk)

let getPresetWeapons = @(unitBlk, weapon) weapon == null ? []
  : "weaponsBlk" in weapon ? getWeaponsByTypes(unitBlk, weapon.weaponsBlk)
  : getPresetWeaponsByName(unitBlk, weapon.name)

let function getSlotWeapons(slotBlk) {
  let res = []
  foreach (preset in ((slotBlk % "WeaponPreset")))
    addSlotWeaponsFromPreset(res, slotBlk, preset)
  return res
}

let function getUnitWeapons(unitBlk) {// Pesets weapon only
  let res = []
  let slots = getUnitWeaponSlots(unitBlk).filter(@(_) _?.tier != null)
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

let function updateTiersActivity(tiers, weapons) {
  for (local i = 0; i < TIERS_NUMBER; i++)
    tiers[i].__update({
      isActive = weapons.findvalue(@(_)_.tier == i) != null
    })
}

let function createNewTiers(weapons) {
  local res = []
  for (local i = 0; i < TIERS_NUMBER; i++)
    res.append({
      tierId = i
      isActive = weapons.findvalue(@(_)_.tier == i) != null
    })
  return res
}

let createNameCustomPreset = @(idx) ::loc("shop/slotbarPresets/item", { number = idx + 1 })

let createNewPreset = @(idx) {
  id                = $"{CUSTOM_PRESET_PREFIX}{idx}"
  cost              = null
  image             = ""
  totalItemsAmount  = 0
  totalMass         = 0
  purposeType       = null
  chapterOrd        = CHAPTER_NEW_IDX
  isDefault         = false
  isEnabled         = false
  rank              = null
  customNameText    = createNameCustomPreset(idx)
  torpedo           = false
  cannon            = false
  additionalGuns    = false
  frontGun          = false
  bomb              = false
  rocket            = false
  tiers             = {}
}

let isCustomPreset = @(preset) (preset?.id ?? preset.name ?? "").indexof(CUSTOM_PRESET_PREFIX) != null

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
  createNewPreset
  createNameCustomPreset
  createNewTiers
  updateTiersActivity
  isCustomPreset
}
