from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { isPlatformXboxOne } = require("%scripts/clientState/platform.nut")
let { crossNetworkPlayStatus } = require("%scripts/social/crossplay.nut")

let isMultiplayerPrivilegeAvailable = persist("isMultiplayerPrivilegeAvailable", @() Watched(true))

local multiplayerPrivelegeCallback = null
local crossplayPrivelegeCallback = null

let function checkMultiplayerPrivilege(showWarning = false, cb = null)
{
  if (!isPlatformXboxOne) {
    cb?()
    return
  }

  multiplayerPrivelegeCallback = cb
  ::check_multiplayer_sessions_privilege(showWarning)
}

::check_multiplayer_sessions_privilege_callback <- function(isAllowed)
{
  isMultiplayerPrivilegeAvailable(isAllowed)

  if (isAllowed)
    multiplayerPrivelegeCallback?()

  multiplayerPrivelegeCallback = null

  if (!::g_login.isLoggedIn())
    return

  ::broadcastEvent("XboxMultiplayerPrivilegeUpdated")
}

let function checkAndShowCrossplayWarning(cb = null, showWarning = true) {
  crossplayPrivelegeCallback = cb

  if (isPlatformXboxOne)
    ::check_crossnetwork_play_privilege(showWarning)
  else
    ::check_crossnetwork_play_privilege_callback(false) //Default value in code
}

::check_crossnetwork_play_privilege_callback <- function(isAllowed) {
  if (isPlatformXboxOne) //callback returns actual updated state
    crossNetworkPlayStatus(isAllowed)

  if (!isAllowed && !isPlatformXboxOne) //Xbox code will show warning message if isAllowed = false
    crossplayPrivelegeCallback?()

  crossplayPrivelegeCallback = null
}

return {
  isMultiplayerPrivilegeAvailable
  checkAndShowMultiplayerPrivilegeWarning = @(cb = null) checkMultiplayerPrivilege(true, cb)
  resetMultiplayerPrivilege = @() isMultiplayerPrivilegeAvailable(true)
  updateMultiplayerPrivilege = function() {
    if (!::g_login.isLoggedIn())
      return

    checkMultiplayerPrivilege()
  }

  checkAndShowCrossplayWarning
}