from "%scripts/dagui_natives.nut" import char_send_blk
from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { move_mouse_on_child } = require("%sqDagui/daguiUtil.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { find_in_array } = require("%sqStdLibs/helpers/u.nut")
let { rnd } = require("dagor.random")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { checkUnlockedCountriesByAirs, unlockCountry, getFirstChosenUnitType, isFirstChoiceShown,
  fillUserNick } = require("%scripts/firstChoice/firstChoice.nut")
let { switchProfileCountry } = require("%scripts/user/playerCountry.nut")
let { sendBqEvent } = require("%scripts/bqQueue/bqQueue.nut")
let { getReserveAircraftName } = require("%scripts/slotbar/slotbarStateData.nut")
let { getCrewUnit } = require("%scripts/crew/crew.nut")
let { getCrewsList } = require("%scripts/slotbar/crewsList.nut")
let { getUnitTypesInCountries, getCountriesByUnitType } = require("%scripts/unit/unitInfo.nut")
let { saveShowedTutorial } = require("%scripts/user/newbieTutorialDisplay.nut")
let { createBatchTrainCrewRequestBlk } = require("%scripts/crew/crewTrain.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { addTask } = require("%scripts/tasker.nut")
let { newbieInitSlotbarPresets } = require("%scripts/slotbar/slotbarPresets.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { OPTIONS_MODE_GAMEPLAY } = require("%scripts/options/optionsExtNames.nut")

function createReserveTasksData(country, unitType, checkCurrentCrewAircrafts = true, ignoreSlotbarCheck = false) {
  let tasksData = []
  let usedUnits = []
  foreach (c in getCrewsList()) {
    if (c.country != country)
      continue
    foreach (_idInCountry, crewBlock in c.crews) {
      local unitName = ""
      if (checkCurrentCrewAircrafts) {
        let trainedUnit = getCrewUnit(crewBlock)
        if (trainedUnit && trainedUnit.unitType == unitType)
          unitName = trainedUnit.name
      }
      if (!unitName.len())
        unitName = getReserveAircraftName({
          country = country
          unitType = unitType.esUnitType
          ignoreUnits = usedUnits
          ignoreSlotbarCheck = ignoreSlotbarCheck
          preferredCrew = crewBlock
        })

      if (unitName.len())
        usedUnits.append(unitName)
      tasksData.append({ crewId = crewBlock.id, airName = unitName })
    }
    break
  }
  return tasksData
}

function createBatchRequestByPresetsData(presetsData) {
  let requestData = []
  foreach (presetDataItem in presetsData.presetDataItems)
    if (presetDataItem.unitType == presetsData.selectedUnitType)
      foreach (taskData in presetDataItem.tasksData)
        requestData.append(taskData)
  return createBatchTrainCrewRequestBlk(requestData)
}

gui_handlers.UnitTypeChoiceHandler <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/firstChoice/unitTypeChoice.blk"
  wndOptionsMode = OPTIONS_MODE_GAMEPLAY

  selItemIdx = -1
  unitTypesList = null

  function initScreen() {
    isFirstChoiceShown.set(true)

    this.unitTypesList = []
    let visibleCountries = {}
    foreach (unitType in unitTypes.types) {
      local isAvailable = false
      foreach (country in getCountriesByUnitType(unitType.esUnitType))
        if (unitType.isAvailableForFirstChoice(country)) {
          isAvailable = true
          visibleCountries[country] <- true
        }
      if (isAvailable)
        this.unitTypesList.append(unitType)
    }
    if (!this.unitTypesList.len())
      return this.goBack()

    this.updateState()

    if (this.unitTypesList.len() == 1)
      this.applyUnitTypeSelection(this.unitTypesList[0])
  }

  function updateState() {
    let items = this.unitTypesList.map(function(unitType, idx, arr) {
      let armyName = unitType.armyId
      return {
        backgroundImage = $"#ui/images/first_{armyName}?P1"
        tooltip = loc($"mainmenu/firstUnitChoiceTooltip/{armyName}")
        text = loc($"mainmenu/{armyName}")
        videoPreview = hasFeature("VideoPreview") ? $"video/unitTypePreview/{armyName}.ivf" : null
        isLast = idx == arr.len() - 1
      }
    })

    let data = handyman.renderCached("%gui/firstChoice/unitTypeChoice.tpl", { items })
    let preselectUnits = [unitTypes.AIRCRAFT, unitTypes.TANK]
    let selUnitType = preselectUnits[rnd() % preselectUnits.len()]
    this.fillChoiceScene(data, find_in_array(this.unitTypesList, selUnitType, 0))
    fillUserNick(this.scene.findObject("usernick_place"), "%gui/firstChoice/userNickBig.tpl", false)
  }

  function onClickUnitType(_obj) {
    this.applyUnitTypeSelection(this.unitTypesList[this.selItemIdx])
  }

  function checkSelection(country, unitType) {
    let availData = getUnitTypesInCountries()
    return availData?[country][unitType.esUnitType] ?? false
  }

  function applyUnitTypeSelection(uType) {
    let { esUnitType } = uType
    let countriesList = getUnitTypesInCountries().filter(@(v) v?[esUnitType] ?? false).keys()
    let country = countriesList[rnd() % countriesList.len()]
    if (!this.checkSelection(country, uType))
      return

    switchProfileCountry(country)
    let presetsData = this.createNewbiePresetsData(uType, country)
    let handler = this
    this.clnSetStartingInfo(presetsData, uType, function () {
      newbieInitSlotbarPresets(presetsData)
      checkUnlockedCountriesByAirs()
      broadcastEvent("EventsDataUpdated")
      handler.goBack()
    })
    saveShowedTutorial("unitTypeChoice")
    sendBqEvent("CLIENT_GAMEPLAY_1", "choose_unit_type_screen", { selectedUnitType = uType.lowerName })
    broadcastEvent("UnitTypeChosen")
  }

  function createNewbiePresetsData(selUnitType, selCountry) {
    let presetDataItems = []
    local selEsUnitType = ES_UNIT_TYPE_INVALID
    foreach (crewData in getCrewsList()) {
      let country = crewData.country
      foreach (unitType in unitTypes.types) {
        if (!unitType.isAvailable()
            || !getCountriesByUnitType(unitType.esUnitType).len())
          continue

        let tasksData = createReserveTasksData(country, unitType, false, true)
        
        local hasUnits = false
        foreach (taskData in tasksData)
          if (taskData.airName != "") {
            hasUnits = true
            break
          }

        if (hasUnits || unitType == selUnitType)
          presetDataItems.append({
            country = country
            unitType = unitType.esUnitType
            hasUnits = hasUnits
            tasksData = tasksData
          })

        if (hasUnits)
          if (unitType == selUnitType || selEsUnitType == ES_UNIT_TYPE_INVALID)
            selEsUnitType = unitType.esUnitType
      }
    }

    return {
      presetDataItems
      selectedCountry = selCountry
      selectedUnitType = selEsUnitType
    }
  }

  function clnSetStartingInfo(presetsData, selUnitType, onComplete) {
    let blk = createBatchRequestByPresetsData(presetsData)
    blk.setStr("country", presetsData.selectedCountry)
    blk.setInt("unitType", presetsData.selectedUnitType)

    foreach (country in shopCountriesList) {
      unlockCountry(country, true, false)
      blk.unlock <- country
    }

    if (getFirstChosenUnitType() == ES_UNIT_TYPE_INVALID)
      if (selUnitType.firstChosenTypeUnlockName)
        blk.unlock <- selUnitType.firstChosenTypeUnlockName

    let taskCallback = Callback(onComplete, this)
    let taskId = char_send_blk("cln_set_starting_info", blk)
    let taskOptions = {
      showProgressBox = true
      progressBoxDelayedButtons = 90
    }
    addTask(taskId, taskOptions, taskCallback)
  }

  function fillChoiceScene(data, focusItemNum) {
    if (data == "")
      return

    let listObj = this.scene.findObject("first_choices_block")
    this.guiScene.replaceContentFromText(listObj, data, data.len(), this)

    let listBoxObj = listObj.getChild(0)
    if (focusItemNum != null)
      move_mouse_on_child(listBoxObj, focusItemNum)
  }

  function onSelectSlot(obj) {
    this.selItemIdx = obj.getValue()
  }

  function afterModalDestroy() {
    this.restoreMainOptions()
  }
}
