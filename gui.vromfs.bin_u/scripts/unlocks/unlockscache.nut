from "%scripts/dagui_library.nut" import *

let g_listener_priority = require("%scripts/g_listener_priority.nut")
let { broadcastEvent, addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { regionalUnlocks } = require("%scripts/unlocks/regionalUnlocks.nut")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { get_unlocks_blk, get_personal_unlocks_blk } = require("blkGetters")
let { isLoggedIn } = require("%appGlobals/login/loginState.nut")

let unlocksCacheById = persist("unlocksCacheById", @() {})
let personalUnlocksCacheById = persist("personalUnlocksCacheById", @() {})
let regionalUnlocksCacheById = persist("regionalUnlocksCacheById", @() {})
let unlocksCacheArray = persist("unlocksCacheArray", @() [])
let personalUnlocksCacheArray = persist("personalUnlocksCacheArray", @() [])
let regionalUnlocksCacheArray = persist("regionalUnlocksCacheArray", @() [])

let unlocksCacheByType = persist("unlocksCacheByType", @() {})
let personalUnlocksCacheByType = persist("personalUnlocksCacheByType", @() {})
let regionalUnlocksCacheByType = persist("regionalUnlocksCacheByType", @() {})
let unlocksCacheIdxsById = persist("unlocksCacheIdxsById", @() {})
let personalUnlocksCacheIdxsById = persist("personalUnlocksCacheIdxsById", @() {})
let regionalUnlocksCacheIdxsById = persist("regionalUnlocksCacheIdxsById", @() {})

let isCacheValid = persist("unlocksIsCacheValid", @() { value = false })

local combinedCacheById = null
local combinedCacheArray = null
let combinedCacheByType = {}

let unlocksCaches = {
  charUnlocks = {
    cacheById = unlocksCacheById
    cacheArray = unlocksCacheArray
    cacheByType = unlocksCacheByType
    cacheIdxs = unlocksCacheIdxsById
  }
  personalUnlocks = {
    cacheById = personalUnlocksCacheById
    cacheArray = personalUnlocksCacheArray
    cacheByType = personalUnlocksCacheByType
    cacheIdxs = personalUnlocksCacheIdxsById
  }
  regionalUnlocks = {
    cacheById = regionalUnlocksCacheById
    cacheArray = regionalUnlocksCacheArray
    cacheByType = regionalUnlocksCacheByType
    cacheIdxs = regionalUnlocksCacheIdxsById
  }
}

function addUnlockToCache(unlock, unlocksId) {
  if (unlock?.id == null) {
    let unlockConfigString = toString(unlock, 2) 
    script_net_assert_once("missing id in unlock", "Unlocks: Missing id in unlock. Cannot cache unlock.")
    return
  }

  let { cacheById, cacheArray, cacheByType, cacheIdxs } = unlocksCaches[unlocksId]
  cacheById[unlock.id] <- unlock
  let typeName = unlock.type
  if (typeName not in cacheByType)
    cacheByType[typeName] <- []

  cacheIdxs[unlock.id] <- { idxInArray = cacheArray.len(), idxInType = cacheByType[typeName].len() }
  cacheArray.append(unlock)
  cacheByType[typeName].append(unlock)
}

function clearCachesUnlocks(caches) {
  let { cacheById, cacheArray, cacheByType, cacheIdxs } = caches
  cacheById.clear()
  cacheArray.clear()
  cacheByType.clear()
  cacheIdxs.clear()
}

function cacheProfileUnlocks(blk, unlocksId) {
  clearCachesUnlocks(unlocksCaches[unlocksId])
  foreach (unlock in (blk % "unlockable"))
    addUnlockToCache(unlock, unlocksId)
}

function clearCombinedCache() {
  combinedCacheById = null
  combinedCacheArray = null
  combinedCacheByType.clear()
}

let cacheCharUnlocks = @() cacheProfileUnlocks(get_unlocks_blk(), "charUnlocks")

function cache() {
  if (isCacheValid.value)
    return

  isCacheValid.value = true
  clearCombinedCache()
  cacheCharUnlocks()
  if (!isLoggedIn.get())
    return

  cacheProfileUnlocks(get_personal_unlocks_blk(), "personalUnlocks")
}

function invalidateCache() {
  isCacheValid.value = false
  broadcastEvent("UnlocksCacheInvalidate")
}

function clearAllCache() {
  foreach (caches in unlocksCaches)
    clearCachesUnlocks(caches)
  invalidateCache()
}

function getAllUnlocks() {
  cache()
  if (combinedCacheById == null)
    combinedCacheById = unlocksCaches.reduce(@(res, v) res.__update(v.cacheById), {})
  return combinedCacheById
}

function getAllUnlocksWithBlkOrder() {
  cache()
  if (combinedCacheArray == null)
    combinedCacheArray = unlocksCaches.reduce(@(res, v) res.extend(v.cacheArray), [])
  return combinedCacheArray
}

let getUnlockById = @(unlockId) getAllUnlocks()?[unlockId]

function getUnlocksByTypeInBlkOrder(typeName) {
  cache()
  if (typeName not in combinedCacheByType)
    combinedCacheByType[typeName] <- unlocksCaches.reduce(@(res, v) res.extend(v.cacheByType?[typeName] ?? []), [])
  return combinedCacheByType[typeName]
}

regionalUnlocks.subscribe(function(_) {
  let { cacheById, cacheArray, cacheByType, cacheIdxs } = unlocksCaches.regionalUnlocks
  
  local isChanged = false
  for (local i = cacheArray.len() - 1; i >= 0; --i) {
    let unlock = cacheArray[i]
    if (unlock.id in regionalUnlocks.get())
      continue 

    isChanged = true
    cacheArray.remove(i)
    cacheById.$rawdelete(unlock.id)
    let { idxInType } = cacheIdxs[unlock.id]
    cacheByType[unlock.type].remove(idxInType)
  }

  foreach (unlock in regionalUnlocks.get())
    if (unlock.id not in cacheById) {
      isChanged = true
      addUnlockToCache(unlock, "regionalUnlocks")
    }

  if (!isChanged)
    return

  clearCombinedCache()
  broadcastEvent("RegionalUnlocksChanged")
})

addListenersWithoutEnv({
  SignOut = @(_) clearAllCache()
  LoginComplete = @(_) clearAllCache()
  ProfileUpdated = @(_) invalidateCache()
}, g_listener_priority.CONFIG_VALIDATION)

return {
  getAllUnlocks
  getAllUnlocksWithBlkOrder
  getUnlockById
  getUnlocksByTypeInBlkOrder
}