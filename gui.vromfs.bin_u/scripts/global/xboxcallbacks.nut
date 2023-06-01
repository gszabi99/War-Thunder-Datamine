//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let {
  resetMultiplayerPrivilege,
  updateMultiplayerPrivilege
} = require("%scripts/user/xboxFeatures.nut")
let {logout} = require("%scripts/xbox/auth.nut")


let function onLogout() {
  logout(function() {
    resetMultiplayerPrivilege()
  })
}


addListenersWithoutEnv({
  SignOut = @(_) onLogout()
  LoginComplete = @(_) updateMultiplayerPrivilege()
} ::g_listener_priority.CONFIG_VALIDATION)
