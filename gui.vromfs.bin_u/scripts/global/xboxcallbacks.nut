import "%scripts/g_listener_priority.nut" as g_listener_priority
from "%scripts/user/xboxFeatures.nut" import updateMultiplayerPrivilege
from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv
from "%scripts/dagui_library.nut" import *

let logX = require("%sqstd/log.nut")().with_prefix("[XBOX_CALLBACKS] ")


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
