from "%scripts/dagui_library.nut" import *
let { getProfileCountry, setProfileCountry } = require("chard")
let { broadcastEvent, addListenersWithoutEnv, CONFIG_VALIDATION } = require("%sqStdLibs/helpers/subscriptions.nut")
let { isProfileReceived } = require("%appGlobals/login/loginState.nut")

let profileCountrySq = mkWatched(persist, "profileCountrySq", isProfileReceived.get()
  ? (getProfileCountry() ?? "country_0")
  : "country_0")

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
  profileCountrySq
  switchProfileCountry
}
