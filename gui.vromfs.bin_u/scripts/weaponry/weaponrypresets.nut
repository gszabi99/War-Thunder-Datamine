let { blkOptFromPath } = require("%sqStdLibs/helpers/datablockUtils.nut")

const TIERS_NUMBER = 13
const MAX_PRESETS_NUM = 20
const CUSTOM_PRESET_PREFIX = "custom"
let CHAPTER_ORDER = ["NONE", "FAVORITE", "UNIVERSAL", "AIR_TO_AIR", "AIR_TO_GROUND", "AIR_TO_SEA", "ARMORED", "CUSTOM"]
let CHAPTER_FAVORITE_IDX = CHAPTER_ORDER.findindex(@(p) p == "FAVORITE")
let CHAPTER_NEW_IDX = CHAPTER_ORDER.findindex(@(p) p == "CUSTOM")

let getTierIdxBySlot = @(slot) TIERS_NUMBER - 1 - slot

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
        slotWeapon.tier = slot?.tier ?? getTierIdxBySlot(wp.slot)
        slotWeapon.iconType = curPreset?.iconType
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

let getUnitPresets = @(unitBlk)  (unitBlk?.weapon_presets != null)
  ? (unitBlk.weapon_presets % "preset") : []

let getWeaponsByPresetName = @(unitBlk, name)
  getPresetWeapons(getUnitPresets(unitBlk)?.findvalue(@(_) _.name == name).blk, unitBlk)

let function getSlotWeapons(slotBlk) {
  let res = []
  foreach (preset in ((slotBlk % "WeaponPreset")))
    foreach (weapon in (preset % "Weapon")) {
      let w = ::u.copy(weapon)
      w.presetId <- preset.name
      w.slot <- slotBlk.index
      w.tier <- slotBlk?.tier
      ::u.appendOnce(w, res)
    }
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
      foreach (weapon in getPresetWeapons(preset.blk, unitBlk)) {
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
  nameTextWithPrice = createNameCustomPreset(idx)
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
  getWeaponsByPresetName
  getDefaultPresetId
  getUnitWeaponSlots
  getSlotWeapons
  createNewPreset
  createNameCustomPreset
  createNewTiers
  updateTiersActivity
  isCustomPreset
}
