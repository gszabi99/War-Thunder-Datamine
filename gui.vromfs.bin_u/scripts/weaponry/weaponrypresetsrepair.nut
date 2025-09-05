from "%scripts/dagui_library.nut" import *

let { getProfileCountry } = require("chard")
let { deep_clone } = require("%sqstd/underscore.nut")
let { isWeaponModsPurchasedOrFree } = require("%scripts/weaponry/modificationInfo.nut")
let { getWeaponryByPresetInfo, findAvailableWeapon } = require("%scripts/weaponry/weaponryPresetsParams.nut")
let { openFixWeaponryPresets } = require("%scripts/weaponry/fixWeaponryPreset.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let slotbarPresets = require("%scripts/slotbar/slotbarPresets.nut")

local invalidPresetsByCountries = {}
local curCountryInvalidPresets



function getInvalidWeapon(curPreset, availableWeapons) {
  let presetsByTiers = curPreset.tiersView
  foreach (p in presetsByTiers)
    if (p?.weaponry != null) {
      let tierId = p.weaponry.tierId
      let presetId = p.weaponry.tiers[tierId].presetId
      let wBlk = findAvailableWeapon(availableWeapons, presetId, tierId)
      if (wBlk == null)
        return { curPreset, tierId, presetId = "" }
      foreach (slot in (wBlk % "dependentWeaponPreset")) {
        let dependWBlk = availableWeapons.findvalue(
          @(w) w.presetId == slot.preset && w.slot == slot.slot)
        if (dependWBlk != null
          && presetsByTiers[dependWBlk.tier]?.weaponry.presetId != dependWBlk.presetId)
            return { curPreset, tierId, presetId }
      }
      foreach (slot in (wBlk % "bannedWeaponPreset")) {
        let bannedWBlk = availableWeapons.findvalue(
          @(w) w.presetId == slot.preset && w.slot == slot.slot)
        if (bannedWBlk != null
          && presetsByTiers[bannedWBlk.tier]?.weaponry.presetId == bannedWBlk.presetId)
            return { curPreset, tierId, presetId }
      }
    }

  return null
}

function repairInvalidPresets() {
  foreach (unitName, presets in curCountryInvalidPresets) {
    
    if (presets.len() == 0)
      continue

    let unit = getAircraftByName(unitName)
    let weaponryByPresetInfo = getWeaponryByPresetInfo(unit)
    let availableWeapons = weaponryByPresetInfo.availableWeapons?.filter(
      @(w) isWeaponModsPurchasedOrFree(unitName, w)
    )
    let p = presets.values()[0]
    presets.$rawdelete(p.curPreset.name)
    let afterModalDestroyFunc = repairInvalidPresets
    openFixWeaponryPresets({
      unit
      originalPreset = p.curPreset
      preset = deep_clone(p.curPreset)
      availableWeapons = availableWeapons
      favoriteArr = []
      afterModalDestroyFunc
    }).chooseWeapon(p.tierId, p.presetId, true)
    return
  }
}

function searchAndRepairInvalidPresets(uNames = null) {
  let countryId = getProfileCountry()
  let isForced = uNames != null
  let unitsList = isForced ? uNames : slotbarPresets.getCurrentPreset(countryId)?.units
  
  if ((!isForced && invalidPresetsByCountries?[countryId] != null) || unitsList == null)
    return

  if (invalidPresetsByCountries?[countryId] == null)
    invalidPresetsByCountries[countryId] <- {}
  curCountryInvalidPresets = invalidPresetsByCountries[countryId]
  foreach (unitName in unitsList) {
    let unit = getAircraftByName(unitName)
    
    if (!unit.hasWeaponSlots)
      continue

    
    if (curCountryInvalidPresets?[unitName] != null
      && curCountryInvalidPresets[unitName].len() == 0)
      continue

    curCountryInvalidPresets[unitName] <- {}
    let weaponryByPresetInfo = getWeaponryByPresetInfo(unit)
    let presets = weaponryByPresetInfo.presets.filter(@(p) p.customIdx > -1)
    let availableWeapons = weaponryByPresetInfo.availableWeapons?.filter(
      @(w) isWeaponModsPurchasedOrFree(unitName, w)
    )
    foreach (preset in presets) {
      let invalidWeapon = getInvalidWeapon(preset, availableWeapons)
      if (invalidWeapon)
        curCountryInvalidPresets[unitName][preset.name] <- invalidWeapon
    }
  }
  repairInvalidPresets()
}

addListenersWithoutEnv({
  CountryChanged                = @(_) searchAndRepairInvalidPresets()
  CrewTakeUnit                  = @(p) p?.unit ? searchAndRepairInvalidPresets([p.unit.name]) : null
  PresetsByGroupsChanged        = @(p) searchAndRepairInvalidPresets(p.unitNames)
  PresetsByGroupsCountryChanged = @(p) searchAndRepairInvalidPresets(p.unitNames)
})

return {
  searchAndRepairInvalidPresets
}