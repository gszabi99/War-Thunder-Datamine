let mkWatched = require("%globalScripts/mkWatched.nut")
let DataBlock = require("DataBlock")
let { initUnitWeapons } = require("%scripts/unit/initUnitWeapons.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { getCustomWpnPresetBlk, charSendBlk } = require("chard")

let customPresetsConfigByUnit = mkWatched(persist, "customPresetsConfigByUnit", {})
let customPresetsByUnit = mkWatched(persist, "customPresetsByUnit", {})

let function loadCustomPresets(unitName) {
  if (!::g_login.isProfileReceived())
    return

  let blk = DataBlock()
  let customPresets = getCustomWpnPresetBlk(-1, unitName)
  if (customPresets != null)
    blk.setFrom(customPresets)
  customPresetsConfigByUnit.mutate(@(val) val[unitName] <- blk)
}

let invalidateUnitCustomPresetsCache  = @(unit) customPresetsByUnit.mutate(@(val) delete val[unit.name])

let function invalidateCache() {
  customPresetsConfigByUnit({})
  customPresetsByUnit({})
}

let function savePresetInProfile(unit, id, presetBlk) {
  let blk = DataBlock()
  blk.addBlock(unit.name).addBlock(id).setFrom(presetBlk)
  charSendBlk("cln_save_weapon_presets", blk)
}

let function updateLocalCustomPresets(unit, presets) {
  customPresetsConfigByUnit.mutate(@(val) val[unit.name] <- presets)
  invalidateUnitCustomPresetsCache(unit)
}

let function getCustomPresetsConfig(unit) {
  if (!unit.hasWeaponSlots)
    return {}

  if (unit.name not in customPresetsConfigByUnit.value)
    loadCustomPresets(unit.name)

  return customPresetsConfigByUnit.value[unit.name]
}

let function addCustomPresets(unit, id, presetBlk) {
  let presets = getCustomPresetsConfig(unit)
  presets[id] = presetBlk
  updateLocalCustomPresets(unit, presets)
  savePresetInProfile(unit, id, presetBlk)
}

let function deleteCustomPresets(unit, id) {
  let presets = getCustomPresetsConfig(unit)
  if (id not in presets)
    return

  presets.removeBlock(id)
  updateLocalCustomPresets(unit, presets)
  let blk = DataBlock()
  blk.addBlock(id)
  savePresetInProfile(unit, id, blk)
}

let function initCustomPreset(unit) {
  let presetConfig = getCustomPresetsConfig(unit)
  let weapons = []
  foreach (presetName, preset in presetConfig) {
    weapons.append({
      name = presetName
      weaponsBlk = preset
      tags = []
      cost = 0
      type = weaponsItem.weapon
      nameTextWithPrice = preset?.name ?? ""
      torpedo = false
      cannon = false
      additionalGuns = false
      frontGun = false
      bomb = false
      rocket = false
    })
  }

  initUnitWeapons(weapons, null, unit.esUnitType, unit.weaponsContainers)
  customPresetsByUnit.mutate(@(val) val[unit.name] <- weapons)
}

let function getWeaponryCustomPresets(unit) {
  if (!unit.hasWeaponSlots)
    return []

  if (unit.name not in customPresetsByUnit.value)
    initCustomPreset(unit)

  return customPresetsByUnit.value[unit.name]
}

addListenersWithoutEnv({
  SignOut = @(p) invalidateCache()
  ProfileReceived = @(p) invalidateCache()
}, ::g_listener_priority.CONFIG_VALIDATION)


return {
  addCustomPresets
  deleteCustomPresets
  getWeaponryCustomPresets
}

