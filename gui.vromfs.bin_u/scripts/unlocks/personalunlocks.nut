from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")

let battleTaskUnlocks = []
let markerUnlocks = []
local isCacheValid = false

let function update() {
  if (!::g_login.isLoggedIn())
    return

  foreach (unlockBlk in ::g_unlocks.getAllUnlocksWithBlkOrder()) {
    if (unlockBlk?.showAsBattleTask)
      battleTaskUnlocks.append(unlockBlk)

    if (unlockBlk?.shouldMarkUnits
        && !::is_unlocked_scripted(-1, unlockBlk?.id)
        && !::g_unlocks.isUnlockExpired(unlockBlk))
      markerUnlocks.append(unlockBlk)
  }

  isCacheValid = true
}

let function getBattleTaskUnlocks() {
  if (!isCacheValid)
    update()

  return battleTaskUnlocks
}

let function getMarkerUnlocks() {
  if (!isCacheValid)
    update()

  return markerUnlocks
}

let function invalidateCache() {
  if (!isCacheValid)
    return

  battleTaskUnlocks.clear()
  markerUnlocks.clear()
  isCacheValid = false
}

addListenersWithoutEnv({
  SignOut = @(_p) invalidateCache()
  LoginComplete = @(_p) invalidateCache()
  UnlocksCacheInvalidate = @(_p) invalidateCache()
}, ::g_listener_priority.CONFIG_VALIDATION)

return {
  getBattleTaskUnlocks
  getMarkerUnlocks
}