from "%scripts/dagui_library.nut" import *
from "%scripts/options/optionsCtors.nut" import create_option_combobox

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { getCountries, getCountryOverride, getCountryStyle, setCountryOverride, setCountryStyle,
  countryDisplayStyle, getUseOperatorFlagsInBattle, setUseOperatorFlagsInBattle,
  isCountryFlagRestricted, resetCountriesStyles } = require("%scripts/countries/countriesCustomization.nut")
let { getCountryIcon } = require("%scripts/options/countryFlagsPreset.nut")

gui_handlers.ChooseCountryView <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/countries/chooseCountryView.blk"

  selectedCountry = null
  initCountryIndex = 0
  hasChanges = false

  function initScreen() {
    this.fillCountriesList()
    this.initUseOperatorFlagsInBattle()
  }

  function initUseOperatorFlagsInBattle() {
    let useOperatorFlagsInBattleObj = this.scene.findObject("useOperatorFlagsInBattle")
    useOperatorFlagsInBattleObj.setValue(getUseOperatorFlagsInBattle())
  }

  function fillCountriesList() {
    let view = { countries = [] }
    foreach (country in shopCountriesList) {
      view.countries.append({
        countryIcon = getCountryIcon(country, false)
        country
      })
    }

    let countriesListObj = this.scene.findObject("countries_list")
    let data = handyman.renderCached("%gui/countries/countryItem.tpl", view)
    this.guiScene.replaceContentFromText(countriesListObj, data, data.len(), this)
    countriesListObj.setValue(shopCountriesList.findindex(@(v) v == profileCountrySq.get()))
  }

  function onItemSelect(obj) {
    let index = obj.getValue()
    if (index == null)
      return

    let selectedCountryObj = obj.getChild(index)
    this.selectedCountry = selectedCountryObj.country

    this.fillCountryStyles()
    this.fillCountryFlags()
  }

  function fillCountryStyles() {
    let countryStyle = getCountryStyle(this.selectedCountry)
    local index = 0
    let styles = []
    let countryDisplayStyles = countryDisplayStyle.values().sort(function(v1, _) {
      if (v1 == countryDisplayStyle.DEFAULT)
        return 1
      return 0
    })
    foreach (style in countryDisplayStyles) {
      styles.append({
        text = loc($"countriesAppearance/styles/{style}")
        idx = style
      })
      if (countryStyle == style)
        index = styles.len() - 1
    }
    let customCountryStylesObj = this.scene.findObject("customCountryStyles")
    let data = create_option_combobox("customCountryStyles", styles, 0, "onHitsOwnerChange", false)
    this.guiScene.replaceContentFromText(customCountryStylesObj, data, data.len(), this)
    customCountryStylesObj.setValue(index)
  }

  function fillCountryFlags() {
    let countryFlag = getCountryOverride(this.selectedCountry)
    local index = 0
    let countryData = getCountries()[this.selectedCountry]

    let countries = []
    countries.append({
      image = getCountryIcon(this.selectedCountry, false)
      text = loc(this.selectedCountry)
      idx = this.selectedCountry
      inactive = false
    })
    foreach (country, enabled in countryData) {
      if (isCountryFlagRestricted(country))
        continue
      countries.append({
        image = getCountryIcon(country, false)
        text = loc(country)
        idx = country
        inactive = !enabled
      })
      if (countryFlag == country) {
        index = countries.len() - 1
        this.initCountryIndex = index
      }
    }
    let customCountryFlagsObj = this.scene.findObject("customCountryFlags")
    let data = create_option_combobox("customCountryFlags", countries, 0, "onHitsOwnerChange", false)
    this.guiScene.replaceContentFromText(customCountryFlagsObj, data, data.len(), this)
    customCountryFlagsObj.setValue(index)
  }

  function onEditFlag(obj) {
    let index = obj.getValue()
    if (index == null)
      return
    let item = obj.getChild(index)

    let inactive = item?.inactive ?? "no"
    if (inactive == "yes") {
      showInfoMsgBox(loc("countriesAppearance/notAvailableMsg"))
      if (this.initCountryIndex == index)
        this.initCountryIndex = 0
      obj.setValue(this.initCountryIndex)
      return
    }
    this.initCountryIndex = index
    setCountryOverride(this.selectedCountry, item.idx)
    this.hasChanges = true
  }

  function onEditStyle(obj) {
    let index = obj.getValue()
    if (index == null)
      return
    let item = obj.getChild(index)
    setCountryStyle(this.selectedCountry, item.idx)
    this.hasChanges = true
  }

  function goBack(_obj) {
    if (this.hasChanges)
      broadcastEvent("CountryAppearanceChanged")
    base.goBack()
  }

  function onUseOperatorFlagsInBattle(obj) {
    setUseOperatorFlagsInBattle(obj.getValue())
  }

  function onResetToDefaults() {
    resetCountriesStyles()
    this.fillCountryStyles()
    this.fillCountryFlags()
    this.hasChanges = true
  }
}
