let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { isUnlockFav } = require("%scripts/unlocks/favoriteUnlocks.nut")
let { get_charserver_time_sec } = require("chard")
let { isDataBlock } = require("%sqstd/underscore.nut")
let { convertBlk } = require("%sqstd/datablock.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let { isProfileReceived } = require("%scripts/login/loginStates.nut")

const SAVE_ID = "unlock_progress_snapshots"

local idToSnapshot = {}
local isInited = false

function initOnce() {
  if (isInited || !isProfileReceived.get())
    return

  isInited = true

  let blk = loadLocalAccountSettings(SAVE_ID, null)
  if (!isDataBlock(blk))
    return

  idToSnapshot = convertBlk(blk)
}

function invalidateCache() {
  idToSnapshot.clear()
  isInited = false
}

function storeUnlockProgressSnapshot(unlockCfg) {
  initOnce()
  if (!isInited)
    return

  idToSnapshot[unlockCfg.id] <- {
    timeSec = get_charserver_time_sec()
    progress = unlockCfg.curVal
  }
  saveLocalAccountSettings(SAVE_ID, idToSnapshot)
}

function getUnlockProgressSnapshot(unlockId) {
  initOnce()
  return idToSnapshot?[unlockId]
}

function onFavoriteUnlocksChanged(params) {
  let { changedId } = params
  if (changedId not in idToSnapshot)
    return

  idToSnapshot.$rawdelete(changedId)
  idToSnapshot = idToSnapshot.filter(@(_, k) isUnlockFav(k)) // validation
  saveLocalAccountSettings(SAVE_ID, idToSnapshot)
}

addListenersWithoutEnv({
  SignOut = @(_) invalidateCache()
  FavoriteUnlocksChanged = onFavoriteUnlocksChanged
})

return {
  storeUnlockProgressSnapshot
  getUnlockProgressSnapshot
}