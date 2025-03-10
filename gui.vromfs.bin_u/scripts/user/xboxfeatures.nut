from "%scripts/dagui_library.nut" import *

let { is_gdk } = require("%scripts/clientState/platform.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { check_crossnetwork_play_privilege, check_multiplayer_sessions_privilege } = require("%scripts/gdk/permissions.nut")
let { multiplayerPrivilege } = require("%gdkLib/crossnetwork.nut")
let { isLoggedIn } = require("%appGlobals/login/loginState.nut")

local multiplayerPrivelegeCallback = null
local crossplayPrivelegeCallback = null

let dummyValue = Watched(true)


function mpPrivilegeNotify() {
  if (!isLoggedIn.get())
    return
  broadcastEvent("XboxMultiplayerPrivilegeUpdated")
}


function multiplayer_sessions_privilege_callback(is_allowed) {
  if (is_allowed)
    multiplayerPrivelegeCallback?()

  multiplayerPrivelegeCallback = null

  mpPrivilegeNotify()
}


function checkMultiplayerPrivilege(showWarning = false, cb = null) {
  if (!is_gdk) {
    cb?()
    return
  }

  multiplayerPrivelegeCallback = cb
  check_multiplayer_sessions_privilege(showWarning, multiplayer_sessions_privilege_callback)
}


function crossnetwork_play_privilege_callback(is_allowed) {
  if (!is_allowed && !is_gdk) 
    crossplayPrivelegeCallback?()

  crossplayPrivelegeCallback = null
}


function checkAndShowCrossplayWarning(cb = null, showWarning = true) {
  crossplayPrivelegeCallback = cb

  if (is_gdk)
    check_crossnetwork_play_privilege(showWarning, crossnetwork_play_privilege_callback)
  else
    crossnetwork_play_privilege_callback(false) 
}


return {
  isMultiplayerPrivilegeAvailable = is_gdk ? multiplayerPrivilege : dummyValue
  checkAndShowMultiplayerPrivilegeWarning = @(cb = null) checkMultiplayerPrivilege(true, cb)
  updateMultiplayerPrivilege = function() {
    if (!isLoggedIn.get())
      return

    checkMultiplayerPrivilege()
  }

  checkAndShowCrossplayWarning
}