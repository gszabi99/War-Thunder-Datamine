from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

let { format } = require("string")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { createBatchTrainCrewRequestBlk } = require("%scripts/crew/crewActions.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { fillUserNick, getFirstChosenUnitType,
  isFirstChoiceShown } = require("%scripts/firstChoice/firstChoice.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")

local MIN_ITEMS_IN_ROW = 3

enum CChoiceState {
  UNIT_TYPE_SELECT
  COUNTRY_SELECT
  APPLY
}

::gui_start_countryChoice <- function gui_start_countryChoice()
{
  ::handlersManager.loadHandler(::gui_handlers.CountryChoiceHandler)
}

::gui_handlers.CountryChoiceHandler <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/firstChoice/countryChoice.blk"
  wndOptionsMode = ::OPTIONS_MODE_GAMEPLAY

  countries = null
  availableCountriesArray = null
  unitTypesList = null

  prevCurtainObj = null
  countriesUnits = {}

  selectedCountry  = null
  selectedUnitType = null
  isFixedUnitType = false
  state = 0

  function initScreen()
  {
    isFirstChoiceShown(true)

    unitTypesList = []
    let visibleCountries = {}
    foreach(unitType in unitTypes.types)
    {
      local isAvailable = false
      foreach(country in getCountriesByUnitType(unitType.esUnitType))
        if (unitType.isAvailableForFirstChoice(country))
        {
          isAvailable = true
          visibleCountries[country] <- true
        }
      if (isAvailable)
        unitTypesList.append(unitType)
    }
    if (!unitTypesList.len())
      return goBack()

    if (unitTypesList.len() == 1)
    {
      selectedUnitType = unitTypesList[0]
      isFixedUnitType = true
    }

    countriesUnits = ::get_unit_types_in_countries()
    countries = []
    foreach(country in shopCountriesList)
      if (country in visibleCountries)
        countries.append(country)

    updateState()
  }

  function startNextState()
  {
    state++
    updateState()
  }

  function updateState()
  {
    if (state == CChoiceState.COUNTRY_SELECT)
      createPrefferedUnitTypeCountries()
    else if (state == CChoiceState.UNIT_TYPE_SELECT)
    {
      if (isFixedUnitType)
        startNextState()
      else
        createUnitTypeChoice()
    } else
      applySelection()
    updateButtons()
  }

  function updateButtons()
  {
    this.showSceneBtn("back_button", !isFixedUnitType && state > 0)
  }

  function checkSelection(country, unitType)
  {
    let availData = ::get_unit_types_in_countries()
    return availData?[country][unitType.esUnitType] ?? false
  }

  function applySelection()
  {
    if (!checkSelection(selectedCountry, selectedUnitType))
      return

    ::switch_profile_country(selectedCountry)
    goBack()
    ::broadcastEvent("UnitTypeChosen")
  }

  function isCountryAvailable(country, unitType)
  {
    if (!unitType.isAvailableForFirstChoice(country))
      return false

    return countriesUnits?[country][unitType.esUnitType]
  }

  function createUnitTypeChoice()
  {
    local columns = guiScene.calcString("1@rw-1@countryChoiceInterval", null)
      / guiScene.calcString("@unitChoiceImageWidth+@countryChoiceInterval", null)
    columns = min(columns < 4 ? 2 : columns, unitTypesList.len())//Just cause 3 columns look weird here
    setFrameWidth($"{columns}@unitChoiceImageWidth + {columns+1}@countryChoiceInterval")

    let view = {
      unitTypeItems = function ()
      {
        let items = []
        foreach(unitType in unitTypesList)
        {
          let uType = unitType
          let countriesList = countries.filter(function(c) {
            return isCountryAvailable(c, uType)}.bindenv(this)
          ).map(@(c) loc("unlockTag/" + c))
          let armyName = unitType.armyId

          items.append({
            backgroundImage = $"#ui/images/first_{armyName}.jpg?P1"
            tooltip = "".concat(
              loc("unit_type"),
              loc("ui/colon"),
              loc($"mainmenu/{armyName}"),
              "\n",
              ", ".join(countriesList)
            )
            text = loc($"mainmenu/{armyName}")
            videoPreview = hasFeature("VideoPreview") ? $"video/unitTypePreview/{armyName}.ivf" : null
            desription = loc("{armyName}/choiseDescription", "")
          })
        }
        return items
      }.bindenv(this)
    }

    let data = ::handyman.renderCached("%gui/firstChoice/unitTypeChoice", view)
    if (selectedUnitType == null) {
      let preselectUnits = [unitTypes.AIRCRAFT, unitTypes.TANK]
      selectedUnitType = preselectUnits[::math.rnd() % preselectUnits.len()]
    }

    fillChoiceScene(data, ::find_in_array(unitTypesList, selectedUnitType, 0), "firstUnit")
  }

  function fillChoiceScene(data, focusItemNum, headerLocId)
  {
    if (data == "")
      return

    let headerObj = scene.findObject("choice_header")
    if (checkObj(headerObj))
      headerObj.setValue(loc("mainmenu/" + headerLocId))
    fillUserNick(scene.findObject("usernick_place"))

    let listObj = scene.findObject("first_choices_block")
    guiScene.replaceContentFromText(listObj, data, data.len(), this)

    let listBoxObj = listObj.getChild(0)
    if (focusItemNum != null) {
      listBoxObj.setValue(focusItemNum)
      ::move_mouse_on_child(listBoxObj, focusItemNum)
    }
  }

  function getNotAvailableCountryMsg(country)
  {
    let availUnitTypes = []
    foreach(unitType in unitTypes.types)
      if (unitType.isAvailableForFirstChoice(country)
        && isInArray(country, getCountriesByUnitType(unitType.esUnitType)))
        availUnitTypes.append(unitType)

    if (availUnitTypes.len())
      return loc("mainmenu/onlyArmyAvailableForCountry",  { army = ", ".join(availUnitTypes.map(@(t) colorize("activeTextColor", t.getArmyLocName()))) })
    return loc("msg/countryNotAvailableForUnitType")
  }

  countSize = @(ratio) {
    width = guiScene.calcString($"1@countryChoiceInterval + {ratio.w}*(1@countryChoiceImageWidth + 1@countryChoiceInterval)", null),
    height = guiScene.calcString($"1@countryChoiceInterval + {ratio.h} * (1@firstChoiceCountryFullHeight + 1@countryChoiceInterval)", null)
  }

  function getMaxSizeInItems()
  {
    let freeWidth = guiScene.calcString("1@rw", null)
    let freeHeight = guiScene.calcString("1@firstChoiceAvailableHeight", null)
    let singleItemSizeTable = countSize({w = 1, h = 1})

    return {
      inRow = freeWidth / singleItemSizeTable.width,
      inColumn = freeHeight / singleItemSizeTable.height
    }
  }

  function updateScreenSize()
  {
    let maxAvailRatio = getMaxSizeInItems()
    let maxItemsInColumn = maxAvailRatio.inColumn

    local itemsInRow = maxAvailRatio.inRow
    local itemsInColumn = maxItemsInColumn

    for (local row = MIN_ITEMS_IN_ROW; row <= maxAvailRatio.inRow ; row++)
    {
      let column = countries.len() / row
      if (column <= maxItemsInColumn && ((column * row) >= countries.len()))
      {
        itemsInColumn = column
        itemsInRow = row
        break
      }
    }

    return countSize({w = itemsInRow, h = itemsInColumn})
  }

  function createPrefferedUnitTypeCountries()
  {
    let screenSize = updateScreenSize()
    setFrameWidth(screenSize.width)

    let availCountries = selectedUnitType ? getCountriesByUnitType(selectedUnitType.esUnitType) : countries
    for (local i = availCountries.len() - 1; i >= 0; i--)
      if (!isCountryAvailable(availCountries[i], selectedUnitType))
        availCountries.remove(i)

    local data = ""
    let view = {
      width = screenSize.width
      countries = function () {
        let res = []
        let curArmyName = selectedUnitType ? selectedUnitType.armyId  : unitTypes.AIRCRAFT.armyId
        foreach(country in countries)
        {
          local image = ::get_country_flag_img($"first_choice_{country}_{curArmyName}")
          if (image == "")
            image = ::get_country_flag_img($"first_choice_{country}_{unitTypes.AIRCRAFT.armyId}")

          let cData = {
            countryName = loc(country)
            backgroundImage = image
            desription = loc($"{country}/choiseDescription", "")
            lockText = null
          }

          if (!isInArray(country, availCountries))
            cData.lockText = getNotAvailableCountryMsg(country)

          res.append(cData)
        }
        return res
      }.bindenv(this)
    }

    data = ::handyman.renderCached("%gui/firstChoice/countryFirstChoiceItem", view)

    if (!availCountries.len())
    {
      let message = format("Error: Empty available countries List for userId = %s\nunitType = %s:\ncountries = %s\n%s",
                               ::my_user_id_str,
                               selectedUnitType.name,
                               toString(countries),
                               toString(::get_unit_types_in_countries(), 2)
                              )
      ::script_net_assert_once("empty countries list", message)
    }
    else if (!isInArray(selectedCountry, availCountries))
    {
      local rndC = ::math.rnd() % availCountries.len()
      if (::is_vietnamese_version())
        rndC = ::find_in_array(availCountries, "country_ussr", rndC)
      selectedCountry = availCountries[rndC]
    }

    let selectId = ::find_in_array(countries, selectedCountry, 0)
    fillChoiceScene(data, selectId, "firstCountry")
  }

  function onBack()
  {
    if (state <= 0)
      return

    state--
    updateState()
  }

  function onEnterChoice(obj)
  {
    sendFirstChooseStatistic()
    startNextState()
  }

  function onSelectCountry(obj)
  {
    let newCountry = countries?[obj.getValue()]
    if (newCountry)
      selectedCountry = newCountry
  }

  function onSelectUnitType(obj)
  {
    selectedUnitType = unitTypesList[obj.getValue()]
  }

  /**
   * Creates tasks data with reserve units.
   * @param checkCurrentCrewAircrafts Skips tasks if crew
   *                                  already has proper unit.
   */
  function createReserveTasksData(country, unitType, checkCurrentCrewAircrafts = true, ignoreSlotbarCheck = false)
  {
    let tasksData = []
    let usedUnits = []
    foreach(c in ::g_crews_list.get())
    {
      if (c.country != country)
        continue
      foreach(idInCountry, crewBlock in c.crews)
      {
        local unitName = ""
        if (checkCurrentCrewAircrafts)
        {
          let trainedUnit = ::g_crew.getCrewUnit(crewBlock)
          if (trainedUnit && trainedUnit.unitType == unitType)
            unitName = trainedUnit.name
        }
        if (!unitName.len())
          unitName = ::getReserveAircraftName({
            country = country
            unitType = unitType.esUnitType
            ignoreUnits = usedUnits
            ignoreSlotbarCheck = ignoreSlotbarCheck
            preferredCrew = crewBlock
          })

        if (unitName.len())
          usedUnits.append(unitName)
        tasksData.append({crewId = crewBlock.id, airName = unitName})
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
  function createNewbiePresetsData()
  {
    let presetDataItems = []
    local selEsUnitType = ES_UNIT_TYPE_INVALID
    foreach (crewData in ::g_crews_list.get())
    {
      let country = crewData.country
      foreach(unitType in unitTypes.types)
      {
        if (!unitType.isAvailable()
            || !getCountriesByUnitType(unitType.esUnitType).len())
          continue

        let tasksData = createReserveTasksData(country, unitType, false, true)
        // Used for not creating empty presets.
        local hasUnits = false
        foreach (taskData in tasksData)
          if (taskData.airName != "")
          {
            hasUnits = true
            break
          }

        presetDataItems.append({
          country = country
          unitType = unitType.esUnitType
          hasUnits = hasUnits
          tasksData = tasksData
        })

        if (hasUnits) {
          selectedCountry = selectedCountry ?? country
          selectedUnitType = selectedUnitType ?? unitType
          if (unitType == selectedUnitType || selEsUnitType == ES_UNIT_TYPE_INVALID)
            selEsUnitType = unitType.esUnitType
        }
      }
    }
    return {
      presetDataItems = presetDataItems
      selectedCountry = selectedCountry
      selectedUnitType = selEsUnitType
    }
  }

  function createBatchRequestByPresetsData(presetsData)
  {
    let requestData = []
    foreach (presetDataItem in presetsData.presetDataItems)
      if (presetDataItem.unitType == presetsData.selectedUnitType)
        foreach (taskData in presetDataItem.tasksData)
          requestData.append(taskData)
    return createBatchTrainCrewRequestBlk(requestData)
  }

  function clnSetStartingInfo(presetsData, onComplete)
  {
    let blk = createBatchRequestByPresetsData(presetsData)
    blk.setStr("country", presetsData.selectedCountry)
    blk.setInt("unitType", presetsData.selectedUnitType)

    foreach(country in shopCountriesList)
    {
      ::unlockCountry(country, true, false) //now unlock all countries
      blk.unlock <- country
    }

    blk.unlock <- "chosen_" + presetsData.selectedCountry

    if (getFirstChosenUnitType() == ES_UNIT_TYPE_INVALID)
      if (selectedUnitType.firstChosenTypeUnlockName)
        blk.unlock <- selectedUnitType.firstChosenTypeUnlockName

    let taskCallback = Callback(onComplete, this)
    let taskId = ::char_send_blk("cln_set_starting_info", blk)
    let taskOptions = {
      showProgressBox = true
      progressBoxDelayedButtons = 90
    }
    ::g_tasker.addTask(taskId, taskOptions, taskCallback)
  }

  function goBack()
  {
    let presetsData = createNewbiePresetsData()
    let handler = this
    clnSetStartingInfo(presetsData, (@(presetsData, handler) function () {
        // This call won't procude any additional char-requests
        // as all units are already set previously as a single
        // batch char request.
        ::slotbarPresets.newbieInit(presetsData)

        ::checkUnlockedCountriesByAirs()
        ::broadcastEvent("EventsDataUpdated")
        ::gui_handlers.BaseGuiHandlerWT.goBack.call(handler)
      })(presetsData, handler))
  }

  function afterModalDestroy()
  {
    restoreMainOptions()
  }

  function setFrameWidth(width)
  {
    let frameObj = scene.findObject("country_choice_block")
    if (checkObj(frameObj))
      frameObj.width = width
  }

  function sendFirstChooseStatistic()
  {
    if (state == CChoiceState.UNIT_TYPE_SELECT && selectedUnitType)
      ::add_big_query_record("choose_unit_type_screen", selectedUnitType.lowerName)
    else if (state == CChoiceState.COUNTRY_SELECT)
      ::add_big_query_record("choose_country_screen", selectedCountry)
  }

  function getCountriesByUnitType(unitType)
  {
    let res = []
    foreach (countryName, countryData in ::get_unit_types_in_countries())
      if (countryData?[unitType])
        res.append(countryName)

    return res
  }
}
