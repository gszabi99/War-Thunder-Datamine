from "%scripts/dagui_natives.nut" import periodic_task_register, periodic_task_unregister
from "%scripts/dagui_library.nut" import *
from "app" import isAppActive
let { steam_is_overlay_active } = require("steam")
let { is_builtin_browser_active } = require("%scripts/onlineShop/browserWndHelpers.nut")

const FREQUENCY_APP_STATE_UPDATE_SEC = 1
local refreshActiveAppTask = -1
let callbacksArray = []
local isAppActiveLast = true

function callIsAppActiveOrRegisterTask(_dt = 0) {
  let self = callee()
  if (refreshActiveAppTask >= 0) {
    periodic_task_unregister(refreshActiveAppTask)
    refreshActiveAppTask = -1
  }

  local needUpdateTimer = false
  let isActive = isAppActive() && !steam_is_overlay_active() && !is_builtin_browser_active()
  if (isAppActiveLast == isActive)
    needUpdateTimer = true

  if (!isActive)
    needUpdateTimer = true

  isAppActiveLast = isActive
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
