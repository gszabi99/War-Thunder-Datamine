let mkWatched = require("%globalScripts/mkWatched.nut")
let DataBlock = require("DataBlock")
let { initUnitCustomPresetsWeapons } = require("%scripts/unit/initUnitWeapons.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { getCustomWpnPresetBlk, charSendBlk } = require("chard")
let { getLastWeapon } = require("%scripts/weaponry/weaponryInfo.nut")

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

let function invalidateCache() {
  customPresetsConfigByUnit({})
  customPresetsByUnit({})
}

let function invalidateUnitCache(unit) {
  customPresetsConfigByUnit.mutate(@(val) val.rawdelete(unit.name))
  customPresetsByUnit.mutate(@(val) val.rawdelete(unit.name))
}

let function savePresetInProfile(unit, id, presetBlk, successCb) {
  let blk = DataBlock()
  blk.addBlock(unit.name).addBlock(id).setFrom(presetBlk)
  let function taskSuccessCb() {
    invalidateUnitCache(unit)
    successCb()
  }
  let taskId = charSendBlk("cln_save_weapon_presets", blk)
  ::g_tasker.addTask(taskId, { showProgressBox = true }, taskSuccessCb)
}

let function getCustomPresetsConfig(unit) {
  if (!unit.hasWeaponSlots)
    return {}

  if (unit.name not in customPresetsConfigByUnit.value)
    loadCustomPresets(unit.name)

  return customPresetsConfigByUnit.value?[unit.name] ?? []
}

let function convertPresetToBlk(preset) {
  let presetBlk = DataBlock()
  presetBlk["name"] = preset.customNameText ?? ""
  foreach (tier in preset.tiers) {
    let weaponBlk = presetBlk.addNewBlock("Weapon")
    weaponBlk["preset"] = tier.presetId
    weaponBlk["slot"] = tier.slot
  }
  return presetBlk
}

let function addCustomPreset(unit, preset) {
  let presetBlk = convertPresetToBlk(preset)
  let presetId = preset.name
  let function cb() {
    if (presetId == getLastWeapon(unit.name))
      ::hangar_force_reload_model()
    ::broadcastEvent("CustomPresetChanged", { unitName = unit.name, presetId })
  }
  savePresetInProfile(unit, presetId, presetBlk, cb)
}

let function deleteCustomPreset(unit, presetId) {
  let presets = getCustomPresetsConfig(unit)
  if (presetId not in presets)
    return

  let cb = @() ::broadcastEvent("CustomPresetRemoved", { unitName = unit.name, presetId })
  savePresetInProfile(unit, presetId, DataBlock(), cb)
}

let function renameCustomPreset(unit, presetId, name) {
  let presets = getCustomPresetsConfig(unit)
  if (presetId not in presets)
    return

  presets[presetId].name = name
  let cb = @() ::broadcastEvent("CustomPresetChanged", { unitName = unit.name, presetId })
  savePresetInProfile(unit, presetId, presets[presetId], cb)
}

let getBaseCustomPresetConfig = @(presetName, presetBlk) {
  name = presetName
  weaponsBlk = presetBlk
  tags = []
  cost = 0
  type = weaponsItem.weapon
  customNameText = presetBlk?.name ?? ""
  image = "#ui/gameuiskin#custom_preset"
}

let function initCustomPreset(unit) {
  let presetConfig = getCustomPresetsConfig(unit)
  let weapons = []
  foreach (presetName, preset in presetConfig)
    weapons.append(getBaseCustomPresetConfig(presetName, preset))

  initUnitCustomPresetsWeapons(unit, weapons)
  customPresetsByUnit.mutate(@(val) val[unit.name] <- weapons)
}

let function getWeaponryCustomPresets(unit) {
  if (!unit.hasWeaponSlots)
    return []

  if (unit.name not in customPresetsByUnit.value)
    initCustomPreset(unit)

  return customPresetsByUnit.value[unit.name]
}

let function getCustomPresetByPresetBlk(unit, presetName, presetBlk) {
  let weapons = [getBaseCustomPresetConfig(presetName, presetBlk)]
  initUnitCustomPresetsWeapons(unit, weapons)
  return weapons[0]
}

addListenersWithoutEnv({
  SignOut = @(p) invalidateCache()
  ProfileReceived = @(p) invalidateCache()
}, ::g_listener_priority.CONFIG_VALIDATION)


return {
  addCustomPreset
  deleteCustomPreset
  renameCustomPreset
  getWeaponryCustomPresets
  getCustomPresetByPresetBlk
  convertPresetToBlk
}

