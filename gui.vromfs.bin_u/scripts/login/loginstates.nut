from "%scripts/dagui_library.nut" import *

let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")

let isProfileReceived = Watched(::g_login.isProfileReceived())

addListenersWithoutEnv({
  LoginStateChanged = @(_) isProfileReceived(::g_login.isProfileReceived())
  ScriptsReloaded = @(_) isProfileReceived(::g_login.isProfileReceived())  //TO DO: Need move current login state to watch
})

return {
  isProfileReceived
}