from "%scripts/dagui_library.nut" import *
let { getCountryCode } = require("auth_wt")
let { isPlatformSony, isPlatformXbox } = require("%scripts/clientState/platform.nut")
let sonyUser = require("sony.user")
let { get_region } = require("%gdkLib/impl/app.nut")

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

return {
  isPlayerRecommendedEmailRegistration = @() getPlayerCountryCode() in countriesWithRecommendEmailRegistration
  getPlayerCountryCode
}
