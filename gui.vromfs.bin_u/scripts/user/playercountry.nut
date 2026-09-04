from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent, addListenersWithoutEnv, CONFIG_VALIDATION
from "%appGlobals/login/loginState.nut" import isProfileReceived
from "chard" import getProfileCountry, setProfileCountry
from "%scripts/dagui_library.nut" import *

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
