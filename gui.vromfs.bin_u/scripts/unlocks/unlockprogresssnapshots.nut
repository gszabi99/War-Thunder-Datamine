let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { isUnlockFav } = require("%scripts/unlocks/favoriteUnlocks.nut")
let { get_charserver_time_sec } = require("chard")

const SAVE_ID = "unlock_progress_snapshots"

local idToSnapshot = {}
local isInited = false

let function initOnce() {
  if (isInited || !::g_login.isProfileReceived())
    return

  isInited = true

  let blk = ::load_local_account_settings(SAVE_ID, null)
  if (!blk)
    return

  idToSnapshot = ::buildTableFromBlk(blk)
}

let function invalidateCache() {
  idToSnapshot.clear()
  isInited = false
}

let function storeUnlockProgressSnapshot(unlockCfg) {
  initOnce()
  if (!isInited)
    return

  idToSnapshot[unlockCfg.id] <- {
    timeSec = get_charserver_time_sec()
    progress = unlockCfg.curVal
  }
  ::save_local_account_settings(SAVE_ID, idToSnapshot)
}

let function getUnlockProgressSnapshot(unlockId) {
  initOnce()
  return idToSnapshot?[unlockId]
}

let function onFavoriteUnlocksChanged(params) {
  let { changedId } = params
  if (changedId not in idToSnapshot)
    return

  delete idToSnapshot[changedId]
  idToSnapshot = idToSnapshot.filter(@(_, k) isUnlockFav(k)) // validation
  ::save_local_account_settings(SAVE_ID, idToSnapshot)
}

addListenersWithoutEnv({
  SignOut = @(_) invalidateCache()
  FavoriteUnlocksChanged = onFavoriteUnlocksChanged
})

return {
  storeUnlockProgressSnapshot
  getUnlockProgressSnapshot
}