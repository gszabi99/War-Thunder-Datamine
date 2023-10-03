//checked for plus_string
from "%scripts/dagui_library.nut" import *
let { isEqual } = require("%sqStdLibs/helpers/u.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let subscriptions = require("%sqStdLibs/helpers/subscriptions.nut")
let { broadcastEvent } = subscriptions
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { getCrew } = require("%scripts/crew/crew.nut")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let DataBlock = require("DataBlock")
let { split } = require("%sqstd/string.nut")
let { getUnitName } = require("%scripts/unit/unitInfo.nut")

local curPreset = {
  groupsList = {} //groups config by country
  countryPresets = {} //units list in slotbar by country
  presetId = "" //eventId or mapId for WW
}

local cachedPresetsListByEventId = {}
let getPresetTemplate = @() {
  units = []
}

let getPresetSaveIdByEventId = @(presetId) "slotbar_presets_by_game_modes/{0}".subst(presetId)

let function invalidateCashe() {
  cachedPresetsListByEventId = {}
  curPreset = {
    groupsList = {}
    countryPresets = {}
    presetId = ""
  }
}

let function getDefaultPresets(countryGroupsList) {
  let preset = getPresetTemplate()
  preset.units = countryGroupsList.defaultUnitsListByGroups.values()
  return preset
}

let function generateDefaultPresets(groupsList) {
  return groupsList.map(@(country) getDefaultPresets(country))
}

let function savePresets(presetId, countryPresets) {
  let blk = DataBlock()
  foreach (countryId, preset in countryPresets)
    blk[countryId] <- ",".join(preset.units.map(@(unit) unit?.name ?? ""))

  let cfgBlk = loadLocalAccountSettings(getPresetSaveIdByEventId(presetId))
  if (isEqual(blk, cfgBlk))
    return

  saveLocalAccountSettings(getPresetSaveIdByEventId(presetId), blk)
}

let function isDefaultUnitForGroup(unit, groupsList, country) {
  let unitsGroups = groupsList?[country]
  if (unitsGroups == null)
    return false

  let groupId = unitsGroups.groupIdByUnitName?[unit.name]
  if (groupId == null)
    return false

  return unitsGroups.defaultUnitsListByGroups?[groupId].name == unit.name
}

let function canAssignInSlot(unit, groupsList, country) {
  return isDefaultUnitForGroup(unit, groupsList, country) || unit.canAssignToCrew(country)
}

let function validatePresets(_presetId, groupsList, countryPresets) {
  if ((countryPresets?.len() ?? 0) == 0)
    return generateDefaultPresets(groupsList)

  foreach (countryId in shopCountriesList) {
    let countryGroupsList = groupsList?[countryId]
    let countryPreset = countryPresets?[countryId]
    if (countryGroupsList == null) {
      if (countryPreset != null)
        countryPresets.rawdelete(countryId)
      continue
    }

    if (countryPreset == null) {
      countryPresets[countryId] <- getDefaultPresets(countryGroupsList)
      continue
    }

    let defaultUnitsListByGroups = clone countryGroupsList.defaultUnitsListByGroups
    let maxVisibleSlots = max(::get_crew_count(countryId), defaultUnitsListByGroups.len())
    let presetUnits = countryPreset.units
    presetUnits.resize(maxVisibleSlots, null)
    let emptySLots = []
    foreach (i, unit in presetUnits) {
      if (unit == null || !canAssignInSlot(unit, groupsList, countryId)) {
        presetUnits[i] = null
        emptySLots.append(i)
        continue
      }

      let unitGroup = countryGroupsList.groupIdByUnitName?[unit.name]
      if (unitGroup in defaultUnitsListByGroups) {
         defaultUnitsListByGroups.rawdelete(unitGroup)
         continue
      }

      presetUnits[i] = null   //not found unit group, need clear slot.
      emptySLots.append(i)
    }

    local i = 0
    foreach (defaultUnit in defaultUnitsListByGroups) {
      let slotIdx = emptySLots[i]
      presetUnits[slotIdx] = defaultUnit
      i++
    }
  }

  return countryPresets
}

let function getPresetsList(presetId, groupsList) {
  local countryPresets = cachedPresetsListByEventId?[presetId]
  if ((countryPresets?.len() ?? 0) != 0)
    return countryPresets

  let savedPresetsBlk = loadLocalAccountSettings(getPresetSaveIdByEventId(presetId))
  if (savedPresetsBlk) {
    countryPresets = {}
    let countryCount = savedPresetsBlk.paramCount()
    for (local c = 0; c < countryCount; c++) {
      let strPreset = savedPresetsBlk.getParamValue(c)
      let preset = getPresetTemplate()
      let unitNames = split(strPreset, ",")
      if (unitNames.len() == 0)
        continue

      local hasUnits = false
      for (local i = 0; i < unitNames.len(); i++) {
        let unitName = unitNames[i]
        let unit = getAircraftByName(unitName)
        if (unit != null)
          hasUnits = true

        preset.units.append(unit)
      }

      if (!hasUnits)
        continue

      countryPresets[savedPresetsBlk.getParamName(c)] <- preset
    }
  }

  countryPresets = validatePresets(presetId, groupsList, countryPresets)
  cachedPresetsListByEventId[presetId] <- countryPresets
  return countryPresets
}

let function updatePresets(presetId, countryPresets) {
  cachedPresetsListByEventId[presetId] <- countryPresets
  savePresets(presetId, countryPresets)
}

let groupInSlotMsgBoxlocId = "msgbox/groupAlreadyInOtherSlot"

let setUnit = kwarg(function setUnit(crew, unit, onFinishCb = null, showNotification = true, needEvent = true) {
  let country = crew.country
  let curCountryPreset = curPreset.countryPresets?[country]
  if (curCountryPreset == null) {
    onFinishCb?(true)
    return
  }

  let idx = crew.idInCountry
  let curUnit = curCountryPreset.units?[idx]
  if (curUnit == unit) {
    onFinishCb?(true)
    return
  }

  let countryGroups = curPreset.groupsList[country]
  let groupIdByUnitName = countryGroups.groupIdByUnitName
  let unitGroup = groupIdByUnitName[unit.name]
  let curUnitGroup = groupIdByUnitName?[curUnit?.name ?? ""] ?? ""
  let onApplyCb = function() {
    if (idx >= curCountryPreset.units.len())
      curPreset.countryPresets[country].units.resize(idx + 1, null)

    curPreset.countryPresets[country].units[idx] = unit
    updatePresets(curPreset.presetId, curPreset.countryPresets)
    if (needEvent)
      broadcastEvent("PresetsByGroupsChanged", {
        crew = crew, unit = unit, unitNames = [unit.name]})
    onFinishCb?(true)
  }

  let oldGroupIdx = curCountryPreset.units.findindex(@(un)
    groupIdByUnitName?[un?.name ?? ""] == unitGroup)
  if (unitGroup != curUnitGroup && oldGroupIdx != null) {
    let replaceUnitGroup = function() {
      curPreset.countryPresets[country].units[oldGroupIdx] = curUnit
      onApplyCb()
    }
    if (!showNotification) {
      replaceUnitGroup()
      return
    }

    let groupName = colorize("activeTextColor", loc(countryGroups.groups[unitGroup].name))
    let descLocId = "{0}/{1}".subst(groupInSlotMsgBoxlocId, curUnit == null ? "inEmptySlot" : "slotWithUnit")
    scene_msg_box("group_already_in_other_slot", null,
      loc(groupInSlotMsgBoxlocId, {
        groupName = groupName
        slotIdx = oldGroupIdx + 1
        descMsg = loc(descLocId, {
          unitName = colorize("activeTextColor", getUnitName(unit))
          curGroupUnitName = colorize("activeTextColor",
            getUnitName(curCountryPreset.units[oldGroupIdx]))
          curUnitName = colorize("activeTextColor", getUnitName(curUnit))
          slotIdx = oldGroupIdx + 1
        })
      }),
      [[ "ok", replaceUnitGroup
        ], [ "cancel", @() null ]],
      "ok")
  }
  else
    onApplyCb()
})

let getCurPresetUnitNames = @()
  (curPreset.countryPresets?[::get_profile_country()].units.map(@(unit) unit?.name)
    ?? []).filter(@(n) n)

let function setCurPreset(presetId, groupsList) {
  let curPresetId = curPreset.presetId
  if (curPresetId == presetId)
    return
  let countryPresets = getPresetsList(presetId, groupsList)
  curPreset = {
    groupsList = groupsList
    countryPresets = countryPresets
    presetId = presetId
  }
  broadcastEvent("PresetsByGroupsChanged", {unitNames = getCurPresetUnitNames()})
}

let function getCurPreset() {
  return curPreset
}

let function getCurCraftsInfo() {
  return (curPreset.countryPresets?[profileCountrySq.value].units ?? []).map(@(unit) unit?.name ?? "")
}

let function getSlotItem(idCountry, idInCountry) {
  return getCrew(idCountry, idInCountry) ?? {
    country = shopCountriesList[idCountry]
    idCountry = idCountry
    idInCountry = idInCountry
    id = -1
  }
}

let function getCrewByUnit(unit) {
  let country = unit.shopCountry
  let idCountry = shopCountriesList.findindex(@(cName) cName == country)
  let units = curPreset.countryPresets?[country].units ?? []
  let idInCountry = units.findindex(@(u) u == unit)
  if (idInCountry == null)
    return null

  return getSlotItem(idCountry, idInCountry)
}

let function setUnits(trainCrews) {
  let unitNames = []
  foreach (data in trainCrews)
    if (data.unit != null) {
      setUnit({
        crew = data.crew
        unit = data.unit
        showNotification = false
        needEvent = false
      })
      unitNames.append(data.unit.name)
    }

  broadcastEvent("PresetsByGroupsChanged", {unitNames})
}

let setGroup = kwarg(function setGroup(crew, group, onFinishCb) {
  let country = crew.country
  let curCountryPreset = curPreset.countryPresets?[country]
  if (curCountryPreset == null) {
    onFinishCb(true)
    return
  }

  let groupIdByUnitName = curPreset.groupsList[country].groupIdByUnitName
  let selectGroupUnit = curCountryPreset.units.findvalue(@(v) groupIdByUnitName?[v?.name ?? ""] == group.id)
  if (selectGroupUnit == null) {
    onFinishCb(true)
    return
  }

  setUnit({
    crew = crew
    unit = selectGroupUnit
    onFinishCb = onFinishCb
    showNotification = false
  })
})

subscriptions.addListenersWithoutEnv({
  SignOut = @(_p) invalidateCashe()
})

let function getVehiclesGroupByUnit(unit, countryGroupsList) {
  return countryGroupsList?.groups[countryGroupsList?.groupIdByUnitName[unit?.name ?? ""] ?? ""]
}

let function getWarningTextTbl(availableUnits, countryCrews, isCrewByUnitsGroup) {
  let res = {
    needShow = false
    needMsgBox = false
    warningText = ""
    fullWarningText = ""
  }

  let crewNames = []
  foreach (crew in countryCrews) {
    let crewUnit = isCrewByUnitsGroup
      ? crew
      : ::g_crew.getCrewUnit(crew)
    if (crewUnit != null)
      crewNames.append(crewUnit.name)
  }

  local isAllBattleUnitsInSlots = true
  foreach (unitName, _ in availableUnits)
    if (!isInArray(unitName, crewNames)) {
      if (isCrewByUnitsGroup) {
        res.needShow = true
        res.needMsgBox = true
        res.warningText = loc("worldWar/warning/can_insert_higher_rank_units")
        res.fullWarningText = loc("worldWar/warning/can_insert_higher_rank_units_full")
        return res
      }
      else if (getAircraftByName(unitName)?.canUseByPlayer() ?? false) {
        res.needShow = true
        res.needMsgBox = true
        res.warningText = loc("worldWar/warning/can_insert_more_available_units")
        res.fullWarningText = loc("worldWar/warning/can_insert_more_available_units_full")
        return res
      }
      else
        isAllBattleUnitsInSlots = false
    }

  if (!isAllBattleUnitsInSlots) {
    res.needShow = true
    res.warningText = loc("worldWar/warning/has_not_all_battle_units")
    res.fullWarningText = loc("worldWar/warning/has_not_all_battle_units_full")
  }

  return res
}

let function getBestAvailableUnitByGroup(curSlotbarUnits, groupUnits, presetGroupsList, country, eDiff = null) {
  eDiff = eDiff ?? DIFFICULTY_REALISTIC
  let sortedUnits = groupUnits.values().map(
    @(u) { unit = u, rank = u.getBattleRating(eDiff),
      isInSlotbar = isInArray(u, curSlotbarUnits), isSpecial = ::isUnitSpecial(u) })
  sortedUnits.sort(@(a, b) b.rank <=> a.rank
    || b.isSpecial <=> a.isSpecial
    || b.isInSlotbar <=> a.isInSlotbar
    || a.unit.name <=> b.unit.name)
  return sortedUnits.findvalue(@(u) canAssignInSlot(u.unit, presetGroupsList, country))
}

return {
  setCurPreset
  getCurPreset
  setUnit
  getCurCraftsInfo
  getCrewByUnit
  getSlotItem
  canAssignInSlot
  setUnits
  setGroup
  getVehiclesGroupByUnit
  getWarningTextTbl
  getCurPresetUnitNames
  getBestAvailableUnitByGroup
}