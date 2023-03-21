//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { getAllUnlocksWithBlkOrder } = require("%scripts/unlocks/unlocksCache.nut")
let { isUnlockExpired } = require("%scripts/unlocks/unlocksModule.nut")

let battleTaskUnlocks = []
let markerUnlocks = []
local isCacheValid = false

let function update() {
  if (!::g_login.isLoggedIn())
    return

  foreach (unlockBlk in getAllUnlocksWithBlkOrder()) {
    if (unlockBlk?.showAsBattleTask)
      battleTaskUnlocks.append(unlockBlk)

    if (unlockBlk?.shouldMarkUnits
        && !::is_unlocked_scripted(-1, unlockBlk?.id)
        && !isUnlockExpired(unlockBlk))
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