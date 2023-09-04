//checked for plus_string
from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")

let { isUnlockVisibleOnCurPlatform, isUnlockVisible } = require("%scripts/unlocks/unlocksModule.nut")
let { addListenersWithoutEnv, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { eachBlock } = require("%sqstd/datablock.nut")
let DataBlock = require("DataBlock")
let { getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")

const FAVORITE_UNLOCKS_LIST_SAVE_ID = "favorite_unlocks"
const FAVORITE_UNLOCKS_LIMIT = 20

local isFavUnlockCacheValid = false

local favoriteUnlocks = null
local favoriteInvisibleUnlocks = null

let function loadFavorites() {
  if (favoriteUnlocks) {
    favoriteUnlocks.reset()
    favoriteInvisibleUnlocks.reset()
  }
  else {
    favoriteUnlocks = DataBlock()
    favoriteInvisibleUnlocks = DataBlock()
  }

  if (!::g_login.isProfileReceived())
    return

  isFavUnlockCacheValid = true

  let ids = ::load_local_account_settings(FAVORITE_UNLOCKS_LIST_SAVE_ID)
  if (!ids)
    return

  for (local i = 0; i < ids.paramCount(); ++i) {
    let unlockId = ids.getParamName(i)
    let unlock = getUnlockById(unlockId)
    if (isUnlockVisible(unlock, false)) {
      if (!isUnlockVisibleOnCurPlatform(unlock))
        favoriteInvisibleUnlocks[unlockId] = true // unlock isn't avaliable on current platform
      else {
        favoriteUnlocks.addBlock(unlockId) // valid unlock
        favoriteUnlocks[unlockId] = unlock
      }
    }

    if (favoriteUnlocks.blockCount() >= FAVORITE_UNLOCKS_LIMIT)
      break
  }
}

let function getFavoriteUnlocks() {
  if (!isFavUnlockCacheValid || favoriteUnlocks == null)
    loadFavorites()

  return favoriteUnlocks
}

let getFavoriteUnlocksNum = @() getFavoriteUnlocks().blockCount()
  + favoriteInvisibleUnlocks.blockCount()

let canAddFavorite = @() getFavoriteUnlocksNum() < FAVORITE_UNLOCKS_LIMIT
let isUnlockFav = @(id) id in getFavoriteUnlocks()

let function saveFavorites() {
  let saveBlk = DataBlock()
  saveBlk.setFrom(favoriteInvisibleUnlocks)

  eachBlock(getFavoriteUnlocks(), function(_, unlockId) {
    if (unlockId not in saveBlk)
      saveBlk[unlockId] = true
  })

  ::save_local_account_settings(FAVORITE_UNLOCKS_LIST_SAVE_ID, saveBlk)
}

let function addUnlockToFavorites(unlockId) {
  if (unlockId in getFavoriteUnlocks())
    return

  getFavoriteUnlocks().addBlock(unlockId)
  getFavoriteUnlocks()[unlockId] = getUnlockById(unlockId)
  saveFavorites()
  broadcastEvent("FavoriteUnlocksChanged", { changedId = unlockId, value = true })
}

let function removeUnlockFromFavorites(unlockId) {
  if (unlockId not in getFavoriteUnlocks())
    return

  getFavoriteUnlocks().removeBlock(unlockId)
  saveFavorites()
  broadcastEvent("FavoriteUnlocksChanged", { changedId = unlockId, value = false })
}

let function toggleUnlockFav(unlockId) {
  if (!unlockId)
    return

  let isFav = isUnlockFav(unlockId)
  if (isFav) {
    removeUnlockFromFavorites(unlockId)
    return
  }

  if (!canAddFavorite()) {
    let num = FAVORITE_UNLOCKS_LIMIT
    let msg = loc("mainmenu/unlockAchievements/limitReached", { num })
    ::showInfoMsgBox(msg)
    return
  }

  addUnlockToFavorites(unlockId)
}

// TODO replace with toggleUnlockFav, do not pass visual object and callback here
let function unlockToFavorites(obj, updateCb = null) {
  let unlockId = obj?.unlockId
  if (u.isEmpty(unlockId))
    return

  if (!canAddFavorite()
      && obj.getValue() // Don't notify if value set to false
      && !(unlockId in getFavoriteUnlocks())) { // Don't notify if unlock wasn't in list already
    let num = FAVORITE_UNLOCKS_LIMIT
    let msg = loc("mainmenu/unlockAchievements/limitReached", { num })
    ::g_popups.add("", colorize("warningTextColor", msg))
    obj.setValue(false)
    return
  }

  obj.tooltip = obj.getValue()
    ? addUnlockToFavorites(unlockId)
    : removeUnlockFromFavorites(unlockId)

  ::g_unlock_view.fillUnlockFavCheckbox(obj)

  if (updateCb)
    updateCb()
}

let invalidateCache = @() isFavUnlockCacheValid = false

addListenersWithoutEnv({
  SignOut = @(_) invalidateCache()
  LoginComplete = @(_) invalidateCache()
  ProfileUpdated = @(_) invalidateCache()
})

return {
  getFavoriteUnlocks
  getFavoriteUnlocksNum
  canAddFavorite
  isUnlockFav
  toggleUnlockFav
  FAVORITE_UNLOCKS_LIMIT
  unlockToFavorites
}