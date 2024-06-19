//-file:plus-string
from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")
let { loadLocalByAccount, saveLocalByAccount
} = require("%scripts/clientState/localProfileDeprecated.nut")
let regexp2 = require("regexp2")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { subscribe_handler, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { isCountrySlotbarHasUnits, initSelectedCrews, getCrewsListByCountry,
  isCountryAllCrewsUnlockedInHangar, selectCrew, getSelectedCrews
} = require("%scripts/slotbar/slotbarState.nut")
let { clearBorderSymbols, split } = require("%sqstd/string.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { batchTrainCrew } = require("%scripts/crew/crewActions.nut")
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
let { getEsUnitType, getUnitCountry } = require("%scripts/unit/unitInfo.nut")
let { isInMenu } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getCurrentGameModeId, setCurrentGameModeById, getGameModeById,
  getGameModeByUnitType, findCurrentGameModeId, isPresetValidForGameMode
} = require("%scripts/gameModes/gameModeManagerState.nut")
let { getCrewUnit } = require("%scripts/crew/crew.nut")
let { flushSlotbarUpdate, suspendSlotbarUpdates, getCrewsList
} = require("%scripts/slotbar/crewsList.nut")

// Independed Modules
require("%scripts/slotbar/hangarVehiclesPreset.nut")

local isAlreadySendMissingPresetError = false

const PRESETS_VERSION = 1
const PRESETS_VERSION_SAVE_ID = "presetsVersion"

let isEqualPreset = @(p1, p2) isEqual(p1.crews, p2.crews) && isEqual(p1.units, p2.units)

let slotbarPresets = persist("slotbarPresets", @() {})
let slotbarPresetsSeletected = persist("slotbarPresetsSeletected", @() {})
let slotbarPresetsVersion = persist("slotbarPresetsVersion", @() {ver=0})

::slotbarPresets <- {
  activeTypeBonusByCountry = null

  baseCountryPresetsAmount = 8
  eraBonusPresetsAmount = 2  // amount of five era bonus, given for each unit type
  eraIdForBonus = 5
  minCountryPresets = 1

  isLoading = false
  validatePresetNameRegexp = regexp2(@"^#|[;|\\<>]")

  /** Array of presets by country id. */
  presets = slotbarPresets

  /** Selected preset index by country id. */
  selected = slotbarPresetsSeletected

  function init() {
    isAlreadySendMissingPresetError = false
    slotbarPresetsVersion.ver = loadLocalByAccount($"slotbar_presets/{PRESETS_VERSION_SAVE_ID}", 0)
    foreach (country in shopCountriesList)
      if (isCountryAvailable(country))
        this.initCountry(country)
    logP("init")
    this.saveAllCountries() // maintenance
  }

  function newbieInit(newbiePresetsData) {
    slotbarPresets.clear()
    foreach (presetDataItem in newbiePresetsData.presetDataItems) {
      // This adds empty array to presets table if not already.
      slotbarPresets[presetDataItem.country] <- getTblValue(presetDataItem.country, this.presets, [])
      if (!presetDataItem.hasUnits)
        continue
      let gameMode = getGameModeByUnitType(presetDataItem.unitType, -1, true)
      // Creating preset from preset data item.
      let preset = this._createPresetTemplate(0)
      preset.title = $"{loc("mainmenu/preset_default")} {unitTypes.getByEsUnitType(presetDataItem.unitType).fontIcon}"
      preset.gameModeId = getTblValue("id", gameMode, "")
      foreach (taskData in presetDataItem.tasksData) {
        if (taskData.airName == "")
          continue
        preset.units.append(taskData.airName)
        preset.crews.append(taskData.crewId)
        if (preset.selected == -1)
          preset.selected = taskData.crewId
      }
      this._updateInfo(preset)
      slotbarPresets[presetDataItem.country].append(preset)

      let presetIndex = slotbarPresets[presetDataItem.country].len() - 1
      presetDataItem.presetIndex <- presetIndex

      if (newbiePresetsData.selectedCountry == presetDataItem.country &&
          newbiePresetsData.selectedUnitType == presetDataItem.unitType &&
          preset.gameModeId != "")
        setCurrentGameModeById(preset.gameModeId)
    }

    slotbarPresetsSeletected.clear()
    // Attempting to select preset with selected unit type for each country.
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
    slotbarPresets[countryId] <- this.getPresetsList(countryId)
    local selPresetId = loadLocalByAccount("slotbar_presets/" + countryId + "/selected", null)
    let slotbarPreset = this.createPresetFromSlotbar(countryId)
    if (selPresetId != null && (selPresetId in slotbarPresets[countryId])
        && isEqualPreset(slotbarPresets[countryId][selPresetId], slotbarPreset)) {
      slotbarPresetsSeletected[countryId] <- selPresetId
      return
    }

    selPresetId = selPresetId != null && (selPresetId in slotbarPresets[countryId])
      ? selPresetId
      : 0
    foreach (idx, preset in slotbarPresets[countryId])
      if (isEqualPreset(preset, slotbarPreset)) {
        selPresetId = idx
        break
      }
    slotbarPresetsSeletected[countryId] <- selPresetId
  }

  function list(countryId = null) {
    countryId = countryId ?? profileCountrySq.value
    let res = []
    if (!(countryId in slotbarPresets)) {
      res.append(this.createPresetFromSlotbar(countryId))
      return res
    }

    let currentIdx = this.getCurrent(countryId, -1)
    foreach (idx, preset in slotbarPresets[countryId]) {
      if (idx == currentIdx)
        this.updatePresetFromSlotbar(preset, countryId)
      res.append(preset)
    }

    return res
  }

  function getCurrent(country = null, defValue = -1) {
    country = country ?? profileCountrySq.value
    return (country in slotbarPresetsSeletected) ? slotbarPresetsSeletected[country] : defValue
  }

  /**
   * Returns selected preset for specified country.
   * @param  {string} country If not specified then current
   *                          profile-selected country is used.
   */
  function getCurrentPreset(country = null) {
    country = country ?? profileCountrySq.value
    let index = this.getCurrent(country, -1)
    let currentPresets = getTblValue(country, slotbarPresets)
    return getTblValue(index, currentPresets)
  }

  function canCreate() {
    local countryId = profileCountrySq.value
    return (countryId in slotbarPresets) && slotbarPresets[countryId].len() < this.getMaxPresetsCount(countryId)
      && this.canEditCountryPresets(countryId)
  }

  function canEditCountryPresets(country = null) {
    return isCountrySlotbarHasUnits(country ?? profileCountrySq.value)
  }

  function getPresetsReseveTypesText(country = null) {
    country = country ?? profileCountrySq.value
    let types = this.getUnitTypesWithNotActivePresetBonus(country)
    local typeNames = types.map(@(unit) unit.getArmyLocName())
    return ", ".join(typeNames, true)
  }

  function havePresetsReserve(country = null) {
    country = country ?? profileCountrySq.value
    return this.getUnitTypesWithNotActivePresetBonus(country).len() > 0
  }

  function getMaxPresetsCount(country = null) {
    country = country ?? profileCountrySq.value
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
    country = country ?? profileCountrySq.value
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

      if (::isUnitBought(unit))
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
    let countryId = profileCountrySq.value
    slotbarPresets[countryId].append(this.createEmptyPreset(countryId, slotbarPresets[countryId].len()))
    this.save(countryId)
    broadcastEvent("SlotbarPresetsChanged", { showPreset = slotbarPresets[countryId].len() - 1 })
    return true
  }

  function copyPreset(fromPreset) {
    if (!this.canCreate())
      return false
    let countryId = profileCountrySq.value
    let newPreset = deep_clone(fromPreset).__update({ title = $"{fromPreset.title} *" })
    slotbarPresets[countryId].append(newPreset)
    this.save(countryId)
    broadcastEvent("SlotbarPresetsChanged", { showPreset = slotbarPresets[countryId].len() - 1 })
    return true
  }

  function canErase() {
    let countryId = profileCountrySq.value
    return (countryId in slotbarPresets) && slotbarPresets[countryId].len() > this.minCountryPresets
  }

  function erase(idx) {
    if (!this.canErase())
      return false
    let countryId = profileCountrySq.value
    if (idx == slotbarPresetsSeletected[countryId])
      return
    slotbarPresets[countryId].remove(idx)
    if (slotbarPresetsSeletected[countryId] != null && slotbarPresetsSeletected[countryId] > idx)
      slotbarPresetsSeletected[countryId]--
    this.save(countryId)
    broadcastEvent("SlotbarPresetsChanged", { showPreset = min(idx, slotbarPresets[countryId].len() - 1) })
    return true
  }

  function move(idx, offset) {
    let countryId = profileCountrySq.value
    let newIdx = clamp(idx + offset, 0, slotbarPresets[countryId].len() - 1)
    if (newIdx == idx)
      return false
    slotbarPresets[countryId].insert(newIdx, slotbarPresets[countryId].remove(idx))
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
    let countryId = profileCountrySq.value
    if (!(countryId in slotbarPresets) || !(idx in slotbarPresets[countryId]))
      return

    let oldName = slotbarPresets[countryId][idx].title
    ::gui_modal_editbox_wnd({
                      title = loc("mainmenu/newPresetName"),
                      maxLen = 16,
                      value = oldName,
                      owner = this,
                      checkButtonFunc = function (value) {
                        return value != null && clearBorderSymbols(value).len() > 0
                      },
                      validateFunc = function (value) {
                        return ::slotbarPresets.validatePresetName(value)
                      },
                      okFunc = @(newName) this.onChangePresetName(idx, clearBorderSymbols(newName), countryId)
                    })
  }

  function onChangePresetName(idx, newName, countryId) {
    let oldName = slotbarPresets[countryId][idx].title
    if (oldName == newName)
      return

    slotbarPresets[countryId][idx].title <- newName
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
      countryId = profileCountrySq.value
    if (!this.canEditCountryPresets(countryId) || !(countryId in slotbarPresets))
      return false
    let cfgBlk = loadLocalByAccount("slotbar_presets/" + countryId)
    local blk = null
    if (slotbarPresets[countryId].len() > 0) {
      let curPreset = getTblValue(slotbarPresetsSeletected[countryId], slotbarPresets[countryId])
      if (curPreset && countryId == profileCountrySq.value)
        this.updatePresetFromSlotbar(curPreset, countryId)

      let presetsList = []
      foreach (_idx, p in slotbarPresets[countryId]) {
        if (p.units.len() == 0)
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

      blk = ::array_to_blk(presetsList, "preset")
      if (slotbarPresetsSeletected[countryId] != null)
        blk.selected <- slotbarPresetsSeletected[countryId]
    }

    if (blk == null) {
      script_net_assert_once("attempt_save_not_valid_presets", "Attempt save not valid presets")
      return false
    }

    if (u.isEqual(blk, cfgBlk))
      return false

    saveLocalByAccount("slotbar_presets/" + countryId, blk, shouldSaveProfile ? forceSaveProfile : @() null)
    return true
  }

  function canLoad(verbose = false, country = null) {
    if (this.isLoading)
      return false
    country = country ?? profileCountrySq.value
    if (!(country in slotbarPresets) || !isInMenu() || !::queues.isCanModifyCrew())
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
    if (::SessionLobby.isInvalidCrewsAllowed())
      return true

    foreach (unitName in preset.units) {
      let unit = getAircraftByName(unitName)
      if (unit && ::SessionLobby.isUnitAllowed(unit))
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
    countryId = countryId ?? profileCountrySq.value
    this.save(countryId) //save current preset slotbar changes

    let preset = getTblValue(idx, slotbarPresets[countryId])
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
          if (unit && unit.isInShop && ::isUnitUsable(unit)
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

    // Sometimes preset can consist of only invalid units (like expired rented units), so here
    // we automatically overwrite this permanently unloadable preset with valid one.
    if (!unitsList.len()) {
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

    this.isLoading = true // Blocking slotbar content and game mode id from overwritting during 'batchTrainCrew' call.

    suspendSlotbarUpdates()
    this.invalidateUnitsModificators(countryIdx)
    batchTrainCrew(tasksData, { showProgressBox = true },
      @() this.onTrainCrewTasksSuccess(idx, countryIdx, countryId, selCrewIdx, selUnitId, skipGameModeSelect, preset),
      function (_taskResult = -1) {
        flushSlotbarUpdate()
        this.onTrainCrewTasksFail()
      },
      ::slotbarPresets)

    return true
  }

  function onTrainCrewTasksSuccess(idx, countryIdx, countryId, selCrewIdx, _selUnitId, skipGameModeSelect, preset) {
    slotbarPresetsSeletected[countryId] = idx

    this.isLoading = false
    selectCrew(countryIdx, selCrewIdx, true)
    this.invalidateUnitsModificators(countryIdx)
    flushSlotbarUpdate()

    // Game mode select is performed only
    // after successful slotbar vehicles change.
    if (!skipGameModeSelect) {
      this.setCurrentGameModeByPreset(countryId, preset)
    }

    this.save(countryId)

    broadcastEvent("SlotbarPresetLoaded", { crewsChanged = true })
  }

  function setCurrentGameModeByPreset(country, preset = null) {
    if (!isCountrySlotbarHasUnits(profileCountrySq.value))
      return

    if (!preset)
      preset = this.getCurrentPreset(profileCountrySq.value)

    local gameModeId = preset?.gameModeId ?? ""
    if (gameModeId == "") //try use current game mode if game mode for preset not defined
      gameModeId = getCurrentGameModeId()
    local gameMode = getGameModeById(gameModeId)
    // This means that some game mode id is
    // linked to preset but can not be found.
    if (gameMode == null) {
      gameModeId = findCurrentGameModeId(true)
      gameMode = getGameModeById(gameModeId)
    }

    // If game mode is not valid for preset
    // we will try to find better one.
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
    let blk = loadLocalByAccount("slotbar_presets/" + countryId)
    if (blk) {
      let presetsBlk = blk % "preset"
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

        if(data.len() > 5 && data[5] != "")
          preset.crewInSlots = data[5].split(",").map(@(v) to_integer_safe(v, 0, false))

        let unitNames = split(data[2], ",")
        let crewIds = split(data[1], ",")
        if (!unitNames.len() || unitNames.len() != crewIds.len())
          continue

        //validate crews and units
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

        if (!preset.units.len())
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
        let blkString = toString(blk, 2)                      // warning disable: -declared-never-used
        let isProfileReceived = ::g_login.isProfileReceived() // warning disable: -declared-never-used
        debug_dump_stack()
        logerr("[SLOTBAR PRESETS]: presets is missing")
      }
    }
    return res
  }

  function _createPresetTemplate(presetIdx) {
    return {
      units = []
      crews = []
      crewInSlots = []
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

    return preset
  }

  function updatePresetFromSlotbar(preset, countryId) {
    if (this.isLoading)    //not need update preset from slotbar if loading process
      return preset   //but can not return null, because this value used in create new preset

    initSelectedCrews()
    let units = []
    let crews = []
    local selected = preset.selected
    foreach (tbl in getCrewsList())
      if (tbl.country == countryId) {
        foreach (crew in tbl.crews)
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

    if (units.len() == 0 || crews.len() == 0) //not found crews and units for country
      return preset                           //so not need update preset from slotbar

    preset.units = units
    preset.crews = crews
    preset.selected = selected
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
      this.savePresetGameMode(profileCountrySq.value)
  }

  function swapCrewsInCurrentPreset(crewIds) {
    let crewInSlots = this.getCurrentPreset()?.crewInSlots
    if(crewInSlots == null)
      return
    this.swapValues(crewInSlots, crewIds)
    this.save()
  }

  function updateCrewsInCurrentPreset(countryId, crewIds) {
    let crewInSlots = this.getCurrentPreset(countryId)?.crewInSlots
    if(crewInSlots == null)
      return
    let newCrews = crewIds.filter(@(c) crewInSlots.indexof(c) == null)
    crewInSlots.extend(newCrews)
    this.save(countryId)
  }

  function swapValues(arr, values) {
    arr.apply(@(v) (v in values) ? values[v] : v)
  }
}

subscribe_handler(::slotbarPresets)
