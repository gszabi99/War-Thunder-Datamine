//-file:plus-string
from "%scripts/dagui_natives.nut" import char_send_blk
from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { move_mouse_on_child } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { find_in_array } = require("%sqStdLibs/helpers/u.nut")
let { format } = require("string")
let { rnd } = require("dagor.random")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { createBatchTrainCrewRequestBlk } = require("%scripts/crew/crewActions.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { fillUserNick, getFirstChosenUnitType, unlockCountry, checkUnlockedCountriesByAirs,
  isFirstChoiceShown } = require("%scripts/firstChoice/firstChoice.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { switchProfileCountry } = require("%scripts/user/playerCountry.nut")
let { sendBqEvent } = require("%scripts/bqQueue/bqQueue.nut")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { OPTIONS_MODE_GAMEPLAY } = require("%scripts/options/optionsExtNames.nut")
let { getCountryFlagImg } = require("%scripts/options/countryFlagsPreset.nut")
let { userIdStr } = require("%scripts/user/profileStates.nut")
let { addTask } = require("%scripts/tasker.nut")
let { getReserveAircraftName } = require("%scripts/slotbar/slotbarState.nut")
let { getCrewUnit } = require("%scripts/crew/crew.nut")
let { getCrewsList } = require("%scripts/slotbar/crewsList.nut")

local MIN_ITEMS_IN_ROW = 3

enum CChoiceState {
  UNIT_TYPE_SELECT
  COUNTRY_SELECT
  APPLY
}

gui_handlers.CountryChoiceHandler <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/firstChoice/countryChoice.blk"
  wndOptionsMode = OPTIONS_MODE_GAMEPLAY

  countries = null
  availableCountriesArray = null
  unitTypesList = null

  prevCurtainObj = null
  countriesUnits = {}

  selectedCountry  = null
  selectedUnitType = null
  isFixedUnitType = false
  state = 0

  function initScreen() {
    isFirstChoiceShown(true)

    this.unitTypesList = []
    let visibleCountries = {}
    foreach (unitType in unitTypes.types) {
      local isAvailable = false
      foreach (country in this.getCountriesByUnitType(unitType.esUnitType))
        if (unitType.isAvailableForFirstChoice(country)) {
          isAvailable = true
          visibleCountries[country] <- true
        }
      if (isAvailable)
        this.unitTypesList.append(unitType)
    }
    if (!this.unitTypesList.len())
      return this.goBack()

    if (this.unitTypesList.len() == 1) {
      this.selectedUnitType = this.unitTypesList[0]
      this.isFixedUnitType = true
    }

    this.countriesUnits = ::get_unit_types_in_countries()
    this.countries = []
    foreach (country in shopCountriesList)
      if (country in visibleCountries)
        this.countries.append(country)

    this.updateState()
  }

  function startNextState() {
    this.state++
    this.updateState()
  }

  function updateState() {
    if (this.state == CChoiceState.COUNTRY_SELECT)
      this.createPrefferedUnitTypeCountries()
    else if (this.state == CChoiceState.UNIT_TYPE_SELECT) {
      if (this.isFixedUnitType)
        this.startNextState()
      else
        this.createUnitTypeChoice()
    }
    else
      this.applySelection()
    this.updateButtons()
  }

  function updateButtons() {
    showObjById("back_button", !this.isFixedUnitType && this.state > 0, this.scene)
  }

  function checkSelection(country, unitType) {
    let availData = ::get_unit_types_in_countries()
    return availData?[country][unitType.esUnitType] ?? false
  }

  function applySelection() {
    if (!this.checkSelection(this.selectedCountry, this.selectedUnitType))
      return

    switchProfileCountry(this.selectedCountry)
    this.goBack()
    broadcastEvent("UnitTypeChosen")
  }

  function isCountryAvailable(country, unitType) {
    if (!unitType.isAvailableForFirstChoice(country))
      return false

    return this.countriesUnits?[country][unitType.esUnitType]
  }

  function createUnitTypeChoice() {
    local columns = this.guiScene.calcString("1@rw-1@countryChoiceInterval", null)
      / this.guiScene.calcString("@unitChoiceImageWidth+@countryChoiceInterval", null)
    columns = min(columns < 4 ? 2 : columns, this.unitTypesList.len()) //Just cause 3 columns look weird here
    this.setFrameWidth($"{columns}@unitChoiceImageWidth + {columns+1}@countryChoiceInterval")

    let view = {
      unitTypeItems = function () {
        let items = []
        foreach (unitType in this.unitTypesList) {
          let uType = unitType
          let countriesList = this.countries.filter(function(c) {
            return this.isCountryAvailable(c, uType) }.bindenv(this)
          ).map(@(c) loc("unlockTag/" + c))
          let armyName = unitType.armyId

          items.append({
            backgroundImage = $"#ui/images/first_{armyName}?P1"
            tooltip = "".concat(
              loc("unit_type"),
              loc("ui/colon"),
              loc($"mainmenu/{armyName}"),
              "\n",
              ", ".join(countriesList)
            )
            text = loc($"mainmenu/{armyName}")
            videoPreview = hasFeature("VideoPreview") ? $"video/unitTypePreview/{armyName}.ivf" : null
          })
        }
        return items
      }.bindenv(this)
    }

    let data = handyman.renderCached("%gui/firstChoice/unitTypeChoice.tpl", view)
    if (this.selectedUnitType == null) {
      let preselectUnits = [unitTypes.AIRCRAFT, unitTypes.TANK]
      this.selectedUnitType = preselectUnits[rnd() % preselectUnits.len()]
    }

    this.fillChoiceScene(data, find_in_array(this.unitTypesList, this.selectedUnitType, 0), "firstUnit")
  }

  function fillChoiceScene(data, focusItemNum, headerLocId) {
    if (data == "")
      return

    let headerObj = this.scene.findObject("choice_header")
    if (checkObj(headerObj))
      headerObj.setValue(loc("mainmenu/" + headerLocId))
    fillUserNick(this.scene.findObject("usernick_place"))

    let listObj = this.scene.findObject("first_choices_block")
    this.guiScene.replaceContentFromText(listObj, data, data.len(), this)

    let listBoxObj = listObj.getChild(0)
    if (focusItemNum != null) {
      listBoxObj.setValue(focusItemNum)
      move_mouse_on_child(listBoxObj, focusItemNum)
    }
  }

  function getNotAvailableCountryMsg(country) {
    let availUnitTypes = []
    foreach (unitType in unitTypes.types)
      if (unitType.isAvailableForFirstChoice(country)
        && isInArray(country, this.getCountriesByUnitType(unitType.esUnitType)))
        availUnitTypes.append(unitType)

    if (availUnitTypes.len())
      return loc("mainmenu/onlyArmyAvailableForCountry",  { army = ", ".join(availUnitTypes.map(@(t) colorize("activeTextColor", t.getArmyLocName()))) })
    return loc("msg/countryNotAvailableForUnitType")
  }

  countSize = @(ratio) {
    width = this.guiScene.calcString($"1@countryChoiceInterval + {ratio.w}*(1@countryChoiceImageWidth + 1@countryChoiceInterval)", null),
    height = this.guiScene.calcString($"1@countryChoiceInterval + {ratio.h} * (1@firstChoiceCountryFullHeight + 1@countryChoiceInterval)", null)
  }

  function getMaxSizeInItems() {
    let freeWidth = this.guiScene.calcString("1@rw", null)
    let freeHeight = this.guiScene.calcString("1@firstChoiceAvailableHeight", null)
    let singleItemSizeTable = this.countSize({ w = 1, h = 1 })

    return {
      inRow = freeWidth / singleItemSizeTable.width,
      inColumn = freeHeight / singleItemSizeTable.height
    }
  }

  function updateScreenSize() {
    let maxAvailRatio = this.getMaxSizeInItems()
    let maxItemsInColumn = maxAvailRatio.inColumn

    local itemsInRow = maxAvailRatio.inRow
    local itemsInColumn = maxItemsInColumn

    for (local row = MIN_ITEMS_IN_ROW; row <= maxAvailRatio.inRow ; row++) {
      let column = this.countries.len() / row
      if (column <= maxItemsInColumn && ((column * row) >= this.countries.len())) {
        itemsInColumn = column
        itemsInRow = row
        break
      }
    }

    return this.countSize({ w = itemsInRow, h = itemsInColumn })
  }

  function createPrefferedUnitTypeCountries() {
    let screenSize = this.updateScreenSize()
    this.setFrameWidth(screenSize.width)

    let availCountries = this.selectedUnitType ? this.getCountriesByUnitType(this.selectedUnitType.esUnitType) : this.countries
    for (local i = availCountries.len() - 1; i >= 0; i--)
      if (!this.isCountryAvailable(availCountries[i], this.selectedUnitType))
        availCountries.remove(i)

    local data = ""
    let view = {
      width = screenSize.width
      countries = function () {
        let res = []
        let curArmyName = this.selectedUnitType ? this.selectedUnitType.armyId  : unitTypes.AIRCRAFT.armyId
        foreach (country in this.countries) {
          local image = getCountryFlagImg($"first_choice_{country}_{curArmyName}")
          if (image == "")
            image = getCountryFlagImg($"first_choice_{country}_{unitTypes.AIRCRAFT.armyId}")

          let cData = {
            countryName = loc(country)
            backgroundImage = image
            lockText = null
          }

          if (!isInArray(country, availCountries))
            cData.lockText = this.getNotAvailableCountryMsg(country)

          res.append(cData)
        }
        return res
      }.bindenv(this)
    }

    data = handyman.renderCached("%gui/firstChoice/countryFirstChoiceItem.tpl", view)

    if (!availCountries.len()) {
      let message = format("Error: Empty available countries List for userId = %s\nunitType = %s:\ncountries = %s\n%s",
                               userIdStr.value,
                               this.selectedUnitType.name,
                               toString(this.countries),
                               toString(::get_unit_types_in_countries(), 2)
                              )
      script_net_assert_once("empty countries list", message)
    }
    else if (!isInArray(this.selectedCountry, availCountries))
      this.selectedCountry = availCountries[rnd() % availCountries.len()]

    let selectId = find_in_array(this.countries, this.selectedCountry, 0)
    this.fillChoiceScene(data, selectId, "firstCountry")
  }

  function onBack() {
    if (this.state <= 0)
      return

    this.state--
    this.updateState()
  }

  function onEnterChoice(_obj) {
    this.sendFirstChooseStatistic()
    this.startNextState()
  }

  function onSelectCountry(obj) {
    let newCountry = this.countries?[obj.getValue()]
    if (newCountry)
      this.selectedCountry = newCountry
  }

  function onSelectUnitType(obj) {
    this.selectedUnitType = this.unitTypesList[obj.getValue()]
  }

  /**
   * Creates tasks data with reserve units.
   * @param checkCurrentCrewAircrafts Skips tasks if crew
   *                                  already has proper unit.
   */
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

  /**
   * Returns collection of items with all data
   * required to create newbie presets.
   * @see ::slotbarPresets.newbieInit(...)
   */
  function createNewbiePresetsData() {
    let presetDataItems = []
    local selEsUnitType = ES_UNIT_TYPE_INVALID
    foreach (crewData in getCrewsList()) {
      let country = crewData.country
      foreach (unitType in unitTypes.types) {
        if (!unitType.isAvailable()
            || !this.getCountriesByUnitType(unitType.esUnitType).len())
          continue

        let tasksData = this.createReserveTasksData(country, unitType, false, true)
        // Used for not creating empty presets.
        local hasUnits = false
        foreach (taskData in tasksData)
          if (taskData.airName != "") {
            hasUnits = true
            break
          }

        if (hasUnits || unitType == this.selectedUnitType)
          presetDataItems.append({
            country = country
            unitType = unitType.esUnitType
            hasUnits = hasUnits
            tasksData = tasksData
          })

        if (hasUnits) {
          this.selectedCountry = this.selectedCountry ?? country
          this.selectedUnitType = this.selectedUnitType ?? unitType
          if (unitType == this.selectedUnitType || selEsUnitType == ES_UNIT_TYPE_INVALID)
            selEsUnitType = unitType.esUnitType
        }
      }
    }
    return {
      presetDataItems = presetDataItems
      selectedCountry = this.selectedCountry
      selectedUnitType = selEsUnitType
    }
  }

  function createBatchRequestByPresetsData(presetsData) {
    let requestData = []
    foreach (presetDataItem in presetsData.presetDataItems)
      if (presetDataItem.unitType == presetsData.selectedUnitType)
        foreach (taskData in presetDataItem.tasksData)
          requestData.append(taskData)
    return createBatchTrainCrewRequestBlk(requestData)
  }

  function clnSetStartingInfo(presetsData, onComplete) {
    let blk = this.createBatchRequestByPresetsData(presetsData)
    blk.setStr("country", presetsData.selectedCountry)
    blk.setInt("unitType", presetsData.selectedUnitType)

    foreach (country in shopCountriesList) {
      unlockCountry(country, true, false) //now unlock all countries
      blk.unlock <- country
    }

    blk.unlock <- "chosen_" + presetsData.selectedCountry

    if (getFirstChosenUnitType() == ES_UNIT_TYPE_INVALID)
      if (this.selectedUnitType.firstChosenTypeUnlockName)
        blk.unlock <- this.selectedUnitType.firstChosenTypeUnlockName

    let taskCallback = Callback(onComplete, this)
    let taskId = char_send_blk("cln_set_starting_info", blk)
    let taskOptions = {
      showProgressBox = true
      progressBoxDelayedButtons = 90
    }
    addTask(taskId, taskOptions, taskCallback)
  }

  function goBack() {
    let presetsData = this.createNewbiePresetsData()
    let handler = this
    this.clnSetStartingInfo(presetsData, function () {
        // This call won't procude any additional char-requests
        // as all units are already set previously as a single
        // batch char request.
        ::slotbarPresets.newbieInit(presetsData)

        checkUnlockedCountriesByAirs()
        broadcastEvent("EventsDataUpdated")
        gui_handlers.BaseGuiHandlerWT.goBack.call(handler)
      })
  }

  function afterModalDestroy() {
    this.restoreMainOptions()
  }

  function setFrameWidth(width) {
    let frameObj = this.scene.findObject("country_choice_block")
    if (checkObj(frameObj))
      frameObj.width = width
  }

  function sendFirstChooseStatistic() {
    if (this.state == CChoiceState.UNIT_TYPE_SELECT && this.selectedUnitType)
      sendBqEvent("CLIENT_GAMEPLAY_1", "choose_unit_type_screen", { selectedUnitType = this.selectedUnitType.lowerName })
    else if (this.state == CChoiceState.COUNTRY_SELECT)
      sendBqEvent("CLIENT_GAMEPLAY_1", "choose_country_screen", { selectedCountry = this.selectedCountry })
  }

  function getCountriesByUnitType(unitType) {
    let res = []
    foreach (countryName, countryData in ::get_unit_types_in_countries())
      if (countryData?[unitType])
        res.append(countryName)

    return res
  }
}
