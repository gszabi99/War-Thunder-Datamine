from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { startLogout } = require("%scripts/login/logout.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let {
  resetMultiplayerPrivilege,
  updateMultiplayerPrivilege
} = require("%scripts/user/xboxFeatures.nut")


let function onLogout() {
  ::xbox_on_logout(function(_) {
    resetMultiplayerPrivilege()
  })
}


addListenersWithoutEnv({
  SignOut = @(_) onLogout()
  XboxSystemUIReturn = @(p) updateMultiplayerPrivilege()
  LoginComplete = @(p) updateMultiplayerPrivilege()
})

::xbox_on_start_logout <- startLogout