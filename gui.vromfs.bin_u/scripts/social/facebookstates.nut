from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let function isAvailableFacebook() {
  return hasFeature("Facebook") && ::get_country_code() != "RU"
}

return {
  isAvailableFacebook,
}