let { addListenersWithoutEnv } = require("sqStdLibs/helpers/subscriptions.nut")

let isProfileReceived = ::Watched(::g_login.isProfileReceived())

addListenersWithoutEnv({
  LoginStateChanged = @(_) isProfileReceived(::g_login.isProfileReceived())
})

return {
  isProfileReceived
}