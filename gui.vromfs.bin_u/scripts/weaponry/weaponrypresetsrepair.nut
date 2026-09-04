from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv, broadcastEvent
from "chard" import getProfileCountry
from "%sqstd/underscore.nut" import deep_clone
from "%scripts/dagui_library.nut" import *

let { isWeaponModsPurchasedOrAvailableForFree } = require("%scripts/weaponry/modificationInfo.nut")
let { getWeaponryByPresetInfo, findAvailableWeapon } = require("%scripts/weaponry/weaponryPresetsParams.nut")
let { openFixWeaponryPresets } = require("%scripts/weaponry/fixWeaponryPreset.nut")
let { getCurrentSlotbarPreset } = require("%scripts/slotbar/slotbarPresetsHelpers.nut")
let { validateBadLastWeapons } = require("%scripts/weaponry/weaponryInfo.nut")


const DBG_REPAIR_PRESET_MODE = {
  dependentWeapon = 0 
  brokenTiers = 1 
}

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

  if (curPreset.brokenTiers.len()) {
    local brokenPresetWpn = null
    for (local idx = 0; idx < curPreset.brokenTiers.len(); idx++) {
      let t = curPreset.brokenTiers[idx]
      let tierId = availableWeapons.findvalue(
        @(w) w.presetId == t.preset && w.slot == t.slot)?.tier ?? -1
      if (brokenPresetWpn == null || tierId != -1)
        brokenPresetWpn = { curPreset, tierId, presetId = t.preset }
      if (tierId != -1)
        break
    }
    return brokenPresetWpn
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
      @(w) isWeaponModsPurchasedOrAvailableForFree(unitName, w)
    )
    let p = presets.values()[0]
    presets.$rawdelete(p.curPreset.name)
    let afterModalDestroyFunc = repairInvalidPresets
    let modal = openFixWeaponryPresets({
      unit
      originalPreset = p.curPreset
      preset = deep_clone(p.curPreset)
      availableWeapons = availableWeapons
      favoriteArr = []
      afterModalDestroyFunc
    })
    
    
    if (p.tierId != -1)
      modal.chooseWeapon(p.tierId, p.presetId, true)
    return
  }
  broadcastEvent("WeaponryPresetsRepairFinished")
}

function searchAndRepairInvalidPresets(uNames = null, dbgRepairPresetModeInt = null) {
  let countryId = getProfileCountry()
  let isForced = uNames != null
  let unitsList = isForced ? uNames : getCurrentSlotbarPreset(countryId)?.units
  
  if ((!isForced && invalidPresetsByCountries?[countryId] != null) || unitsList == null)
    return

  if (invalidPresetsByCountries?[countryId] == null)
    invalidPresetsByCountries[countryId] <- {}
  curCountryInvalidPresets = invalidPresetsByCountries[countryId]
  foreach (unitName in unitsList) {
    let unit = getAircraftByName(unitName)
    if (unit == null)
      continue

    validateBadLastWeapons(unit)
    
    if (!unit.hasWeaponSlots)
      continue

    
    if (dbgRepairPresetModeInt == null && curCountryInvalidPresets?[unitName] != null
      && curCountryInvalidPresets[unitName].len() == 0)
      continue

    curCountryInvalidPresets[unitName] <- {}
    let weaponryByPresetInfo = getWeaponryByPresetInfo(unit)
    let presets = weaponryByPresetInfo.presets.filter(@(p) p.customIdx > -1)
    let availableWeapons = weaponryByPresetInfo.availableWeapons?.filter(
      @(w) isWeaponModsPurchasedOrAvailableForFree(unitName, w)
    )
    foreach (preset in presets) {
      let invalidWeapon = getInvalidWeapon(preset,
        dbgRepairPresetModeInt == DBG_REPAIR_PRESET_MODE.dependentWeapon ? availableWeapons?.slice(0,1)
          : availableWeapons)
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
  DBG_REPAIR_PRESET_MODE
}