from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this
let { getCountryCode } = require("auth_wt")

let function isAvailableFacebook() {
  return hasFeature("Facebook") && getCountryCode() != "RU"
}

return {
  isAvailableFacebook,
}