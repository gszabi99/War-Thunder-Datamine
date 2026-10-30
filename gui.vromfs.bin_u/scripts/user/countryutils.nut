import "sony.user" as sonyUser
from "%sqstd/platform.nut" import isSony, isXbox
from "auth_wt" import getCountryCode
from "%gdkLib/impl/app.nut" import get_region
from "%scripts/dagui_library.nut" import *

function xboxGetCountryCode() {
  let xbox_code = get_region()
  if (xbox_code != "")
    return xbox_code.toupper()
  return getCountryCode()
}

let getPlayerCountryCode = isSony ? @() sonyUser?.country.toupper()
  : isXbox ? xboxGetCountryCode
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

return freeze({
  isPlayerRecommendedEmailRegistration = @() getPlayerCountryCode() in countriesWithRecommendEmailRegistration
  getPlayerCountryCode
})
