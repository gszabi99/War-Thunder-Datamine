local { addListenersWithoutEnv } = require("sqStdLibs/helpers/subscriptions.nut")

local battleTaskUnlocks = []
local markerUnlocks = []
local isCacheValid = false

local function update() {
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

local function getBattleTaskUnlocks() {
  if (!isCacheValid)
    update()

  return battleTaskUnlocks
}

local function getMarkerUnlocks() {
  if (!isCacheValid)
    update()

  return markerUnlocks
}

local function invalidateCache() {
  if (!isCacheValid)
    return

  battleTaskUnlocks.clear()
  markerUnlocks.clear()
  isCacheValid = false
}

addListenersWithoutEnv({
  SignOut = @(p) invalidateCache()
  LoginComplete = @(p) invalidateCache()
  UnlocksCacheInvalidate = @(p) invalidateCache()
}, ::g_listener_priority.CONFIG_VALIDATION)

return {
  getBattleTaskUnlocks
  getMarkerUnlocks
}