from "%scripts/dagui_natives.nut" import get_profile_country, set_profile_country
from "%scripts/dagui_library.nut" import *
let { getCountryCode } = require("auth_wt")
let { isPlatformSony, isPlatformXbox } = require("%scripts/clientState/platform.nut")
let sonyUser = require("sony.user")
let { broadcastEvent, addListenersWithoutEnv, CONFIG_VALIDATION } = require("%sqStdLibs/helpers/subscriptions.nut")
let { get_region } = require("%gdkLib/impl/app.nut")
let { isProfileReceived } = require("%appGlobals/login/loginState.nut")

let getProfileCountry = @() get_profile_country() ?? "country_0"

let profileCountrySq = mkWatched(persist, "profileCountrySq", isProfileReceived.get()
  ? getProfileCountry()
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
  if (country == profileCountrySq.value)
    return

  set_profile_country(country)
  profileCountrySq(country)
  broadcastEvent("CountryChanged")
}

addListenersWithoutEnv({
  ProfileUpdated = @(_) profileCountrySq(getProfileCountry())
}, CONFIG_VALIDATION)

return {
  isPlayerRecommendedEmailRegistration = @() getPlayerCountryCode() in countriesWithRecommendEmailRegistration
  profileCountrySq
  switchProfileCountry
}
