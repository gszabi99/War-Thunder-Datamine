from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { format } = require("string")
let { floor } = require("math")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { getFirstChosenUnitType, isFirstChoiceShown, fillUserNick } = require("%scripts/firstChoice/firstChoice.nut")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { getCountryFlagImg } = require("%scripts/options/countryFlagsPreset.nut")
let { userIdStr } = require("%scripts/user/profileStates.nut")
let { getUnitTypesInCountries, getCountriesByUnitType } = require("%scripts/unit/unitInfo.nut")
let { switchProfileCountry } = require("%scripts/user/playerCountry.nut")
let { sendBqEvent } = require("%scripts/bqQueue/bqQueue.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { OPTIONS_MODE_GAMEPLAY } = require("%scripts/options/optionsExtNames.nut")
let { buildUnitSlot, fillUnitSlotTimers } = require("%scripts/slotbar/slotbarView.nut")
let { saveShowedTutorial, getFirstCountryChoice } = require("%scripts/user/newbieTutorialDisplay.nut")
let { reqUnlockByClient } = require("%scripts/unlocks/unlocksModule.nut")
let { unlockLaterVehicles, getRecomendedCountries } = require("%appGlobals/config/countriesVehicles.nut")
let { hasRunTutorialDialog } = require("%scripts/tutorials.nut")
let { doesLocTextExist } = require("dagor.localize")
let { getCrewsList } = require("%scripts/slotbar/crewsList.nut")
let { getReserveAircraftName } = require("%scripts/slotbar/slotbarStateData.nut")
let { register_command } = require("console")
let { findChildIndex } = require("%sqDagui/daguiUtil.nut")
let { shuffle } = require("%sqStdLibs/helpers/u.nut")


function getReserveUnits(country, esUnitType) {
  let result = []
  let usedUnits = []
  let crews = getCrewsList().findvalue(@(v) v.country == country)
  if (crews == null)
    return result

  foreach (crewBlock in crews.crews) {
    local unitName = ""
    if (!unitName.len())
      unitName = getReserveAircraftName({
        country = country
        unitType = esUnitType
        ignoreUnits = usedUnits
        ignoreSlotbarCheck = true
        preferredCrew = crewBlock
      })

    if (unitName.len())
      usedUnits.append(unitName)
    if (unitName != "")
      result.append(unitName)
  }
  return result
}

function isCountryAvailable(country, unitType) {
  if (!unitType.isAvailableForFirstChoice(country))
    return false

  return getUnitTypesInCountries()?[country][unitType.esUnitType]
}

gui_handlers.CountryChoiceHandler <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/firstChoice/countryChoice.blk"
  wndOptionsMode = OPTIONS_MODE_GAMEPLAY

  countries = null
  listObj = null
  countryInfoHolderObj = null
  curArmyName = null
  selectedCountry = null

  esUnitType = null
  unitType = null
  isNewStyleView = null

  function initScreen() {
    isFirstChoiceShown.set(true)
    this.isNewStyleView = this.isNewStyleView ?? !hasRunTutorialDialog()

    this.esUnitType = this.esUnitType ?? getFirstChosenUnitType()

    this.listObj = this.scene.findObject("countries")
    this.countryInfoHolderObj = showObjById("country_info_div", this.isNewStyleView, this.scene)
    let visibleCountries = {}
    foreach (unitType in unitTypes.types) {
      local isAvailable = false
      foreach (country in getCountriesByUnitType(unitType.esUnitType))
        if (unitType.isAvailableForFirstChoice(country)) {
          isAvailable = true
          visibleCountries[country] <- true
        }
      if (isAvailable && unitType.esUnitType == this.esUnitType)
        this.unitType = unitType
    }

    this.countries = []
    foreach (country in shopCountriesList)
      if (country in visibleCountries)
        this.countries.append(country)

    fillUserNick(this.scene.findObject("usernick_place"), "%gui/firstChoice/userNickBig.tpl", false)
    this.updateState()
  }

  function updateState() {
    let allCountriesByUnitType = this.unitType ? getCountriesByUnitType(this.esUnitType) : this.countries
    let uType = this.unitType
    let availCountries = allCountriesByUnitType.filter(@(country) isCountryAvailable(country, uType))

    this.curArmyName = this.unitType ? this.unitType.armyId : unitTypes.AIRCRAFT.armyId
    let recomendedCountries = []
    let otherCountries = []
    let notAvailableCountries = []

    foreach (country in allCountriesByUnitType) {
      local image = getCountryFlagImg($"first_choice_{country}_{this.curArmyName}")
      if (image == "")
        image = getCountryFlagImg($"first_choice_{country}_{unitTypes.AIRCRAFT.armyId}")

      if (availCountries.contains(country)) {
        let isRecomended = getRecomendedCountries(this.esUnitType).contains(country)
        let countriesList = isRecomended ? recomendedCountries : otherCountries
        countriesList.append({
          country
          isRecomended
          countryName = loc(country)
          backgroundImage = image
          tooltip = !this.isNewStyleView ? this.getCountryInfoDescription(country) : ""
        })
      }
      else
        notAvailableCountries.append(country)
    }

    let countries = shuffle(recomendedCountries).extend(otherCountries)
    let data = handyman.renderCached("%gui/firstChoice/countryFirstChoiceItem.tpl", { countries })

    if (!availCountries.len()) {
      let message = format("Error: Empty available countries List for userId = %s\nunitType = %s:\ncountries = %s\n%s",
        userIdStr.get(),
        this.unitType.name,
        toString(this.countries),
        toString(getUnitTypesInCountries(), 2)
      )
      script_net_assert_once("empty countries list", message)
    }

    this.guiScene.replaceContentFromText(this.listObj, data, data.len(), this)

    if (this.isNewStyleView) {
      let countriesRowsCount = countries.len() > 0 ? floor((countries.len() - 1) / 3) + 1 : 1
      let countryInfoObjHeight = (countriesRowsCount + 1) * to_pixels("1@unitChoiceImageHeight + 1@countryChoiceInterval") - to_pixels("1@countryChoiceInterval")
      this.countryInfoHolderObj["height"] = $"{countryInfoObjHeight}"
    }
    if (notAvailableCountries.len() > 0) {
      let notAvailableCountriesObj = this.scene.findObject("not_available_countries")
      notAvailableCountriesObj.show(true)
      notAvailableCountriesObj.setValue(loc("mainmenu/firstCountryChoiceNoticeCountries", { countries = ", ".join(notAvailableCountries.map(@(c) loc(c))) }))
    }
  }

  function onClickCountry(obj) {
    let idx = obj.getValue()
    let countryItem = obj.getChild(idx)
    this.selectedCountry = countryItem["countryName"]

    if (!this.isNewStyleView) {
      this.saveChoosenCountry()
      this.goBack()
      return
    }

    showObjById("choose_country_info", false, this.countryInfoHolderObj)
    showObjById("country_info", true, this.countryInfoHolderObj)
    this.fillUnits()
    this.fillCountryInfo()
  }

  function saveChoosenCountry() {
    let chosenCountry = getFirstCountryChoice()
    if (chosenCountry == null) {
      reqUnlockByClient($"chosen_{this.selectedCountry}")
      switchProfileCountry(this.selectedCountry)
      sendBqEvent("CLIENT_GAMEPLAY_1", "choose_country_screen", { selectedCountry = this.selectedCountry })
    }
    else
      switchProfileCountry(chosenCountry)

    saveShowedTutorial("countryChoice")
    broadcastEvent("UnitTypeChosen")
  }

  function getCountryInfoDescription(country = null) {
    let key = $"firstChoiceCountry/{country ?? this.selectedCountry}_{this.curArmyName}_description"
    return doesLocTextExist(key) ? loc(key) : ""
  }

  function fillCountryInfo() {
    let unitTypeKey = $"firstChoiceCountry/{this.curArmyName}"
    let unitTypeText = doesLocTextExist(unitTypeKey) ? loc(unitTypeKey) : ""

    let countryKey = $"firstChoiceCountry/{this.selectedCountry}"
    let countryText = doesLocTextExist(countryKey) ? loc(countryKey) : ""

    let countryUnitTypeText = loc("firstChoiceCountry/description_title" { unitType = unitTypeText, country = countryText })
    this.scene.findObject("country_info_title").setValue(countryUnitTypeText)

    this.scene.findObject("country_info_description").setValue(this.getCountryInfoDescription())
  }

  function fillUnits() {
    let reserveUnits = getReserveUnits(this.selectedCountry, this.esUnitType)
    if (reserveUnits.len() > 2)
      reserveUnits.resize(2)
    this.scene.findObject("starting_vehicles").setValue(loc($"firstChoiceCountry/starting_{this.curArmyName}", { num = reserveUnits.len()}))

    foreach (idx, unitName in reserveUnits) {
      let params = { firstChoice = true, firstChoiceLocked = false, tooltipParams = { canOpenOtherWindows = false } }
      let unit = getAircraftByName(unitName)
      let unitBlk = buildUnitSlot(unitName, unit, params)
      let unitNest = this.countryInfoHolderObj.findObject($"starting_unit{idx + 1}")
      this.guiScene.replaceContentFromText(unitNest, unitBlk, unitBlk.len(), this)
      fillUnitSlotTimers(unitNest.findObject(unitName), unit)
    }
    showObjById("starting_unit2", reserveUnits.len() > 1, this.countryInfoHolderObj)

    let lateUnlockUnits = unlockLaterVehicles?[this.selectedCountry][this.curArmyName] ?? []

    showObjById("lateUnlock_unit1", lateUnlockUnits.len() > 0, this.countryInfoHolderObj)
    showObjById("lateUnlock_unit2", lateUnlockUnits.len() > 1, this.countryInfoHolderObj)

    if (lateUnlockUnits.len() == 0) {
      logerr($"[FirstCountryChoice] missing unlock later units for {this.unitType.name} in {this.selectedCountry}")
      return
    }

    foreach (idx, unitName in lateUnlockUnits) {
      let params = {
        translucentText = true
        status = "owned"
        isItemLocked = false
        tooltipParams = { canOpenOtherWindows = false }
        hasLockedIcon = true
      }
      let unit = getAircraftByName(unitName)
      let unitBlk = buildUnitSlot(unitName, unit, params)
      let unitNest = this.countryInfoHolderObj.findObject($"lateUnlock_unit{idx + 1}")
      this.guiScene.replaceContentFromText(unitNest, unitBlk, unitBlk.len(), this)
      fillUnitSlotTimers(unitNest.findObject(unitName), unit)
    }
  }

  function onToBattleClick() {
    this.saveChoosenCountry()
    let handler = handlersManager.findHandlerClassInScene(gui_handlers.MainMenu)
    if (handler)
      handler.onStart()
    this.goBack()
  }

  function afterModalDestroy() {
    this.restoreMainOptions()
  }

  function onClickCountryItem(obj) {
    let idx = findChildIndex(this.listObj, @(o) o.isEqual(obj))
    if (idx < 0 || idx == this.listObj.getValue())
      return
    this.listObj.setValue(idx)
  }
}

register_command(function(esUnitType, isNewStyleView) {
  if (!unitTypes.getByEsUnitType(esUnitType).isAvailableForFirstChoice()) {
    logerr($"[FirstCountryChoice] esUnitType {esUnitType} not available for first choice")
    esUnitType = ES_UNIT_TYPE_AIRCRAFT
  }

  handlersManager.loadHandler(gui_handlers.CountryChoiceHandler, { esUnitType, isNewStyleView })
}, "debug.open_country_choice_wnd")