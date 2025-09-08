from "%scripts/dagui_library.nut" import *
let { getCountryCode } = require("auth_wt")
let subscriptions = require("%sqStdLibs/helpers/subscriptions.nut")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")

let legalRestrictionsChecked = mkWatched(persist, "legalRestrictionsChecked", false)
let isPurchaseAllowed = mkWatched(persist, "isPurchaseAllowed", true)

let countryCodeToLocId = {
  BE = "country_belgium",
  NL = "country_netherlands",
  RU = "country_russia",
  KR = "country_south_korea",
}


function hasLegalRestictions(restrictedInCountries) {
  if (restrictedInCountries.len() == 0)
    return false

  let userCountry = getCountryCode()
  return restrictedInCountries.findindex(@(c) c == userCountry) != null
}

function isHiddenByCountry(hiddenInCountries) {
  if (hiddenInCountries.len() == 0)
    return false
  return hiddenInCountries.contains(getCountryCode())
}

function showLegalRestrictionsNotice() {
  scene_msg_box("legalRestrictionsNotice", null, loc("msgbox/legalRestrictionsNotice"),
    [["ok"]], "ok")
}

function getCountryName(countryCode) {
  if (countryCode not in countryCodeToLocId) {
    script_net_assert_once("Legal restrictions: unsupported country code",
      $"Random rewards functionality is limited in {countryCode}, but no loc key was defined")
    return ""
  }

  let res = loc(countryCodeToLocId[countryCode], "")
  if (res == "")
    script_net_assert_once("Legal restrictions: localization is not found",
      $"Random rewards functionality is limited in {countryCode}, but no localization was provided")

  return res
}

function checkLegalRestrictions(restrictedInCountries, onSuccessCb) {
  if (!hasLegalRestictions(restrictedInCountries))
    return onSuccessCb()

  if (legalRestrictionsChecked.get()) {
    if (isPurchaseAllowed.get())
      return onSuccessCb()

    showLegalRestrictionsNotice()
    return false
  }

  let onCountryConfirmed = function() {
    legalRestrictionsChecked.set(true)
    isPurchaseAllowed.set(false)
    showLegalRestrictionsNotice()
  }

  let onCountryDeclined = function() {
    legalRestrictionsChecked.set(true)
    isPurchaseAllowed.set(true)
    onSuccessCb()
  }

  let countryName = getCountryName(getCountryCode())
  if (countryName == "")
    return onSuccessCb()

  let text = loc("msgbox/countryConfirmation", { country = countryName })
  scene_msg_box("countryConfirmation", null, text,
    [["yes", onCountryConfirmed], ["no", onCountryDeclined]], "yes", { cancel_fn = @() null })
}

subscriptions.addListenersWithoutEnv({
  SignOut = @(_p) legalRestrictionsChecked.set(false)
})

return {
  checkLegalRestrictions
  isHiddenByCountry
}