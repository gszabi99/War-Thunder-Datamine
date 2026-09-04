from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv
from "%appGlobals/login/loginState.nut" import isProfileReceived
from "chard" import get_charserver_time_sec
from "%sqstd/underscore.nut" import isDataBlock
from "%sqstd/datablock.nut" import convertBlk

let { isUnlockFav } = require("%scripts/unlocks/favoriteUnlocks.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings } = require("%scripts/clientState/localProfile.nut")

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
  idToSnapshot = idToSnapshot.filter(@(_, k) isUnlockFav(k)) 
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