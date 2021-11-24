local { isString } = require("sqStdLibs/helpers/u.nut")
local subscriptions = require("sqStdLibs/helpers/subscriptions.nut")

local legalRestrictionsChecked = persist("legalRestrictionsChecked", @() ::Watched(false))
local isPurchaseAllowed = persist("isPurchaseAllowed", @() ::Watched(true))

local countryCodeToLocId = {
  BE = "country_belgium",
  NL = "country_netherlands"
}

// restrictedInCountries - comma-separated country codes
local function hasLegalRestictions(restrictedInCountries)
{
  if (!isString(restrictedInCountries) || restrictedInCountries.len() == 0)
    return false

  local userCountry = ::get_country_code()
  return restrictedInCountries.split(",").findindex(@(c) c == userCountry) != null
}

local function showLegalRestrictionsNotice()
{
  ::scene_msg_box("legalRestrictionsNotice", null, ::loc("msgbox/legalRestrictionsNotice"),
    [["ok"]], "ok")
}

local function getCountryName(countryCode)
{
  if (countryCode not in countryCodeToLocId)
  {
    ::script_net_assert_once("Legal restrictions: unsupported country code",
      $"Random rewards functionality is limited in {countryCode}, but no loc key was defined")
    return ""
  }

  local res = ::loc(countryCodeToLocId[countryCode], "")
  if (res == "")
    ::script_net_assert_once("Legal restrictions: localization is not found",
      $"Random rewards functionality is limited in {countryCode}, but no localization was provided")

  return res
}

local function checkLegalRestrictions(restrictedInCountries, onSuccessCb)
{
  if (!hasLegalRestictions(restrictedInCountries))
    return onSuccessCb()

  if (legalRestrictionsChecked.value)
  {
    if (isPurchaseAllowed.value)
      return onSuccessCb()

    showLegalRestrictionsNotice()
    return false
  }

  local onCountryConfirmed = function() {
    legalRestrictionsChecked(true)
    isPurchaseAllowed(false)
    showLegalRestrictionsNotice()
  }

  local onCountryDeclined = function() {
    legalRestrictionsChecked(true)
    isPurchaseAllowed(true)
    onSuccessCb()
  }

  local countryName = getCountryName(::get_country_code())
  if (countryName == "")
    return onSuccessCb()

  local text = ::loc("msgbox/countryConfirmation", { country = countryName })
  ::scene_msg_box("countryConfirmation", null, text,
    [["yes", onCountryConfirmed], ["no", onCountryDeclined]], "yes", { cancel_fn = @() null })
}

subscriptions.addListenersWithoutEnv({
  SignOut = @(p) legalRestrictionsChecked(false)
})

return {
  checkLegalRestrictions
}