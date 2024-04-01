from "%scripts/dagui_natives.nut" import is_app_active, periodic_task_register, periodic_task_unregister
from "%scripts/dagui_library.nut" import *
let { steam_is_overlay_active } = require("steam")

const FREQUENCY_APP_STATE_UPDATE_SEC = 1
local refreshActiveAppTask = -1
let callbacksArray = []
local isAppActive = true

function callIsAppActiveOrRegisterTask(_dt = 0) {
  let self = callee()
  if (refreshActiveAppTask >= 0) {
    periodic_task_unregister(refreshActiveAppTask)
    refreshActiveAppTask = -1
  }

  local needUpdateTimer = false
  let isActive = ::is_app_active() && !steam_is_overlay_active() && !::is_builtin_browser_active()
  if (isAppActive == isActive)
    needUpdateTimer = true

  if (!isActive)
    needUpdateTimer = true

  isAppActive = isActive
  if (needUpdateTimer) {
    refreshActiveAppTask = periodic_task_register(this,
      self, FREQUENCY_APP_STATE_UPDATE_SEC)

    return
  }

  let list = clone callbacksArray
  callbacksArray.clear()
  foreach (cb in list)
    cb()
}

function callbackWhenAppWillActive(cb) {
  callbacksArray.append(cb)
  callIsAppActiveOrRegisterTask()
}


return callbackWhenAppWillActive
