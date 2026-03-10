from "%scripts/dagui_natives.nut" import wp_get_repair_cost
from "%scripts/dagui_library.nut" import *

let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { getSelectedCrews, ignoreTransactions } = require("%scripts/slotbar/slotbarStateData.nut")
let { initSelectedCrews, reinitAllSlotbars } = require("%scripts/slotbar/slotbarState.nut")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { hasDefaultUnitsInCountry } = require("%scripts/shop/shopUnitsInfo.nut")
let { getEsUnitType } = require("%scripts/unit/unitParams.nut")
let { getCrewsList, invalidateCrewsList } = require("%scripts/slotbar/crewsList.nut")
let { slotbarPresetsByCountry, getCurrentPresetIdx, isSlotbarPresetsLoading
} = require("%scripts/slotbar/slotbarPresetsState.nut")
let { updateShopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { isProfileReceived } = require("%appGlobals/login/loginState.nut")
let { CONFIG_VALIDATION, DEFAULT_HANDLER } = require("%scripts/g_listener_priority.nut")
let { disableNetwork } = require("%globalScripts/clientState/initialState.nut")

function createPresetTemplate(presetIdx) {
  return {
    units = []
    crews = []
    crewInSlots = []
    orderedUnits = []
    selected = -1
    title = loc("shop/slotbarPresets/item", { number = presetIdx + 1 })
    gameModeId = ""

    unitTypesMask = 0
    enabled = true
  }
}

let checkCanHaveEmptyPresets = @(country) !hasDefaultUnitsInCountry(country)

function reorderUnitsInPreset(preset) {
  let unitsOrder = preset.crews.map(@(c) preset.crewInSlots.indexof(c))
  preset.orderedUnits <- preset.units
    .map(@(unit, index) { unit, order = unitsOrder[index] })
    .sort(@(u1, u2) u1.order <=> u2.order)
    .map(@(unit) unit.unit)
}

function updatePresetInfo(preset) {
  local unitTypesMask = 0
  foreach (unitId in preset.units) {
    let unit = getAircraftByName(unitId)
    let unitType = unit ? getEsUnitType(unit) : ES_UNIT_TYPE_INVALID
    if (unitType != ES_UNIT_TYPE_INVALID)
      unitTypesMask = unitTypesMask | (1 << unitType)
  }

  preset.unitTypesMask = unitTypesMask
  preset.enabled = true
  reorderUnitsInPreset(preset)

  return preset
}

function updatePresetFromSlotbar(preset, countryId) {
  if (isSlotbarPresetsLoading.get())    
    return preset   

  initSelectedCrews()
  let units = []
  let crews = []
  let crewInSlots = clone preset.crewInSlots
  local selected = preset.selected
  foreach (tbl in getCrewsList())
    if (tbl.country == countryId) {
      foreach (crew in tbl.crews) {
        if (!crewInSlots.contains(crew.id))
          crewInSlots.append(crew.id)
        if (("aircraft" in crew)) {
          let unitName = crew.aircraft
          if (!getAircraftByName(unitName))
            continue

          units.append(crew.aircraft)
          crews.append(crew.id)
          if (selected == -1 || crew.idInCountry == getSelectedCrews(crew.idCountry))
            selected = crew.id
        }
      }
    }

  if ((units.len() == 0 || crews.len() == 0) && !checkCanHaveEmptyPresets(countryId))
    return preset 

  preset.units = units
  preset.crews = crews
  preset.selected = selected
  preset.crewInSlots = crewInSlots

  updatePresetInfo(preset)
  return preset
}

function createPresetFromSlotbar(countryId, presetIdx = 0) {
  return updatePresetFromSlotbar(createPresetTemplate(presetIdx), countryId)
}

function getPresetsListFromSlotbar(countryId = null) {
  countryId = countryId ?? profileCountrySq.get()
  let res = []
  if (!(countryId in slotbarPresetsByCountry)) {
    res.append(createPresetFromSlotbar(countryId))
    return res
  }

  let currentIdx = getCurrentPresetIdx(countryId, -1)
  foreach (idx, preset in slotbarPresetsByCountry[countryId]) {
    if (idx == currentIdx)
      updatePresetFromSlotbar(preset, countryId)
    res.append(preset)
  }

  return res
}

function getCurrentSlotbarPreset(country = null) {
  country = country ?? profileCountrySq.get()
  let index = getCurrentPresetIdx(country, -1)
  return getPresetsListFromSlotbar(country)?[index]
}

function getBrokenUnits() {
  let brokenUnits = {}
  foreach (c in getCrewsList()) {
    if (!("crews" in c))
      continue
    foreach (crew in c.crews)
      if (("aircraft" in crew) && crew.aircraft != "" && crew.isLocked == 0
        && getAircraftByName(crew.aircraft) && wp_get_repair_cost(crew.aircraft) > 0)
        brokenUnits[crew.aircraft] <- true
  }
  return brokenUnits
}

local unitsStateCached = null
function getMyCrewUnitsState(country = null) {
  if (unitsStateCached != null)
    return unitsStateCached

  country = country ?? profileCountrySq.get()

  unitsStateCached = {
    crewAirs = {}
    brokenAirs = []
    rank = 0
  }

  foreach (c in getCrewsList()) {
    if (!("crews" in c))
      continue

    let crewAirs = []
    foreach (crew in c.crews)
      if (("aircraft" in crew) && crew.aircraft != "" && crew.isLocked == 0) {
        let air = getAircraftByName(crew.aircraft)
        if (air) {
          crewAirs.append(crew.aircraft)
          if (c.country == country && unitsStateCached.rank < air.rank)
            unitsStateCached.rank = air.rank
          if (wp_get_repair_cost(crew.aircraft) > 0)
            unitsStateCached.brokenAirs.append(crew.aircraft)
        }
      }

    let preset = getCurrentSlotbarPreset(c.country)
    if(preset != null)
      crewAirs.replace(preset.orderedUnits.filter(@(unit) crewAirs.indexof(unit) != null))

    unitsStateCached.crewAirs[c.country] <- crewAirs
  }

  return unitsStateCached
}

addListenersWithoutEnv({
  function ProfileUpdated(p) {
    if (p.transactionType == EATT_UPDATE_ENTITLEMENTS)
      updateShopCountriesList()

    let brokenUnitsCached = getMyCrewUnitsState().brokenAirs
    let brokenUnitsUpdated = getBrokenUnits()

    local hasRepairedUnits = false
    foreach (unit in brokenUnitsCached) {
      if (unit not in brokenUnitsUpdated) {
        hasRepairedUnits = true
        break
      }
    }

    if (isProfileReceived.get() && !isInArray(p.transactionType, ignoreTransactions)
        && invalidateCrewsList(hasRepairedUnits) && !disableNetwork)
      reinitAllSlotbars()
  }
}, DEFAULT_HANDLER)

addListenersWithoutEnv({
  CrewsListChanged = @(_p) unitsStateCached = null
  CrewsListInvalidate = @(_p) unitsStateCached = null
  SlotbarPresetChangedWithoutProfileUpdate = @(_p) unitsStateCached = null
  CrewsOrderChanged = @(_p) unitsStateCached = null
  UnitRepaired = @(_p) unitsStateCached = null
  InitConfigs = @(_) unitsStateCached = null
}, CONFIG_VALIDATION)

return {
  createPresetTemplate
  checkCanHaveEmptyPresets
  reorderUnitsInPreset
  updatePresetInfo
  updatePresetFromSlotbar
  createPresetFromSlotbar
  getPresetsListFromSlotbar
  getCurrentSlotbarPreset
  getMyCrewUnitsState
}