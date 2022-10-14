from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { isPlatformSony, isPlatformXboxOne } = require("%scripts/clientState/platform.nut")
let sonyUser = require("sony.user")

let function xboxGetCountryCode() {
  let xbox_code = ::xbox_get_region()
  if (xbox_code != "")
    return xbox_code.toupper()
  return ::get_country_code()
}

let getPlayerCountryCode = isPlatformSony ? @() sonyUser?.country.toupper()
  : isPlatformXboxOne ? xboxGetCountryCode
  : ::get_country_code

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

return {
  isPlayerRecommendedEmailRegistration = @() getPlayerCountryCode() in countriesWithRecommendEmailRegistration
}
