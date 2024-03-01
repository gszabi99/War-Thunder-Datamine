from "%scripts/dagui_library.nut" import *

let g_listener_priority = require("%scripts/g_listener_priority.nut")
let logX = require("%sqstd/log.nut")().with_prefix("[XBOX_CALLBACKS] ")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let {
  resetMultiplayerPrivilege,
  updateMultiplayerPrivilege
} = require("%scripts/user/xboxFeatures.nut")


function onLogout() {
  logX("onLogout")
  resetMultiplayerPrivilege()
}


function onLoginComplete() {
  logX("onLoginComplete")
  updateMultiplayerPrivilege()
}


addListenersWithoutEnv({
  SignOut = @(_) onLogout()
  LoginComplete = @(_) onLoginComplete()
} g_listener_priority.CONFIG_VALIDATION)
