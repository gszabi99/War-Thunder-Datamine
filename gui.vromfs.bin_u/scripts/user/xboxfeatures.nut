let { isPlatformXboxOne } = require("%scripts/clientState/platform.nut")

let isMultiplayerPrivilegeAvailable = persist("isMultiplayerPrivilegeAvailable", @() Watched(true))
local multiplayerPrivelegeCallback = null

let function checkMultiplayerPrivilege(showMarket = false, cb = null)
{
  if (!isPlatformXboxOne) {
    cb?()
    return
  }

  multiplayerPrivelegeCallback = cb
  ::check_multiplayer_sessions_privilege(showMarket)
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

return {
  isMultiplayerPrivilegeAvailable
  checkAndShowMultiplayerPrivilegeWarning = @(cb = null) checkMultiplayerPrivilege(true, cb)
  resetMultiplayerPrivilege = @() isMultiplayerPrivilegeAvailable(true)
  updateMultiplayerPrivilege = function() {
    if (!::g_login.isLoggedIn())
      return

    checkMultiplayerPrivilege()
  }
}