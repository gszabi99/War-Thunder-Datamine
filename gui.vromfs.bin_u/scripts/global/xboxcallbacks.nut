let { startLogout } = require("%scripts/login/logout.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let {
  resetMultiplayerPrivilege,
  updateMultiplayerPrivilege
} = require("%scripts/user/xboxFeatures.nut")

addListenersWithoutEnv({
  SignOut = @(p) resetMultiplayerPrivilege()
  XboxSystemUIReturn = @(p) updateMultiplayerPrivilege()
  LoginComplete = @(p) updateMultiplayerPrivilege()
})

::xbox_on_start_logout <- startLogout