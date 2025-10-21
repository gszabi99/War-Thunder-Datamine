from "%scripts/dagui_library.nut" import *

let { array_to_blk } = require("%scripts/utils_sa.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { loadLocalByAccount, saveLocalByAccount
} = require("%scripts/clientState/localProfileDeprecated.nut")
let regexp2 = require("regexp2")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { subscribe_handler, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { isCountryAllCrewsUnlockedInHangar, isCountrySlotbarHasUnits, getSelectedCrews } = require("%scripts/slotbar/slotbarStateData.nut")
let { initSelectedCrews, selectCrew, flushSlotbarUpdate, suspendSlotbarUpdates } = require("%scripts/slotbar/slotbarState.nut")
let { clearBorderSymbols, split } = require("%sqstd/string.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { batchTrainCrew } = require("%scripts/crew/crewTrain.nut")
let { forceSaveProfile } = require("%scripts/clientState/saveProfile.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { deep_clone } = require("%sqstd/underscore.nut")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { isNeedFirstCountryChoice, isCountryAvailable } = require("%scripts/firstChoice/firstChoice.nut")
let { hasDefaultUnitsInCountry } = require("%scripts/shop/shopUnitsInfo.nut")
let { isEqual } = u
let logP = log_with_prefix("[SLOTBAR PRESETS] ")
let { debug_dump_stack } = require("dagor.debug")
let getAllUnits = require("%scripts/unit/allUnits.nut")
let { getUnitCountry } = require("%scripts/unit/unitInfo.nut")
let { getEsUnitType } = require("%scripts/unit/unitParams.nut")
let { isUnitBought } = require("%scripts/unit/unitShopInfo.nut")
let { isUnitUsable } = require("%scripts/unit/unitStatus.nut")
let { isInMenu } = require("%scripts/clientState/clientStates.nut")
let { getCurrentGameModeId, setCurrentGameModeById, getGameModeById,
  getGameModeByUnitType, findCurrentGameModeId, isPresetValidForGameMode
} = require("%scripts/gameModes/gameModeManagerState.nut")
let { getCrewUnit } = require("%scripts/crew/crew.nut")
let { getCrewsList, getCrewsListByCountry } = require("%scripts/slotbar/crewsList.nut")
let openEditBoxDialog = require("%scripts/wndLib/editBoxHandler.nut")
let { isProfileReceived } = require("%appGlobals/login/loginState.nut")
let { isInvalidCrewsAllowed } = require("%scripts/matchingRooms/sessionLobbyState.nut")
let { isUnitAllowedForRoom } = require("%scripts/matchingRooms/sessionLobbyInfo.nut")
let { isCanModifyCrew } = require("%scripts/queue/queueManager.nut")


require("%scripts/slotbar/hangarVehiclesPreset.nut")

local isAlreadySendMissingPresetError = false

const PRESETS_VERSION = 1
const PRESETS_VERSION_SAVE_ID = "presetsVersion"

let isEqualPreset = @(p1, p2) isEqual(p1.crews, p2.crews) && isEqual(p1.units, p2.units)

let slotbarPresetsByCountry = persist("slotbarPresetsByCountry", @() {})
let slotbarPresetsSeletected = persist("slotbarPresetsSeletected", @() {})
let slotbarPresetsVersion = persist("slotbarPresetsVersion", @() {ver=0})

local slotbarPresets = null
slotbarPresets = {
  activeTypeBonusByCountry = null

  baseCountryPresetsAmount = 8
  eraBonusPresetsAmount = 2  
  eraIdForBonus = 5
  minCountryPresets = 1

  isLoading = false
  validatePresetNameRegexp = regexp2(@"^#|[;|\\<>]")

  
  presets = slotbarPresetsByCountry

  
  selected = slotbarPresetsSeletected

  function init() {
    isAlreadySendMissingPresetError = false
    slotbarPresetsVersion.ver = loadLocalByAccount($"slotbar_presets/{PRESETS_VERSION_SAVE_ID}", 0)
    foreach (country in shopCountriesList)
      if (isCountryAvailable(country))
        this.initCountry(country)
    logP("init")
    this.saveAllCountries() 
  }

  function newbieInit(newbiePresetsData) {
    slotbarPresetsByCountry.clear()
    foreach (presetDataItem in newbiePresetsData.presetDataItems) {
      
      let countryId = presetDataItem.country
      slotbarPresetsByCountry[countryId] <- this.presets?[countryId] ?? []
      if (!presetDataItem.hasUnits && !this.canHaveEmptyPresets(countryId))
        continue
      let gameMode = getGameModeByUnitType(presetDataItem.unitType, -1, true)
      
      let preset = this._createPresetTemplate(0)
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
      this._updateInfo(preset)
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

      let presetDataItem = this.getPresetDataByCountryAndUnitType(newbiePresetsData, country, newbiePresetsData.selectedUnitType)
      slotbarPresetsSeletected[country] <- getTblValue("presetIndex", presetDataItem, 0)
    }

    this.saveAllCountries()
  }

  function getPresetDataByCountryAndUnitType(presetsData, country, unitType) {
    foreach (presetDataItem in presetsData.presetDataItems) {
      if (presetDataItem.country == country && presetDataItem.unitType == unitType)
        return presetDataItem
    }
    return null
  }

  function initCountry(countryId) {
    slotbarPresetsByCountry[countryId] <- this.getPresetsList(countryId)
    local selPresetId = loadLocalByAccount($"slotbar_presets/{countryId}/selected", null)
    let slotbarPreset = this.createPresetFromSlotbar(countryId)
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

  function list(countryId = null) {
    countryId = countryId ?? profileCountrySq.get()
    let res = []
    if (!(countryId in slotbarPresetsByCountry)) {
      res.append(this.createPresetFromSlotbar(countryId))
      return res
    }

    let currentIdx = this.getCurrent(countryId, -1)
    foreach (idx, preset in slotbarPresetsByCountry[countryId]) {
      if (idx == currentIdx)
        this.updatePresetFromSlotbar(preset, countryId)
      res.append(preset)
    }

    return res
  }

  function getCurrent(country = null, defValue = -1) {
    country = country ?? profileCountrySq.get()
    return (country in slotbarPresetsSeletected) ? slotbarPresetsSeletected[country] : defValue
  }

  




  function getCurrentPreset(country = null) {
    country = country ?? profileCountrySq.get()
    let index = this.getCurrent(country, -1)
    return this.list(country)?[index]
  }

  function canCreate() {
    local countryId = profileCountrySq.get()
    return (countryId in slotbarPresetsByCountry) && slotbarPresetsByCountry[countryId].len() < this.getMaxPresetsCount(countryId)
      && this.canEditCountryPresets(countryId)
  }

  function canEditCountryPresets(country = null) {
    country = country ?? profileCountrySq.get()
    return isCountrySlotbarHasUnits(country)
      || this.canHaveEmptyPresets(country)
  }

  canHaveEmptyPresets = @(country) !hasDefaultUnitsInCountry(country)

  function getPresetsReseveTypesText(country = null) {
    country = country ?? profileCountrySq.get()
    let types = this.getUnitTypesWithNotActivePresetBonus(country)
    local typeNames = types.map(@(unit) unit.getArmyLocName())
    return ", ".join(typeNames, true)
  }

  function havePresetsReserve(country = null) {
    country = country ?? profileCountrySq.get()
    return this.getUnitTypesWithNotActivePresetBonus(country).len() > 0
  }

  function getMaxPresetsCount(country = null) {
    country = country ?? profileCountrySq.get()
    this.validateSlotsCountCache()
    local result = this.baseCountryPresetsAmount
    foreach (_unitType, typeStatus in getTblValue(country, this.activeTypeBonusByCountry, {}))
      if (typeStatus)
        result += this.eraBonusPresetsAmount
    return result
  }

  function getTotalPresetsCount() {
    return this.baseCountryPresetsAmount + unitTypes.types.len() * this.eraBonusPresetsAmount
  }

  function getUnitTypesWithNotActivePresetBonus(country = null) {
    country = country ?? profileCountrySq.get()
    this.validateSlotsCountCache()
    let result = []
    foreach (unitType, typeStatus in getTblValue(country, this.activeTypeBonusByCountry, {}))
      if (! typeStatus)
        result.append(unitType)
    return result
  }

  function clearSlotsCache() {
    this.activeTypeBonusByCountry = null
  }

  function validateSlotsCountCache() {
    if (this.activeTypeBonusByCountry)
      return

    this.activeTypeBonusByCountry = {}

    foreach (unit in getAllUnits()) {
      if (unit.rank != this.eraIdForBonus ||
          ! unit.unitType.isAvailable() ||
          ! unit.isVisibleInShop())
        continue

      let countryName = getUnitCountry(unit)
      if (! (countryName in this.activeTypeBonusByCountry))
        this.activeTypeBonusByCountry[countryName] <- {}

      if (! (unit.unitType in this.activeTypeBonusByCountry[countryName]))
        this.activeTypeBonusByCountry[countryName][unit.unitType] <- false

      if (isUnitBought(unit))
        this.activeTypeBonusByCountry[countryName][unit.unitType] = true
    }
  }

  function onEventUnitBought(_params) {
    this.clearSlotsCache()
  }

  function  onEventSignOut(_params) {
    this.clearSlotsCache()
  }

  function create() {
    if (!this.canCreate())
      return false
    let countryId = profileCountrySq.get()
    slotbarPresetsByCountry[countryId].append(this.createEmptyPreset(countryId, slotbarPresetsByCountry[countryId].len()))
    this.save(countryId)
    broadcastEvent("SlotbarPresetsChanged", { showPreset = slotbarPresetsByCountry[countryId].len() - 1 })
    return true
  }

  function copyPreset(fromPreset) {
    if (!this.canCreate())
      return false
    let countryId = profileCountrySq.get()
    let newPreset = deep_clone(fromPreset).__update({ title = $"{fromPreset.title} *" })
    slotbarPresetsByCountry[countryId].append(newPreset)
    this.save(countryId)
    broadcastEvent("SlotbarPresetsChanged", { showPreset = slotbarPresetsByCountry[countryId].len() - 1 })
    return true
  }

  function canErase() {
    let countryId = profileCountrySq.get()
    return (countryId in slotbarPresetsByCountry) && slotbarPresetsByCountry[countryId].len() > this.minCountryPresets
  }

  function erase(idx) {
    if (!this.canErase())
      return false
    let countryId = profileCountrySq.get()
    if (idx == slotbarPresetsSeletected[countryId])
      return
    slotbarPresetsByCountry[countryId].remove(idx)
    if (slotbarPresetsSeletected[countryId] != null && slotbarPresetsSeletected[countryId] > idx)
      slotbarPresetsSeletected[countryId]--
    this.save(countryId)
    broadcastEvent("SlotbarPresetsChanged", { showPreset = min(idx, slotbarPresetsByCountry[countryId].len() - 1) })
    return true
  }

  function move(idx, offset) {
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
    this.save(countryId)
    broadcastEvent("SlotbarPresetsChanged", { showPreset = newIdx })
    return true
  }

  function validatePresetName(name) {
    return this.validatePresetNameRegexp.replace("", name)
  }

  function rename(idx) {
    let countryId = profileCountrySq.get()
    if (!(countryId in slotbarPresetsByCountry) || !(idx in slotbarPresetsByCountry[countryId]))
      return

    let oldName = slotbarPresetsByCountry[countryId][idx].title
    openEditBoxDialog({
                      title = loc("mainmenu/newPresetName"),
                      maxLen = 16,
                      value = oldName,
                      owner = this,
                      checkButtonFunc = function (value) {
                        return value != null && clearBorderSymbols(value).len() > 0
                      },
                      validateFunc = function (value) {
                        return slotbarPresets.validatePresetName(value)
                      },
                      okFunc = @(newName) this.onChangePresetName(idx, clearBorderSymbols(newName), countryId)
                    })
  }

  function onChangePresetName(idx, newName, countryId) {
    let oldName = slotbarPresetsByCountry[countryId][idx].title
    if (oldName == newName)
      return

    slotbarPresetsByCountry[countryId][idx].title <- newName
    this.save(countryId)
    broadcastEvent("SlotbarPresetsChanged", { showPreset = idx })
  }

  function saveAllCountries() {
    local hasChanges = false
    foreach (countryId in shopCountriesList)
      if (isCountryAvailable(countryId))
        hasChanges = this.save(countryId, false) || hasChanges

    if (slotbarPresetsVersion.ver < PRESETS_VERSION) {
      slotbarPresetsVersion.ver = PRESETS_VERSION
      saveLocalByAccount($"slotbar_presets/{PRESETS_VERSION_SAVE_ID}", slotbarPresetsVersion.ver)
    }

    if (hasChanges)
      forceSaveProfile()
  }

  function save(countryId = null, shouldSaveProfile = true) {
    if (!countryId)
      countryId = profileCountrySq.get()
    if (!this.canEditCountryPresets(countryId) || !(countryId in slotbarPresetsByCountry))
      return false
    let cfgBlk = loadLocalByAccount($"slotbar_presets/{countryId}")
    local blk = null
    if (slotbarPresetsByCountry[countryId].len() > 0) {
      let curPreset = getTblValue(slotbarPresetsSeletected[countryId], slotbarPresetsByCountry[countryId])
      if (curPreset && countryId == profileCountrySq.get())
        this.updatePresetFromSlotbar(curPreset, countryId)

      let presetsList = []
      foreach (_idx, p in slotbarPresetsByCountry[countryId]) {
        if (p.units.len() == 0 && !this.canHaveEmptyPresets(countryId))
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

    if (u.isEqual(blk, cfgBlk))
      return false

    saveLocalByAccount($"slotbar_presets/{countryId}", blk, shouldSaveProfile ? forceSaveProfile : @() null)
    return true
  }

  function canLoad(verbose = false, country = null) {
    if (this.isLoading)
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

  function load(idx, countryId = null, skipGameModeSelect = false) {
    if (!this.canLoad())
      return false
    countryId = countryId ?? profileCountrySq.get()
    this.save(countryId) 

    let preset = getTblValue(idx, slotbarPresetsByCountry[countryId])
    if (!this.canLoadPreset(preset))
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

    
    
    if (!unitsList.len() && !this.canHaveEmptyPresets(countryId)) {
      let p = this.createEmptyPreset(countryId)
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
      this.onTrainCrewTasksSuccess(idx, countryIdx, countryId, selCrewIdx, selUnitId, skipGameModeSelect, preset)
      broadcastEvent("SlotbarPresetChangedWithoutProfileUpdate")
      return
    }

    this.isLoading = true 

    suspendSlotbarUpdates()
    this.invalidateUnitsModificators(countryIdx)
    batchTrainCrew(tasksData, { showProgressBox = true },
      @() this.onTrainCrewTasksSuccess(idx, countryIdx, countryId, selCrewIdx, selUnitId, skipGameModeSelect, preset),
      function (_taskResult = -1) {
        flushSlotbarUpdate()
        this.onTrainCrewTasksFail()
      },
      slotbarPresets)

    return true
  }

  function onTrainCrewTasksSuccess(idx, countryIdx, countryId, selCrewIdx, _selUnitId, skipGameModeSelect, preset) {
    slotbarPresetsSeletected[countryId] = idx

    this.isLoading = false
    selectCrew(countryIdx, selCrewIdx, true)
    this.invalidateUnitsModificators(countryIdx)
    flushSlotbarUpdate()

    
    
    if (!skipGameModeSelect) {
      this.setCurrentGameModeByPreset(countryId, preset)
    }

    this.save(countryId)

    broadcastEvent("SlotbarPresetLoaded", { crewsChanged = true })
  }

  function setCurrentGameModeByPreset(country, preset = null) {
    if (!isCountrySlotbarHasUnits(profileCountrySq.get()))
      return

    if (!preset)
      preset = this.getCurrentPreset(profileCountrySq.get())

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
    this.savePresetGameMode(country)
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
    this.isLoading = false
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
        let preset = this._createPresetTemplate(idx)
        preset.selected = to_integer_safe(data[0], -1)
        let title = this.validatePresetName(getTblValue(3, data, ""))
        if (title.len())
          preset.title = title
        preset.gameModeId = getTblValue(4, data, "")

        if(data.len() > 5 && data[5] != "") {
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

        let canHaveEmptyPresets = this.canHaveEmptyPresets(countryId)
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

        this._updateInfo(preset)

        res.append(preset)
        if (res.len() == this.getMaxPresetsCount(countryId))
          break
      }
    }
    if (!res.len()) {
      res.append(this.createPresetFromSlotbar(countryId))
      if (!isAlreadySendMissingPresetError && !isNeedFirstCountryChoice()
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

  function _createPresetTemplate(presetIdx) {
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

  function _updateInfo(preset) {
    local unitTypesMask = 0
    foreach (unitId in preset.units) {
      let unit = getAircraftByName(unitId)
      let unitType = unit ? getEsUnitType(unit) : ES_UNIT_TYPE_INVALID
      if (unitType != ES_UNIT_TYPE_INVALID)
        unitTypesMask = unitTypesMask | (1 << unitType)
    }

    preset.unitTypesMask = unitTypesMask
    preset.enabled = true
    this.reorderUnitsInPreset(preset)

    return preset
  }

  function updatePresetFromSlotbar(preset, countryId) {
    if (this.isLoading)    
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

    if ((units.len() == 0 || crews.len() == 0) && !this.canHaveEmptyPresets(countryId))
      return preset 

    preset.units = units
    preset.crews = crews
    preset.selected = selected
    preset.crewInSlots = crewInSlots

    this._updateInfo(preset)
    return preset
  }

  function createPresetFromSlotbar(countryId, presetIdx = 0) {
    return this.updatePresetFromSlotbar(this._createPresetTemplate(presetIdx), countryId)
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

    let preset = this._createPresetTemplate(presetIdx)
    if (unitToSet) {
      preset.units = [ unitToSet.name ]
      preset.crews = [ crewToSet.id ]
      preset.crewInSlots = [ crewToSet.id ]
      preset.selected = crewToSet.id
      this._updateInfo(preset)
    }
    return preset
  }

  function savePresetGameMode(country) {
     let curGameModeId = getCurrentGameModeId()
     if (!curGameModeId)
       return

     let preset = this.getCurrentPreset(country)
     if (!preset || curGameModeId == preset.gameModeId)
       return

     preset.gameModeId = curGameModeId
     this.save(country)
  }

  function onEventCurrentGameModeIdChanged(params) {
    if (params.isUserSelected)
      this.savePresetGameMode(profileCountrySq.get())
  }

  function swapCrewsInCurrentPreset(crewIds) {
    let preset = this.getCurrentPreset()
    let crewInSlots = preset?.crewInSlots
    if(crewInSlots == null)
      return
    this.swapValues(crewInSlots, crewIds)
    this.reorderUnitsInPreset(preset)
    this.save()
    broadcastEvent("CrewsOrderChanged")
  }

  function swapValues(arr, values) {
    arr.apply(@(v) (v in values) ? values[v] : v)
  }

  function replaceCrewsInCurrentPreset(countryId, crewIds) {
    let preset = this.getCurrentPreset(countryId)
    let crewInSlots = preset?.crewInSlots
    if(crewInSlots == null)
      return
    crewInSlots.replace(crewIds)
    this.reorderUnitsInPreset(preset)
    this.save()
    broadcastEvent("CrewsOrderChanged")
  }

  function reorderUnitsInPreset(preset) {
    let unitsOrder = preset.crews.map(@(c) preset.crewInSlots.indexof(c))
    preset.orderedUnits <- preset.units
      .map(@(unit, index) { unit, order = unitsOrder[index] })
      .sort(@(u1, u2) u1.order <=> u2.order)
      .map(@(unit) unit.unit)
  }
}

subscribe_handler(slotbarPresets)

::slotbarPresets <- slotbarPresets 

return slotbarPresets
