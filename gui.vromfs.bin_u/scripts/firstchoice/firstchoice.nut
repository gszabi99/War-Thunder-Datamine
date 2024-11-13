from "%scripts/dagui_natives.nut" import stat_get_value_respawns, disable_network, is_country_available
from "%scripts/dagui_library.nut" import *
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { isPlatformXboxOne } = require("%scripts/clientState/platform.nut")
let { getPlayerName } = require("%scripts/user/remapNick.nut")
let { reqUnlockByClient } = require("%scripts/unlocks/unlocksModule.nut")
let { isDiffUnlocked } = require("%scripts/tutorials/tutorialsState.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let getAllUnits = require("%scripts/unit/allUnits.nut")
let { isUnitDefault, isUnitUsable } = require("%scripts/unit/unitStatus.nut")
let { getProfileInfo } = require("%scripts/user/userInfoStats.nut")

let isFirstChoiceShown = mkWatched(persist, "isFirstChoiceShown", false)

let unlockedCountries = persist("unlockedCountries", @() [])

let getFirstChosenUnitType = function(defValue = ES_UNIT_TYPE_INVALID) {
  foreach (unitType in unitTypes.types)
    if (unitType.isFirstChosen())
      return unitType.esUnitType
  return defValue
}

let isNeedFirstCountryChoice = function() {
  return getFirstChosenUnitType() == ES_UNIT_TYPE_INVALID
         && !stat_get_value_respawns(0, 1)
         && !disable_network()
}

let fillUserNick = function (nestObj, _headerLocId = null) {
  if (!::g_login.isProfileReceived() || !isPlatformXboxOne)
    return

  if (!nestObj?.isValid())
    return

  let guiScene = nestObj.getScene()
  if (!guiScene)
    return

  let cfg = getProfileInfo()
  let data =  handyman.renderCached("%gui/firstChoice/userNick.tpl", {
      userIcon = cfg?.icon ? $"#ui/images/avatars/{cfg.icon}.avif" : ""
      userName = colorize("@mainPlayerColor", getPlayerName(cfg?.name ?? ""))
    })
  guiScene.replaceContentFromText(nestObj, data, data.len(), null)
}

let isCountryUnlocked = @(country) unlockedCountries.contains(country)

let isCountryAvailable = @(country) country == "country_0" || country == ""
  || isCountryUnlocked(country) || is_country_available(country)

function unlockCountry(country, hideInUserlog = false, reqUnlock = true) {
  if (reqUnlock)
    reqUnlockByClient(country, hideInUserlog)

  if (!unlockedCountries.contains(country))
    unlockedCountries.append(country)
}

function checkUnlockedCountries() {
  let curUnlocked = []
  if (isNeedFirstCountryChoice())
    return curUnlocked

  let unlockAll = disable_network() || hasFeature("UnlockAllCountries") || isDiffUnlocked(1, ES_UNIT_TYPE_AIRCRAFT)
  let wasInList = unlockedCountries.len()
  foreach (_i, country in shopCountriesList)
    if (is_country_available(country)) {
      if (!unlockedCountries.contains(country)) {
        unlockedCountries.append(country)
        curUnlocked.append(country)
      }
    }
    else if (unlockAll) {
      unlockCountry(country, !::g_login.isLoggedIn())
      curUnlocked.append(country)
    }
  if (wasInList != unlockedCountries.len())
    broadcastEvent("UnlockedCountriesUpdate")
  return curUnlocked
}

function checkUnlockedCountriesByAirs() { //starter packs
  local haveUnlocked = false
  foreach (air in getAllUnits())
    if (!isUnitDefault(air)
        && isUnitUsable(air)
        && !isCountryAvailable(air.shopCountry)) {
      unlockCountry(air.shopCountry)
      haveUnlocked = true
    }
  if (haveUnlocked)
    broadcastEvent("UnlockedCountriesUpdate")
  return haveUnlocked
}

return {
  fillUserNick
  getFirstChosenUnitType
  isNeedFirstCountryChoice
  isFirstChoiceShown
  getUnlockedCountries = @() unlockedCountries
  clearUnlockedCountries = @() unlockedCountries.clear()
  isCountryUnlocked
  isCountryAvailable
  unlockCountry
  checkUnlockedCountries
  checkUnlockedCountriesByAirs
}