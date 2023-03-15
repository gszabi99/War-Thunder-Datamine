from "%scripts/dagui_library.nut" import *
#no-root-fallback
#explicit-this
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")

let cacheById = persist("unlocksCacheById", @() {})
let cacheArray = persist("unlocksCacheArray", @() [])
// <unlockTypeName> = { byName = { <unlockId> = <unlockBlk> }, inOrder = [<unlockBlk>] }
let cacheByType = persist("unlocksCacheByType", @() {})
let isCacheValid = persist("unlocksIsCacheValid", @() { value = false })

let function convertBlkToCache(blk) {
  foreach (unlock in (blk % "unlockable")) {
    if (unlock?.id == null) {
      let unlockConfigString = toString(unlock, 2) // warning disable: -declared-never-used
      ::script_net_assert_once("missing id in unlock", "Unlocks: Missing id in unlock. Cannot cache unlock.")
      continue
    }
    cacheById[unlock.id] <- unlock
    cacheArray.append(unlock)

    let typeName = unlock.type
    if (typeName not in cacheByType)
      cacheByType[typeName] <- { byName = {}, inOrder = [] }
    cacheByType[typeName].byName[unlock.id] <- unlock
    cacheByType[typeName].inOrder.append(unlock)
  }
}

let function cache() {
  if (isCacheValid.value)
    return

  isCacheValid.value = true
  cacheById.clear()
  cacheArray.clear()
  cacheByType.clear()
  convertBlkToCache(::get_unlocks_blk())
  convertBlkToCache(::get_personal_unlocks_blk())
}

let function invalidateCache() {
  isCacheValid.value = false
  ::broadcastEvent("UnlocksCacheInvalidate")
}

let function getAllUnlocks() {
  cache()
  return cacheById
}

let function getAllUnlocksWithBlkOrder() {
  cache()
  return cacheArray
}

let function getUnlockById(unlockId) {
  if (::g_login.isLoggedIn())
    return getTblValue(unlockId, getAllUnlocks())

  // For before login actions.
  let blk = ::get_unlocks_blk()
  foreach (cb in (blk % "unlockable"))
    if (cb?.id == unlockId)
      return cb
  return null
}

let function getUnlocksByType(typeName) {
  cache()
  return cacheByType?[typeName].byName ?? {}
}

let function getUnlocksByTypeInBlkOrder(typeName) {
  cache()
  return cacheByType?[typeName].inOrder ?? []
}

addListenersWithoutEnv({
  SignOut = @(_) invalidateCache()
  LoginComplete = @(_) invalidateCache()
  ProfileUpdated = @(_) invalidateCache()
}, ::g_listener_priority.CONFIG_VALIDATION)

return {
  getAllUnlocks
  getAllUnlocksWithBlkOrder
  getUnlockById
  getUnlocksByType
  getUnlocksByTypeInBlkOrder
}