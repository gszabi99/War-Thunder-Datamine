import "%scripts/g_listener_priority.nut" as g_listener_priority
from "%scripts/unlocks/unlocksCache.nut" import getUnlocksWhereInBlkOrder
from "%scripts/unlocks/unlocksModule.nut" import isUnlockExpired, canOpenUnlockManually, isUnlockOpened, isUnlockVisible, canClaimUnlockRewardForUnit
from "%scripts/unlocks/commandersHandbookState.nut" import CMH_CHAPTER
from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv
from "%appGlobals/login/loginState.nut" import hasFullLoginState
from "%scripts/dagui_library.nut" import *
from "%scripts/seen/seenIds.nut" import SEEN

let manualUnlocksSeenList = require("%scripts/seen/seenList.nut").get(SEEN.MANUAL_UNLOCKS)

const NIGHT_BATTLES_CHAPTER = "tank_realistic_night_battles"

let markerUnlocks = []
let manualUnlocks = []
let nightBattlesUnlocks = []
local isCacheValid = false

function cache() {
  if (isCacheValid || !hasFullLoginState.get())
    return

  let unlocks = getUnlocksWhereInBlkOrder("shouldMarkUnits || manualOpen || chapter == $nightChapter",
    { nightChapter = NIGHT_BATTLES_CHAPTER })
  foreach (unlockBlk in unlocks) {
    if (unlockBlk?.shouldMarkUnits
        && !isUnlockOpened(unlockBlk.id)
        && !isUnlockExpired(unlockBlk))
      markerUnlocks.append(unlockBlk)

    if (canOpenUnlockManually(unlockBlk) && unlockBlk?.chapter != CMH_CHAPTER)
      manualUnlocks.append(unlockBlk)

    if (unlockBlk?.chapter == NIGHT_BATTLES_CHAPTER && isUnlockVisible(unlockBlk))
      nightBattlesUnlocks.append(unlockBlk)
  }

  isCacheValid = true
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
  if (!isCacheValid)
    return

  markerUnlocks.clear()
  manualUnlocks.clear()
  nightBattlesUnlocks.clear()
  isCacheValid = false

  manualUnlocksSeenList.onListChanged()
}

manualUnlocksSeenList.setListGetter(@() getManualUnlocks()
  .filter(@(u) canClaimUnlockRewardForUnit(u.id))
  .map(@(u) u.id))

addListenersWithoutEnv({
  UnlocksCacheInvalidate = @(_p) invalidateCache()
}, g_listener_priority.CONFIG_VALIDATION)

return freeze({
  getMarkerUnlocks
  getManualUnlocks
  getNightBattlesUnlocks
})