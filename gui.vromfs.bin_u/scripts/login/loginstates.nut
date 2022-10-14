from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")

let isProfileReceived = Watched(::g_login.isProfileReceived())

addListenersWithoutEnv({
  LoginStateChanged = @(_) isProfileReceived(::g_login.isProfileReceived())
})

return {
  isProfileReceived
}