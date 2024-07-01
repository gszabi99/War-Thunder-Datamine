from "%scripts/dagui_library.nut" import *
from "%scripts/mainConsts.nut" import SEEN

let g_listener_priority = require("%scripts/g_listener_priority.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { getAllUnlocksWithBlkOrder } = require("%scripts/unlocks/unlocksCache.nut")
let { isUnlockExpired, canOpenUnlockManually, isUnlockOpened, isUnlockVisible, canClaimUnlockRewardForUnit
} = require("%scripts/unlocks/unlocksModule.nut")
let manualUnlocksSeenList = require("%scripts/seen/seenList.nut").get(SEEN.MANUAL_UNLOCKS)

let markerUnlocks = persist("markerUnlocksCache", @() [])
let manualUnlocks = persist("manualUnlocksCache", @() [])
let nightBattlesUnlocks = persist("nightBattlesUnlocks", @() [])
let isCacheValid = persist("isPersonalUnlocksCacheValid", @() { value = false })

function cache() {
  if (isCacheValid.value || !::g_login.isLoggedIn())
    return

  foreach (unlockBlk in getAllUnlocksWithBlkOrder()) {
    if (unlockBlk?.shouldMarkUnits
        && !isUnlockOpened(unlockBlk.id)
        && !isUnlockExpired(unlockBlk))
      markerUnlocks.append(unlockBlk)

    if (canOpenUnlockManually(unlockBlk))
      manualUnlocks.append(unlockBlk)

    if (unlockBlk?.chapter == "tank_realistic_night_battles" && isUnlockVisible(unlockBlk))
      nightBattlesUnlocks.append(unlockBlk)
  }

  isCacheValid.value = true
}

function getMarkerUnlocks() {
  cache()
  return markerUnlocks
}

function getManualUnlocks() {
  cache()
  return manualUnlocks
}

function getNightBattlesUnlocks() {
  cache()
  return nightBattlesUnlocks
}

function invalidateCache() {
  if (!isCacheValid.value)
    return

  markerUnlocks.clear()
  manualUnlocks.clear()
  nightBattlesUnlocks.clear()
  isCacheValid.value = false

  manualUnlocksSeenList.onListChanged()
}

manualUnlocksSeenList.setListGetter(@() getManualUnlocks()
  .filter(@(u) canClaimUnlockRewardForUnit(u.id))
  .map(@(u) u.id))

addListenersWithoutEnv({
  UnlocksCacheInvalidate = @(_p) invalidateCache()
}, g_listener_priority.CONFIG_VALIDATION)

return {
  getMarkerUnlocks
  getManualUnlocks
  getNightBattlesUnlocks
}