let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")

/**
 * Action to perform after change country window closes.
 */
enum ChangeCountryAction {
  NONE
  APPLY_COUNTRY
  CHANGE_GAME_MODE
}

::gui_handlers.ChangeCountry <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  currentCountry = null
  chosenCountry = null
  buttonObject = null
  availableCountries = null
  pendingAction = ChangeCountryAction.NONE
  onCountryChooseCb = null

  function initScreen()
  {
    availableCountries = getAvailableCountries()
    let view = {
      headerText = hasUnlockedAvailableCountry()
        ? ::loc("mainmenu/coutryChoice")
        : ::loc("mainmenu/countryChoice/changeMode")

      messageText = hasUnlockedAvailableCountry()
        ? ::loc("notAvailbleCountry/choose")
        : ::loc("notAvailbleCountry/none")

      showOkButton = hasUnlockedAvailableCountry()

      shopFilterItems = createShopFilterItems(availableCountries)
    }

    let data = ::handyman.renderCached("%gui/changeCountry", view)
    guiScene.replaceContentFromText(scene, data, data.len(), this)

    buttonObject = getObj("btn_apply")
    if (!::checkObj(buttonObject))
      buttonObject = null
    if (buttonObject != null)
      buttonObject.enable(false)

    let listObj = scene.findObject("countries_list")
    if (::checkObj(listObj))
    {
      listObj.setValue(getValueByCountry(currentCountry))
      onCountrySelect(listObj)
    }
  }

  function afterModalDestroy()
  {
    switch (pendingAction)
    {
      case ChangeCountryAction.APPLY_COUNTRY:
        if (chosenCountry != null)
          onCountryChooseCb?(chosenCountry)
        break
      case ChangeCountryAction.CHANGE_GAME_MODE:
          ::gui_handlers.GameModeSelect.open()
        break
    }
  }

  function onCountrySelect(obj)
  {
    let country = getCountryByValue(obj.getValue())
    if (country == null)
      return
    let countryUnlocked = isCountryUnlocked(country)
    currentCountry = countryUnlocked ? country : null
    if (::checkObj(buttonObject))
      buttonObject.enable(countryUnlocked || !hasUnlockedAvailableCountry())
  }

  function onApply()
  {
    if (!hasUnlockedAvailableCountry())
      return
    if (currentCountry == null)
      return
    chosenCountry = currentCountry
    pendingAction = ChangeCountryAction.APPLY_COUNTRY
    goBack()
  }

  function onChangeMode()
  {
    pendingAction = ChangeCountryAction.CHANGE_GAME_MODE
    goBack()
  }

  function createShopFilterItems(countries)
  {
    let shopFilterItems = []
    for (local i = 0; i < countries.len(); ++i)
    {
      let country = countries[i]
      shopFilterItems.append({
        shopFilterId = country
        shopFilterText = ::loc(country)
        shopFilterImage = ::get_country_icon(country, true, !isCountryUnlocked(country))
      })
    }
    return shopFilterItems
  }

  function getValueByCountry(country)
  {
    return ::find_in_array(getAvailableCountries(), country, 0)
  }

  function getCountryByValue(value)
  {
    if (!availableCountries || !(value in availableCountries))
      return null
    return availableCountries[value]
  }

  /**
   * Array of country names supported by selected event.
   */
  function getAvailableCountries()
  {
    let res = []
    let currentMode = ::game_mode_manager.getCurrentGameMode()
    let source = ::getTblValue("source", currentMode, {})
    foreach (country in shopCountriesList)
    {
      if (::events.isCountryAvailable(source, country))
        res.append(country)
    }
    return res
  }

  function isCountryUnlocked(country)
  {
    return ::isInArray(country, ::unlocked_countries)
  }

  function hasUnlockedAvailableCountry()
  {
    foreach (country in getAvailableCountries())
    {
      if (isCountryUnlocked(country))
        return true
    }
    return false
  }
}
