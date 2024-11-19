from "%scripts/dagui_library.nut" import *

let { isPlatformXboxOne } = require("%scripts/clientState/platform.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { check_crossnetwork_play_privilege, check_multiplayer_sessions_privilege } = require("%scripts/xbox/permissions.nut")
let { multiplayerPrivilege } = require("%xboxLib/crossnetwork.nut")

local multiplayerPrivelegeCallback = null
local crossplayPrivelegeCallback = null

let dummyValue = Watched(true)


function mpPrivilegeNotify() {
  if (!::g_login.isLoggedIn())
    return
  broadcastEvent("XboxMultiplayerPrivilegeUpdated")
}


if (isPlatformXboxOne) {
  multiplayerPrivilege.subscribe(function(_){
    mpPrivilegeNotify()
  })
}


function multiplayer_sessions_privilege_callback(is_allowed) {
  if (is_allowed)
    multiplayerPrivelegeCallback?()

  multiplayerPrivelegeCallback = null

  mpPrivilegeNotify()
}


function checkMultiplayerPrivilege(showWarning = false, cb = null) {
  if (!isPlatformXboxOne) {
    cb?()
    return
  }

  multiplayerPrivelegeCallback = cb
  check_multiplayer_sessions_privilege(showWarning, multiplayer_sessions_privilege_callback)
}


function crossnetwork_play_privilege_callback(is_allowed) {
  if (!is_allowed && !isPlatformXboxOne) //Xbox code will show warning message if isAllowed = false
    crossplayPrivelegeCallback?()

  crossplayPrivelegeCallback = null
}


function checkAndShowCrossplayWarning(cb = null, showWarning = true) {
  crossplayPrivelegeCallback = cb

  if (isPlatformXboxOne)
    check_crossnetwork_play_privilege(showWarning, crossnetwork_play_privilege_callback)
  else
    crossnetwork_play_privilege_callback(false) //Default value in code
}


return {
  isMultiplayerPrivilegeAvailable = isPlatformXboxOne ? multiplayerPrivilege : dummyValue
  checkAndShowMultiplayerPrivilegeWarning = @(cb = null) checkMultiplayerPrivilege(true, cb)
  updateMultiplayerPrivilege = function() {
    if (!::g_login.isLoggedIn())
      return

    checkMultiplayerPrivilege()
  }

  checkAndShowCrossplayWarning
}