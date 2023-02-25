//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this
let { getCountryCode } = require("auth_wt")
let { isPlatformSony, isPlatformXboxOne } = require("%scripts/clientState/platform.nut")
let sonyUser = require("sony.user")
let { addListenersWithoutEnv, CONFIG_VALIDATION } = require("%sqStdLibs/helpers/subscriptions.nut")

let getProfileCountry = @() ::get_profile_country() ?? "country_0"

let profileCountrySq = Watched(::g_login.isProfileReceived()
  ? getProfileCountry()
  : "country_0")

let function xboxGetCountryCode() {
  let xbox_code = ::xbox_get_region()
  if (xbox_code != "")
    return xbox_code.toupper()
  return getCountryCode()
}

let getPlayerCountryCode = isPlatformSony ? @() sonyUser?.country.toupper()
  : isPlatformXboxOne ? xboxGetCountryCode
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

let function switchProfileCountry(country) {
  if (country == profileCountrySq.value)
    return

  ::set_profile_country(country)
  profileCountrySq(country)
  ::g_squad_utils.updateMyCountryData()
  ::broadcastEvent("CountryChanged")
}

addListenersWithoutEnv({
  ProfileUpdated = @(_) profileCountrySq(getProfileCountry())
}, CONFIG_VALIDATION)

return {
  isPlayerRecommendedEmailRegistration = @() getPlayerCountryCode() in countriesWithRecommendEmailRegistration
  profileCountrySq
  switchProfileCountry
}
