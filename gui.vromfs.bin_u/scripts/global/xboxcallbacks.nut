from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv
from "%scripts/dagui_library.nut" import *

let g_listener_priority = require("%scripts/g_listener_priority.nut")
let logX = require("%sqstd/log.nut")().with_prefix("[XBOX_CALLBACKS] ")
let { updateMultiplayerPrivilege } = require("%scripts/user/xboxFeatures.nut")


function onLogout() {
  logX("onLogout")
}


function onLoginComplete() {
  logX("onLoginComplete")
  updateMultiplayerPrivilege()
}


addListenersWithoutEnv({
  SignOut = @(_) onLogout()
  LoginComplete = @(_) onLoginComplete()
} g_listener_priority.CONFIG_VALIDATION)
