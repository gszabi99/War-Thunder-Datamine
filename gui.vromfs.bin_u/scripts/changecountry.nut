//checked for plus_string
from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { find_in_array } = require("%sqStdLibs/helpers/u.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { getCountryIcon } = require("%scripts/options/countryFlagsPreset.nut")
let { isCountryUnlocked } = require("%scripts/firstChoice/firstChoice.nut")

/**
 * Action to perform after change country window closes.
 */
enum ChangeCountryAction {
  NONE
  APPLY_COUNTRY
  CHANGE_GAME_MODE
}

gui_handlers.ChangeCountry <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  currentCountry = null
  chosenCountry = null
  buttonObject = null
  availableCountries = null
  pendingAction = ChangeCountryAction.NONE
  onCountryChooseCb = null

  function initScreen() {
    this.availableCountries = this.getAvailableCountries()
    let view = {
      headerText = this.hasUnlockedAvailableCountry()
        ? loc("mainmenu/coutryChoice")
        : loc("mainmenu/countryChoice/changeMode")

      messageText = this.hasUnlockedAvailableCountry()
        ? loc("notAvailbleCountry/choose")
        : loc("notAvailbleCountry/none")

      showOkButton = this.hasUnlockedAvailableCountry()

      shopFilterItems = this.createShopFilterItems(this.availableCountries)
    }

    let data = handyman.renderCached("%gui/changeCountry.tpl", view)
    this.guiScene.replaceContentFromText(this.scene, data, data.len(), this)

    this.buttonObject = this.getObj("btn_apply")
    if (!checkObj(this.buttonObject))
      this.buttonObject = null
    if (this.buttonObject != null)
      this.buttonObject.enable(false)

    let listObj = this.scene.findObject("countries_list")
    if (checkObj(listObj)) {
      listObj.setValue(this.getValueByCountry(this.currentCountry))
      this.onCountrySelect(listObj)
    }
  }

  function afterModalDestroy() {
    let pAct = this.pendingAction
    if (pAct == ChangeCountryAction.APPLY_COUNTRY) {
      if (this.chosenCountry != null)
        this.onCountryChooseCb?(this.chosenCountry)
    }
    else if (pAct == ChangeCountryAction.CHANGE_GAME_MODE )
        gui_handlers.GameModeSelect.open()
  }

  function onCountrySelect(obj) {
    let country = this.getCountryByValue(obj.getValue())
    if (country == null)
      return
    let countryUnlocked = isCountryUnlocked(country)
    this.currentCountry = countryUnlocked ? country : null
    if (checkObj(this.buttonObject))
      this.buttonObject.enable(countryUnlocked || !this.hasUnlockedAvailableCountry())
  }

  function onApply() {
    if (!this.hasUnlockedAvailableCountry())
      return
    if (this.currentCountry == null)
      return
    this.chosenCountry = this.currentCountry
    this.pendingAction = ChangeCountryAction.APPLY_COUNTRY
    this.goBack()
  }

  function onChangeMode() {
    this.pendingAction = ChangeCountryAction.CHANGE_GAME_MODE
    this.goBack()
  }

  function createShopFilterItems(countries) {
    let shopFilterItems = []
    for (local i = 0; i < countries.len(); ++i) {
      let country = countries[i]
      shopFilterItems.append({
        shopFilterId = country
        shopFilterText = loc(country)
        shopFilterImage = getCountryIcon(country, true, !isCountryUnlocked(country))
      })
    }
    return shopFilterItems
  }

  function getValueByCountry(country) {
    return find_in_array(this.getAvailableCountries(), country, 0)
  }

  function getCountryByValue(value) {
    if (!this.availableCountries || !(value in this.availableCountries))
      return null
    return this.availableCountries[value]
  }

  /**
   * Array of country names supported by selected event.
   */
  function getAvailableCountries() {
    let res = []
    let currentMode = ::game_mode_manager.getCurrentGameMode()
    let source = getTblValue("source", currentMode, {})
    foreach (country in shopCountriesList) {
      if (::events.isCountryAvailable(source, country))
        res.append(country)
    }
    return res
  }

  function hasUnlockedAvailableCountry() {
    foreach (country in this.getAvailableCountries()) {
      if (isCountryUnlocked(country))
        return true
    }
    return false
  }
}
