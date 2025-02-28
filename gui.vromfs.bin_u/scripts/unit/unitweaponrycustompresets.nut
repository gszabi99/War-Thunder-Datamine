from "%scripts/dagui_library.nut" import *
from "%scripts/weaponry/weaponryConsts.nut" import weaponsItem

let g_listener_priority = require("%scripts/g_listener_priority.nut")
let DataBlock = require("DataBlock")
let { hangar_force_reload_model } = require("hangar")
let { initUnitCustomPresetsWeapons } = require("%scripts/unit/initUnitWeapons.nut")
let { broadcastEvent, addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { getCustomWpnPresetBlk, charSendBlk } = require("chard")
let { getLastWeapon } = require("%scripts/weaponry/weaponryInfo.nut")
let { getWeaponToFakeBulletMask, updateSecondaryBullets } = require("%scripts/weaponry/bulletsInfo.nut")
let customPresetsConfigByUnit = mkWatched(persist, "customPresetsConfigByUnit", {})
let customPresetsByUnit = mkWatched(persist, "customPresetsByUnit", {})
let { addTask } = require("%scripts/tasker.nut")
let { isProfileReceived } = require("%appGlobals/login/loginState.nut")

function loadCustomPresets(unitName) {
  if (!isProfileReceived.get())
    return

  let blk = DataBlock()
  let customPresets = getCustomWpnPresetBlk(-1, unitName)
  if (customPresets != null)
    blk.setFrom(customPresets)
  customPresetsConfigByUnit.mutate(@(val) val[unitName] <- blk)
}

function invalidateCache() {
  customPresetsConfigByUnit({})
  customPresetsByUnit({})
}

function invalidateUnitCache(unit) {
  customPresetsConfigByUnit.mutate(@(val) val.$rawdelete(unit.name))
  customPresetsByUnit.mutate(@(val) val.$rawdelete(unit.name))
}

function savePresetInProfile(unit, id, presetBlk, successCb) {
  let blk = DataBlock()
  blk.addBlock(unit.name).addBlock(id).setFrom(presetBlk)
  function taskSuccessCb() {
    invalidateUnitCache(unit)
    successCb()
  }
  let taskId = charSendBlk("cln_save_weapon_presets", blk)
  addTask(taskId, { showProgressBox = true }, taskSuccessCb)
}

function getCustomPresetsConfig(unit) {
  if (!unit.hasWeaponSlots)
    return []

  if (unit.name not in customPresetsConfigByUnit.value)
    loadCustomPresets(unit.name)

  return customPresetsConfigByUnit.value?[unit.name] ?? []
}

function convertPresetToBlk(preset) {
  let presetBlk = DataBlock()
  presetBlk["name"] = preset.customNameText ?? ""
  foreach (tier in preset.tiers) {
    let weaponBlk = presetBlk.addNewBlock("Weapon")
    weaponBlk["preset"] = tier.presetId
    weaponBlk["slot"] = tier.slot
  }
  return presetBlk
}

function isPresetChanged(oldPreset, newPreset) {
  if (oldPreset.customNameText != newPreset.customNameText)
    return true

  if (oldPreset.tiers.len() != newPreset.tiers.len())
    return true

  foreach (idx, oldTier in oldPreset.tiers) {
    let newTier = newPreset.tiers?[idx]
    if (newTier == null
        || oldTier.presetId != newTier.presetId
        || oldTier.slot != newTier.slot)
      return true
  }

  return false
}

function addCustomPreset(unit, preset) {
  let presetBlk = convertPresetToBlk(preset)
  let presetId = preset.name
  function cb() {
    if (presetId == getLastWeapon(unit.name))
      hangar_force_reload_model()

    updateSecondaryBullets(unit, presetId, getWeaponToFakeBulletMask(unit))
    broadcastEvent("CustomPresetChanged", { unitName = unit.name, presetId })
  }
  savePresetInProfile(unit, presetId, presetBlk, cb)
}

function deleteCustomPreset(unit, presetId) {
  let presets = getCustomPresetsConfig(unit)
  if (presetId not in presets)
    return

  let cb = @() broadcastEvent("CustomPresetRemoved", { unitName = unit.name, presetId })
  savePresetInProfile(unit, presetId, DataBlock(), cb)
}

function renameCustomPreset(unit, presetId, name) {
  let presets = getCustomPresetsConfig(unit)
  if (presetId not in presets)
    return

  presets[presetId].name = name
  let cb = @() broadcastEvent("CustomPresetChanged", { unitName = unit.name, presetId })
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

function initCustomPreset(unit) {
  let presetConfig = getCustomPresetsConfig(unit)
  let weapons = []
  foreach (presetName, preset in presetConfig) {
    let presetClone = DataBlock()
    presetClone.setFrom(preset)
    weapons.append(getBaseCustomPresetConfig(presetName, presetClone))
  }

  initUnitCustomPresetsWeapons(unit, weapons)
  customPresetsByUnit.mutate(@(val) val[unit.name] <- weapons)
}

function getWeaponryCustomPresets(unit) {
  if (!unit.hasWeaponSlots)
    return []

  if (unit.name not in customPresetsByUnit.value)
    initCustomPreset(unit)

  return customPresetsByUnit.value[unit.name]
}

function getCustomPresetByPresetBlk(unit, presetName, presetBlk) {
  let weapons = [getBaseCustomPresetConfig(presetName, presetBlk)]
  initUnitCustomPresetsWeapons(unit, weapons)
  return weapons[0]
}

addListenersWithoutEnv({
  SignOut = @(_p) invalidateCache()
  ProfileReceived = @(_p) invalidateCache()
}, g_listener_priority.CONFIG_VALIDATION)


return {
  addCustomPreset
  deleteCustomPreset
  renameCustomPreset
  getWeaponryCustomPresets
  getCustomPresetByPresetBlk
  convertPresetToBlk
  isPresetChanged
}

