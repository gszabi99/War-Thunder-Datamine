from "%scripts/dagui_library.nut" import *
let { getProfileCountry, setProfileCountry } = require("chard")
let { getCountryCode } = require("auth_wt")
let { isPlatformSony, isPlatformXbox } = require("%scripts/clientState/platform.nut")
let sonyUser = require("sony.user")
let { broadcastEvent, addListenersWithoutEnv, CONFIG_VALIDATION } = require("%sqStdLibs/helpers/subscriptions.nut")
let { get_region } = require("%gdkLib/impl/app.nut")
let { isProfileReceived } = require("%appGlobals/login/loginState.nut")

let profileCountrySq = mkWatched(persist, "profileCountrySq", isProfileReceived.get()
  ? (getProfileCountry() ?? "country_0")
  : "country_0")

function xboxGetCountryCode() {
  let xbox_code = get_region()
  if (xbox_code != "")
    return xbox_code.toupper()
  return getCountryCode()
}

let getPlayerCountryCode = isPlatformSony ? @() sonyUser?.country.toupper()
  : isPlatformXbox ? xboxGetCountryCode
  : getCountryCode

let countriesWithRecommendEmailRegistration = {
  AZ = "Azerbaijan"
  AM = "Armenia"
  BY = "Belarus"
  GE = "Georgia"
  KZ = "Kazakhstan"
  KG = "Kyrgyzstan"
  LV = "Latvia"
  LT = "Lithuania"
  MD = "Moldova"
  RU = "Russia"
  TJ = "Tajikistan"
  TM = "Turkmenistan"
  UZ = "Uzbekistan"
  UA = "Ukraine"
  EE = "Estonia"
}

function switchProfileCountry(country) {
  if (country == profileCountrySq.get())
    return

  setProfileCountry(country)
  profileCountrySq.set(country)
  broadcastEvent("CountryChanged")
}

addListenersWithoutEnv({
  ProfileUpdated = @(_) profileCountrySq.set(getProfileCountry() ?? "country_0")
}, CONFIG_VALIDATION)

return {
  isPlayerRecommendedEmailRegistration = @() getPlayerCountryCode() in countriesWithRecommendEmailRegistration
  profileCountrySq
  switchProfileCountry
}
