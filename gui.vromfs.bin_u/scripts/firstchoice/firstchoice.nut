from "%scripts/unit/unitsData.nut" import getAllUnits
from "%sqStdLibs/helpers/handyman.nut" import handyman
from "%scripts/user/remapNick.nut" import getPlayerName
from "%scripts/unlocks/unlocksModule.nut" import reqUnlockByClient
from "%scripts/tutorials/tutorialsState.nut" import isDiffUnlocked
from "%scripts/unit/unitStatus.nut" import isUnitDefault, isUnitUsable
from "%scripts/user/userInfoStats.nut" import getProfileInfo
from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent
from "%appGlobals/login/loginState.nut" import hasFullLoginState, isProfileReceived
from "%globalScripts/clientState/initialState.nut" import disableNetwork
from "%sqstd/platform.nut" import is_gdk
from "%scripts/dagui_natives.nut" import stat_get_value_respawns, is_country_available
from "%globalScripts/unitTypeConsts.nut" import *
from "%scripts/dagui_library.nut" import *

let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")

let isFirstChoiceShown = Watched(false)

let unlockedCountries = mkHardPersist("firstChoice.firstChoice")("unlockedCountries", [])

let getFirstChosenUnitType = function(defValue = ES_UNIT_TYPE_INVALID) {
  foreach (unitType in unitTypes.types)
    if (unitType.isFirstChosen())
      return unitType.esUnitType
  return defValue
}

let reqFirstUnitTypeChoice = function() {
  return getFirstChosenUnitType() == ES_UNIT_TYPE_INVALID
    && !stat_get_value_respawns(0, 1)
    && !disableNetwork
}

let fillUserNick = function (nestObj, tpl = "%gui/firstChoice/userNick.tpl", doChecks = true) {
  if (doChecks && (!isProfileReceived.get() || !is_gdk))
    return

  if (!nestObj?.isValid())
    return

  let guiScene = nestObj.getScene()
  if (!guiScene)
    return

  let cfg = getProfileInfo()
  let data = handyman.renderCached(tpl, {
    userIcon = cfg?.icon ?? "cardicon_default"
    userName = colorize("@playerNameColorWhite", getPlayerName(cfg?.name ?? ""))
    userFrame = "!ui/images/avatar_frames/frame_simple_solid_grey.avif"
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
  if (reqFirstUnitTypeChoice())
    return curUnlocked

  let unlockAll = disableNetwork || hasFeature("UnlockAllCountries") || isDiffUnlocked(1, ES_UNIT_TYPE_AIRCRAFT)
  let wasInList = unlockedCountries.len()
  foreach (_i, country in shopCountriesList)
    if (is_country_available(country)) {
      if (!unlockedCountries.contains(country)) {
        unlockedCountries.append(country)
        curUnlocked.append(country)
      }
    }
    else if (unlockAll) {
      unlockCountry(country, !hasFullLoginState.get())
      curUnlocked.append(country)
    }
  if (wasInList != unlockedCountries.len())
    broadcastEvent("UnlockedCountriesUpdate")
  return curUnlocked
}

function checkUnlockedCountriesByAirs() { 
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

return freeze({
  fillUserNick
  getFirstChosenUnitType
  reqFirstUnitTypeChoice
  isFirstChoiceShown
  getUnlockedCountries = @() unlockedCountries
  clearUnlockedCountries = @() unlockedCountries.clear()
  isCountryUnlocked
  isCountryAvailable
  unlockCountry
  checkUnlockedCountries
  checkUnlockedCountriesByAirs
})
