from "%scripts/dagui_library.nut" import *

let { array_to_blk } = require("%scripts/utils_sa.nut")
let { isEqual }  = require("%sqStdLibs/helpers/u.nut")
let { loadLocalByAccount, saveLocalByAccount
} = require("%scripts/clientState/localProfileDeprecated.nut")
let regexp2 = require("regexp2")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { addListenersWithoutEnv, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { isCountryAllCrewsUnlockedInHangar, isCountrySlotbarHasUnits } = require("%scripts/slotbar/slotbarStateData.nut")
let { selectCrew, flushSlotbarUpdate, suspendSlotbarUpdates } = require("%scripts/slotbar/slotbarState.nut")
let { clearBorderSymbols, split } = require("%sqstd/string.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { batchTrainCrew } = require("%scripts/crew/crewTrain.nut")
let { forceSaveProfile } = require("%scripts/clientState/saveProfile.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { deep_clone } = require("%sqstd/underscore.nut")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { reqFirstUnitTypeChoice, isCountryAvailable } = require("%scripts/firstChoice/firstChoice.nut")
let { reqFirstCountryChoice } = require("%scripts/user/newbieTutorialDisplay.nut")
let { hasDefaultUnitsInCountry } = require("%scripts/shop/shopUnitsInfo.nut")
let logP = log_with_prefix("[SLOTBAR PRESETS] ")
let { debug_dump_stack } = require("dagor.debug")
let getAllUnits = require("%scripts/unit/allUnits.nut")
let { getUnitCountry } = require("%scripts/unit/unitInfo.nut")
let { isUnitBought } = require("%scripts/unit/unitShopInfo.nut")
let { isUnitUsable } = require("%scripts/unit/unitStatus.nut")
let { isInMenu } = require("%scripts/clientState/clientStates.nut")
let { getCurrentGameModeId, setCurrentGameModeById, getGameModeById,
  getGameModeByUnitType, findCurrentGameModeId, isPresetValidForGameMode
} = require("%scripts/gameModes/gameModeManagerState.nut")
let { getCrewUnit } = require("%scripts/crew/crew.nut")
let { getCrewsList, getCrewsListByCountry } = require("%scripts/slotbar/crewsList.nut")
let { slotbarPresetsByCountry, slotbarPresetsSeletected, slotbarPresetsVersion, isSlotbarPresetsLoading
} = require("%scripts/slotbar/slotbarPresetsState.nut")
let { createPresetTemplate, checkCanHaveEmptyPresets, reorderUnitsInPreset, updatePresetInfo,
  updatePresetFromSlotbar, createPresetFromSlotbar, getCurrentSlotbarPreset
} = require("%scripts/slotbar/slotbarPresetsHelpers.nut")
let openEditBoxDialog = require("%scripts/wndLib/editBoxHandler.nut")
let { isProfileReceived } = require("%appGlobals/login/loginState.nut")
let { isInvalidCrewsAllowed } = require("%scripts/matchingRooms/sessionLobbyState.nut")
let { isUnitAllowedForRoom } = require("%scripts/matchingRooms/sessionLobbyInfo.nut")
let { isCanModifyCrew } = require("%scripts/queue/queueManager.nut")
let { getGlobalModule } = require("%scripts/global_modules.nut")
let events = getGlobalModule("events")
let { isSlotbarOverrided } = require("%scripts/slotbar/slotbarOverride.nut")


require("%scripts/slotbar/hangarVehiclesPreset.nut")

local isAlreadySendMissingPresetError = false

const PRESETS_VERSION = 1
const PRESETS_VERSION_SAVE_ID = "presetsVersion"
const MIN_COUNTRY_PRESETS = 1
const BASE_COUNTRY_PRESETS_AMOUNT = 8
const ERA_BONUS_PRESETS_AMOUNT = 2 
const ERA_ID_FOR_BONUS = 5
let validatePresetNameRegexp = regexp2(@"^#|[;|\\<>]")

local activeTypeBonusByCountry = null

let isEqualPreset = @(p1, p2) isEqual(p1.crews, p2.crews) && isEqual(p1.units, p2.units)

function canEditCountryPreset(country = null) {
  country = country ?? profileCountrySq.get()
  return !isSlotbarOverrided()
    && (isCountrySlotbarHasUnits(country) || checkCanHaveEmptyPresets(country)
      || reqFirstCountryChoice())
}

function canLoadSlotbarPreset(verbose = false, country = null) {
  if (isSlotbarPresetsLoading.get() || isSlotbarOverrided())
    return false
  country = country ?? profileCountrySq.get()
  if (!(country in slotbarPresetsByCountry) || !isInMenu.get() || !isCanModifyCrew())
    return false
  if (!isCountryAllCrewsUnlockedInHangar(country)) {
    if (verbose)
      showInfoMsgBox(loc("charServer/updateError/52"), "slotbar_presets_forbidden")
    return false
  }
  return true
}

function canLoadPreset(preset, isSilent = false) {
  if (!preset)
    return false
  if (isInvalidCrewsAllowed())
    return true

  foreach (unitName in preset.units) {
    let unit = getAircraftByName(unitName)
    if (unit && isUnitAllowedForRoom(unit))
      return true
  }

  if (!isSilent)
    showInfoMsgBox(loc("msg/cantUseUnitInCurrentBattle",
                     { unitName = colorize("userlogColoredText", preset.title) }))
  return false
}



function canEraseSlotbarPreset() {
  let countryId = profileCountrySq.get()
  return (countryId in slotbarPresetsByCountry)
    && slotbarPresetsByCountry[countryId].len() > MIN_COUNTRY_PRESETS
}

function validateSlotsCountCache() {
  if (activeTypeBonusByCountry)
    return

  activeTypeBonusByCountry = {}

  foreach (unit in getAllUnits()) {
    if (unit.rank != ERA_ID_FOR_BONUS ||
        ! unit.unitType.isAvailable() ||
        ! unit.isVisibleInShop())
      continue

    let countryName = getUnitCountry(unit)
    if (! (countryName in activeTypeBonusByCountry))
      activeTypeBonusByCountry[countryName] <- {}

    if (! (unit.unitType in activeTypeBonusByCountry[countryName]))
      activeTypeBonusByCountry[countryName][unit.unitType] <- false

    if (isUnitBought(unit))
      activeTypeBonusByCountry[countryName][unit.unitType] = true
  }
}

function getUnitTypesWithNotActivePresetBonus(country = null) {
  country = country ?? profileCountrySq.get()
  validateSlotsCountCache()
  let result = []
  foreach (unitType, typeStatus in getTblValue(country, activeTypeBonusByCountry, {}))
    if (! typeStatus)
      result.append(unitType)
  return result
}

function havePresetsReserve(country = null) {
  country = country ?? profileCountrySq.get()
  return getUnitTypesWithNotActivePresetBonus(country).len() > 0
}

function getPresetsReseveTypesText(country = null) {
  country = country ?? profileCountrySq.get()
  let types = getUnitTypesWithNotActivePresetBonus(country)
  local typeNames = types.map(@(unit) unit.getArmyLocName())
  return ", ".join(typeNames, true)
}

function getMaxPresetsCount(country = null) {
  country = country ?? profileCountrySq.get()
  validateSlotsCountCache()
  local result = BASE_COUNTRY_PRESETS_AMOUNT
  foreach (_unitType, typeStatus in getTblValue(country, activeTypeBonusByCountry, {}))
    if (typeStatus)
      result += ERA_BONUS_PRESETS_AMOUNT
  return result
}

function getTotalPresetsCount() {
  return BASE_COUNTRY_PRESETS_AMOUNT + unitTypes.types.len() * ERA_BONUS_PRESETS_AMOUNT
}

let clearSlotsCache = @() activeTypeBonusByCountry = null

let validatePresetName = @(name) validatePresetNameRegexp.replace("", name)

function canCreateSlotbarPreset() {
  local countryId = profileCountrySq.get()
  return (countryId in slotbarPresetsByCountry)
    && slotbarPresetsByCountry[countryId].len() < getMaxPresetsCount(countryId)
    && canEditCountryPreset(countryId)
}

function createEmptyPreset(countryId, presetIdx = 0) {
  let crews = getCrewsListByCountry(countryId)
  local unitToSet = null
  local crewToSet = null
  foreach (crew in crews) {
    foreach (unitName in crew.trained) {
      let unit = getAircraftByName(unitName)
      if (!unit || !unit.isBought() || !unit.canAssignToCrew(countryId))
        continue
      if (unitToSet && unitToSet.rank > unit.rank)
        continue
      unitToSet = unit
      crewToSet = crew
    }
    if (unitToSet)
      break
  }

  let preset = createPresetTemplate(presetIdx)
  if (unitToSet) {
    preset.units = [ unitToSet.name ]
    preset.crews = [ crewToSet.id ]
    preset.crewInSlots = [ crewToSet.id ]
    preset.selected = crewToSet.id
    updatePresetInfo(preset)
  }
  return preset
}

function saveCountryPreset(countryId = null, shouldSaveProfile = true) {
  if (!countryId)
    countryId = profileCountrySq.get()
  if (!canEditCountryPreset(countryId) || !(countryId in slotbarPresetsByCountry))
    return false
  let cfgBlk = loadLocalByAccount($"slotbar_presets/{countryId}")
  local blk = null
  if (slotbarPresetsByCountry[countryId].len() > 0) {
    let curPreset = getTblValue(slotbarPresetsSeletected[countryId], slotbarPresetsByCountry[countryId])
    if (curPreset && countryId == profileCountrySq.get())
      updatePresetFromSlotbar(curPreset, countryId)

    let presetsList = []
    foreach (_idx, p in slotbarPresetsByCountry[countryId]) {
      if (p.units.len() == 0 && !checkCanHaveEmptyPresets(countryId))
        continue
      presetsList.append("|".join([
                                    p.selected,
                                    ",".join(p.crews),
                                    ",".join(p.units),
                                    p.title,
                                    getTblValue("gameModeId", p, ""),
                                    ",".join(p.crewInSlots)
                                  ]))
    }
    if (presetsList.len() == 0)
      return false

    blk = array_to_blk(presetsList, "preset")
    if (slotbarPresetsSeletected[countryId] != null)
      blk.selected <- slotbarPresetsSeletected[countryId]
  }

  if (blk == null) {
    script_net_assert_once("attempt_save_not_valid_presets", "Attempt save not valid presets")
    return false
  }

  if (isEqual(blk, cfgBlk))
    return false

  saveLocalByAccount($"slotbar_presets/{countryId}", blk, shouldSaveProfile ? forceSaveProfile : @() null)
  return true
}

function createSlotbarPreset() {
  if (!canCreateSlotbarPreset())
    return false
  let countryId = profileCountrySq.get()
  slotbarPresetsByCountry[countryId].append(createEmptyPreset(countryId, slotbarPresetsByCountry[countryId].len()))
  saveCountryPreset(countryId)
  broadcastEvent("SlotbarPresetsChanged", { showPreset = slotbarPresetsByCountry[countryId].len() - 1 })
  return true
}

function copySlotbarPreset(fromPreset) {
  if (!canCreateSlotbarPreset())
    return false
  let countryId = profileCountrySq.get()
  let newPreset = deep_clone(fromPreset).__update({ title = $"{fromPreset.title} *" })
  slotbarPresetsByCountry[countryId].append(newPreset)
  saveCountryPreset(countryId)
  broadcastEvent("SlotbarPresetsChanged", { showPreset = slotbarPresetsByCountry[countryId].len() - 1 })
  return true
}

function eraseSlotbarPreset(idx) {
  if (!canEraseSlotbarPreset())
    return false
  let countryId = profileCountrySq.get()
  if (idx == slotbarPresetsSeletected[countryId])
    return
  slotbarPresetsByCountry[countryId].remove(idx)
  if (slotbarPresetsSeletected[countryId] != null && slotbarPresetsSeletected[countryId] > idx)
    slotbarPresetsSeletected[countryId]--
  saveCountryPreset(countryId)
  broadcastEvent("SlotbarPresetsChanged", { showPreset = min(idx, slotbarPresetsByCountry[countryId].len() - 1) })
  return true
}

function moveSlotbarPreset(idx, offset) {
  let countryId = profileCountrySq.get()
  let newIdx = clamp(idx + offset, 0, slotbarPresetsByCountry[countryId].len() - 1)
  if (newIdx == idx)
    return false
  slotbarPresetsByCountry[countryId].insert(newIdx, slotbarPresetsByCountry[countryId].remove(idx))
  if (slotbarPresetsSeletected[countryId] != null) {
    if (slotbarPresetsSeletected[countryId] == idx)
      slotbarPresetsSeletected[countryId] = newIdx
    else if (slotbarPresetsSeletected[countryId] == newIdx)
      slotbarPresetsSeletected[countryId] = idx
    else if (slotbarPresetsSeletected[countryId] > min(idx, newIdx) && slotbarPresetsSeletected[countryId] < max(idx, newIdx))
      slotbarPresetsSeletected[countryId] += (offset > 0 ? -1 : 1)
  }
  saveCountryPreset(countryId)
  broadcastEvent("SlotbarPresetsChanged", { showPreset = newIdx })
  return true
}

function onChangePresetName(idx, newName, countryId) {
  let oldName = slotbarPresetsByCountry[countryId][idx].title
  if (oldName == newName)
    return

  slotbarPresetsByCountry[countryId][idx].title <- newName
  saveCountryPreset(countryId)
  broadcastEvent("SlotbarPresetsChanged", { showPreset = idx })
}

function saveAllCountries() {
  local hasChanges = false
  foreach (countryId in shopCountriesList)
    if (isCountryAvailable(countryId))
      hasChanges = saveCountryPreset(countryId, false) || hasChanges

  if (slotbarPresetsVersion.ver < PRESETS_VERSION) {
    slotbarPresetsVersion.ver = PRESETS_VERSION
    saveLocalByAccount($"slotbar_presets/{PRESETS_VERSION_SAVE_ID}", slotbarPresetsVersion.ver)
  }

  if (hasChanges)
    forceSaveProfile()
}


function renameSlotbarPreset(idx) {
  let countryId = profileCountrySq.get()
  if (!(countryId in slotbarPresetsByCountry) || !(idx in slotbarPresetsByCountry[countryId]))
    return

  let oldName = slotbarPresetsByCountry[countryId][idx].title
  openEditBoxDialog({
    title = loc("mainmenu/newPresetName")
    maxLen = 16
    value = oldName
    checkButtonFunc = @(value) value != null && clearBorderSymbols(value).len() > 0
    validateFunc = validatePresetName
    okFunc = @(newName) onChangePresetName(idx, clearBorderSymbols(newName), countryId)
  })
}

function getPresetDataByCountryAndUnitType(presetsData, country, unitType) {
  foreach (presetDataItem in presetsData.presetDataItems) {
    if (presetDataItem.country == country && presetDataItem.unitType == unitType)
      return presetDataItem
  }
  return null
}

function newbieInitSlotbarPresets(newbiePresetsData) {
  slotbarPresetsByCountry.clear()
  foreach (presetDataItem in newbiePresetsData.presetDataItems) {
    
    let countryId = presetDataItem.country
    if (countryId not in slotbarPresetsByCountry)
      slotbarPresetsByCountry[countryId] <- []
    if (!presetDataItem.hasUnits && !checkCanHaveEmptyPresets(countryId))
      continue
    let gameMode = getGameModeByUnitType(presetDataItem.unitType, -1, true)
    
    let preset = createPresetTemplate(0)
    preset.title = $"{loc("mainmenu/preset_default")} {unitTypes.getByEsUnitType(presetDataItem.unitType).fontIcon}"
    preset.gameModeId = getTblValue("id", gameMode, "")
    foreach (taskData in presetDataItem.tasksData) {
      if (taskData.airName == "")
        continue
      preset.units.append(taskData.airName)
      preset.crews.append(taskData.crewId)
      preset.crewInSlots.append(taskData.crewId)
      if (preset.selected == -1)
        preset.selected = taskData.crewId
    }
    updatePresetInfo(preset)
    slotbarPresetsByCountry[presetDataItem.country].append(preset)

    let presetIndex = slotbarPresetsByCountry[presetDataItem.country].len() - 1
    presetDataItem.presetIndex <- presetIndex

    if (newbiePresetsData.selectedCountry == presetDataItem.country &&
        newbiePresetsData.selectedUnitType == presetDataItem.unitType &&
        preset.gameModeId != "")
      setCurrentGameModeById(preset.gameModeId)
  }

  slotbarPresetsSeletected.clear()
  
  foreach (country in shopCountriesList) {
    if (!isCountryAvailable(country))
      continue

    let presetDataItem = getPresetDataByCountryAndUnitType(newbiePresetsData, country, newbiePresetsData.selectedUnitType)
    slotbarPresetsSeletected[country] <- getTblValue("presetIndex", presetDataItem, 0)
  }

  saveAllCountries()
}

function getPresetsList(countryId) {
  let res = []
  let blk = loadLocalByAccount($"slotbar_presets/{countryId}")
  if (blk) {
    let presetsBlk = blk % "preset"
    let countryCrews = getCrewsList().findvalue(@(crews) crews.country == countryId)?.crews.map(@(c) c.id) ?? []
    foreach (idx, strPreset in presetsBlk) {
      let data = split(strPreset, "|")
      if (data.len() < 3)
        continue
      let preset = createPresetTemplate(idx)
      preset.selected = to_integer_safe(data[0], -1)
      let title = validatePresetName(getTblValue(3, data, ""))
      if (title.len())
        preset.title = title
      preset.gameModeId = getTblValue(4, data, "")

      if (data.len() > 5 && data[5] != "") {
        preset.crewInSlots = data[5].split(",").map(@(v) to_integer_safe(v, 0, false))
        local lastExistingCrewIdx = -1
        local isBrokenCrewSort = false
        foreach (crewIdx, crewId in preset.crewInSlots) {
          if (countryCrews.indexof(crewId) == null)
            continue
          if ((crewIdx - 1) != lastExistingCrewIdx) {
            isBrokenCrewSort = true
            break
          }
          lastExistingCrewIdx = crewIdx
        }
        if (isBrokenCrewSort) {
          preset.crewInSlots.replace(countryCrews)
          let presetTitle = preset.title
          debug_dump_stack()
          logerr($"List of crews does not match crews in the preset /*presetTitle = {presetTitle}*/")
        } else if (lastExistingCrewIdx != (preset.crewInSlots.len() -1))
          preset.crewInSlots.resize(lastExistingCrewIdx + 1)
      }

      let canHaveEmptyPresets = checkCanHaveEmptyPresets(countryId)
      let unitNames = data[2] != "" ? split(data[2], ",") : []
      let crewIds = data[1] != "" ? split(data[1], ",") : []
      if ((!unitNames.len() && !canHaveEmptyPresets) || unitNames.len() != crewIds.len())
        continue

      
      for (local i = 0; i < unitNames.len(); i++) {
        let unitName = unitNames[i]
        local crewId = crewIds[i]
        if (crewId == "" && slotbarPresetsVersion.ver == 0)
          continue
        crewId = to_integer_safe(crewIds[i], -1)
        if (!getAircraftByName(unitName) || crewId < 0)
          continue

        preset.units.append(unitName)
        preset.crews.append(crewId)
      }

      if (!preset.units.len() && !canHaveEmptyPresets)
        continue

      updatePresetInfo(preset)

      res.append(preset)
      if (res.len() == getMaxPresetsCount(countryId))
        break
    }
  }
  if (!res.len()) {
    res.append(createPresetFromSlotbar(countryId))
    if (!isAlreadySendMissingPresetError && !reqFirstUnitTypeChoice()
        && hasDefaultUnitsInCountry(countryId)) {
      isAlreadySendMissingPresetError = true
      let blkString = toString(blk, 2)
      let isProfileReceivedValue = isProfileReceived.get()
      debug_dump_stack()
      logerr($"[SLOTBAR PRESETS]: presets is missing /*blkString = {blkString}, isProfileReceivedValue = {isProfileReceivedValue}*/")
    }
  }
  return res
}

function initCountry(countryId) {
  slotbarPresetsByCountry[countryId] <- getPresetsList(countryId)
  local selPresetId = loadLocalByAccount($"slotbar_presets/{countryId}/selected", null)
  let slotbarPreset = createPresetFromSlotbar(countryId)
  if (selPresetId != null && (selPresetId in slotbarPresetsByCountry[countryId])
      && isEqualPreset(slotbarPresetsByCountry[countryId][selPresetId], slotbarPreset)) {
    slotbarPresetsSeletected[countryId] <- selPresetId
    return
  }

  selPresetId = selPresetId != null && (selPresetId in slotbarPresetsByCountry[countryId])
    ? selPresetId
    : 0
  foreach (idx, preset in slotbarPresetsByCountry[countryId])
    if (isEqualPreset(preset, slotbarPreset)) {
      selPresetId = idx
      break
    }
  slotbarPresetsSeletected[countryId] <- selPresetId
}

function initSlotbarPresets() {
  isAlreadySendMissingPresetError = false
  slotbarPresetsVersion.ver = loadLocalByAccount($"slotbar_presets/{PRESETS_VERSION_SAVE_ID}", 0)
  foreach (country in shopCountriesList)
    if (isCountryAvailable(country))
      initCountry(country)
  logP($"init shopCountriesList count = {shopCountriesList.len()}")
  saveAllCountries() 
}

function savePresetGameMode(country) {
  let curGameModeId = getCurrentGameModeId()
  if (!curGameModeId)
    return

  let preset = getCurrentSlotbarPreset(country)
  if (!preset || curGameModeId == preset.gameModeId)
    return

  preset.gameModeId = curGameModeId
  saveCountryPreset(country)
}

function setCurrentGameModeByPreset(country, preset = null) {
  if (!isCountrySlotbarHasUnits(profileCountrySq.get()))
    return

  if (!preset)
    preset = getCurrentSlotbarPreset(profileCountrySq.get())

  local gameModeId = preset?.gameModeId ?? ""
  if (gameModeId == "") 
    gameModeId = getCurrentGameModeId()
  local gameMode = getGameModeById(gameModeId)
  
  
  if (gameMode == null) {
    gameModeId = findCurrentGameModeId(true)
    gameMode = getGameModeById(gameModeId)
  }

  
  
  if (gameMode != null && !isPresetValidForGameMode(preset, gameMode)) {
    let betterGameModeId = findCurrentGameModeId(true, gameMode.diffCode)
    if (betterGameModeId != null)
      gameMode = getGameModeById(betterGameModeId)
  }

  if (gameMode == null)
    return

  setCurrentGameModeById(gameMode.id)
  if (events.isEventsLoaded())
    savePresetGameMode(country)
}

function invalidateUnitsModificators(countryIdx) {
  let crews = getCrewsList()?[countryIdx]?.crews ?? []
  foreach (crew in crews) {
    let unit = getCrewUnit(crew)
    if (unit)
      unit.invalidateModificators()
  }
}

function onTrainCrewTasksFail() {
  flushSlotbarUpdate()
  isSlotbarPresetsLoading.set(false)
}

function onTrainCrewTasksSuccess(idx, countryIdx, countryId, selCrewIdx, _selUnitId, skipGameModeSelect, preset) {
  slotbarPresetsSeletected[countryId] = idx

  isSlotbarPresetsLoading.set(false)
  selectCrew(countryId, selCrewIdx, true)
  invalidateUnitsModificators(countryIdx)
  flushSlotbarUpdate()

  
  
  if (!skipGameModeSelect)
    setCurrentGameModeByPreset(countryId, preset)

  saveCountryPreset(countryId)

  broadcastEvent("SlotbarPresetLoaded", { crewsChanged = true })
}

function loadSlotbarPreset(idx, countryId = null, skipGameModeSelect = false) {
  if (!canLoadSlotbarPreset())
    return false
  countryId = countryId ?? profileCountrySq.get()
  saveCountryPreset(countryId) 

  let preset = getTblValue(idx, slotbarPresetsByCountry[countryId])
  if (!canLoadPreset(preset))
    return false

  if (!preset.enabled)
    return false

  local countryIdx = -1
  local countryCrews = []
  foreach (cIdx, tbl in getCrewsList())
    if (tbl.country == countryId) {
      countryIdx = cIdx
      countryCrews = tbl.crews
      break
    }
  if (countryIdx == -1 || !countryCrews.len())
    return false

  let unitsList = {}
  local selUnitId = ""
  local selCrewIdx = 0
  foreach (crewIdx, crew in countryCrews) {
    let crewTrainedUnits = getTblValue("trained", crew, [])
    foreach (i, unitId in preset.units) {
      let crewId = preset.crews[i]
      if (crewId == crew.id) {
        let unit = getAircraftByName(unitId)
        if (unit && unit.isInShop && isUnitUsable(unit)
            && (!unit.trainCost || isInArray(unitId, crewTrainedUnits))
            && !(unitId in unitsList)) {
          unitsList[unitId] <- crewId
          if (preset.selected == crewId) {
            selUnitId = unitId
            selCrewIdx = crewIdx
          }
        }
      }
    }
  }

  
  
  if (!unitsList.len() && !checkCanHaveEmptyPresets(countryId)) {
    let p = createEmptyPreset(countryId)
    foreach (i, unitId in p.units) {
      unitsList[unitId] <- p.crews[i]
      selUnitId = unitId
      selCrewIdx = i
    }
  }

  let tasksData = []
  foreach (crew in countryCrews) {
    let curUnitId = getTblValue("aircraft", crew, "")
    local unitId = ""
    foreach (uId, crewId in unitsList)
      if (crewId == crew.id)
        unitId = uId
    if (unitId != curUnitId)
      tasksData.append({ crewId = crew.id, airName = unitId })
  }

  if(tasksData.len() == 0) {
    onTrainCrewTasksSuccess(idx, countryIdx, countryId, selCrewIdx, selUnitId, skipGameModeSelect, preset)
    broadcastEvent("SlotbarPresetChangedWithoutProfileUpdate")
    return
  }

  isSlotbarPresetsLoading.set(true) 

  suspendSlotbarUpdates()
  invalidateUnitsModificators(countryIdx)
  batchTrainCrew(tasksData, { showProgressBox = true },
    @() onTrainCrewTasksSuccess(idx, countryIdx, countryId, selCrewIdx, selUnitId, skipGameModeSelect, preset),
    onTrainCrewTasksFail)

  return true
}

function swapValues(arr, values) {
  arr.apply(@(v) (v in values) ? values[v] : v)
}

function swapCrewsInCurrentPreset(crewIds) {
  let preset = getCurrentSlotbarPreset()
  let crewInSlots = preset?.crewInSlots
  if (crewInSlots == null)
    return
  swapValues(crewInSlots, crewIds)
  reorderUnitsInPreset(preset)
  saveCountryPreset()
  broadcastEvent("CrewsOrderChanged")
}

function replaceCrewsInCurrentPreset(countryId, crewIds) {
  let preset = getCurrentSlotbarPreset(countryId)
  let crewInSlots = preset?.crewInSlots
  if (crewInSlots == null)
    return
  crewInSlots.replace(crewIds)
  reorderUnitsInPreset(preset)
  saveCountryPreset()
  broadcastEvent("CrewsOrderChanged")
}

addListenersWithoutEnv({
  UnitBought             = @(_p) clearSlotsCache()
  SignOut                = @(_p) clearSlotsCache()

  function CurrentGameModeIdChanged(params) {
    if (params.isUserSelected)
      savePresetGameMode(profileCountrySq.get())
  }
})

return {
  ERA_ID_FOR_BONUS
  newbieInitSlotbarPresets
  initSlotbarPresets
  canEditCountryPreset
  canLoadSlotbarPreset
  canEraseSlotbarPreset
  havePresetsReserve
  getPresetsReseveTypesText
  getTotalPresetsCount
  canCreateSlotbarPreset
  createSlotbarPreset
  copySlotbarPreset
  eraseSlotbarPreset
  loadSlotbarPreset
  moveSlotbarPreset
  renameSlotbarPreset
  setCurrentGameModeByPreset
  swapCrewsInCurrentPreset
  replaceCrewsInCurrentPreset
}
