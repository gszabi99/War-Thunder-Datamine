from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")
let { isUnlockVisibleOnCurPlatform, isUnlockVisible
} = require("%scripts/unlocks/unlocksModule.nut")
let { addListenersWithoutEnv, broadcastEvent, CONFIG_VALIDATION
} = require("%sqStdLibs/helpers/subscriptions.nut")
let { eachBlock } = require("%sqstd/datablock.nut")
let DataBlock = require("DataBlock")
let { getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let { addPopup } = require("%scripts/popups/popups.nut")
let { isProfileReceived } = require("%scripts/login/loginStates.nut")

const FAVORITE_UNLOCKS_LIST_SAVE_ID = "favorite_unlocks"
const FAVORITE_UNLOCKS_LIMIT = 20

local isFavUnlockCacheValid = false

local favoriteUnlocks = null
local favoriteInvisibleUnlocks = null

function loadFavorites() {
  if (favoriteUnlocks) {
    favoriteUnlocks.reset()
    favoriteInvisibleUnlocks.reset()
  }
  else {
    favoriteUnlocks = DataBlock()
    favoriteInvisibleUnlocks = DataBlock()
  }

  if (!isProfileReceived.get())
    return

  isFavUnlockCacheValid = true

  let ids = loadLocalAccountSettings(FAVORITE_UNLOCKS_LIST_SAVE_ID)
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

function getFavoriteUnlocks() {
  if (!isFavUnlockCacheValid || favoriteUnlocks == null)
    loadFavorites()

  return favoriteUnlocks
}

let getFavoriteUnlocksNum = @() getFavoriteUnlocks().blockCount()
  + favoriteInvisibleUnlocks.blockCount()

let canAddFavorite = @() getFavoriteUnlocksNum() < FAVORITE_UNLOCKS_LIMIT
let isUnlockFav = @(id) id in getFavoriteUnlocks()

function saveFavorites() {
  let saveBlk = DataBlock()
  saveBlk.setFrom(favoriteInvisibleUnlocks)

  eachBlock(getFavoriteUnlocks(), function(_, unlockId) {
    if (unlockId not in saveBlk)
      saveBlk[unlockId] = true
  })

  saveLocalAccountSettings(FAVORITE_UNLOCKS_LIST_SAVE_ID, saveBlk)
}

function addUnlockToFavorites(unlockId) {
  if (unlockId in getFavoriteUnlocks())
    return

  getFavoriteUnlocks().addBlock(unlockId)
  getFavoriteUnlocks()[unlockId] = getUnlockById(unlockId)
  saveFavorites()
  broadcastEvent("FavoriteUnlocksChanged", { changedId = unlockId, value = true })
}

function removeUnlockFromFavorites(unlockId) {
  if (unlockId not in getFavoriteUnlocks())
    return

  getFavoriteUnlocks().removeBlock(unlockId)
  saveFavorites()
  broadcastEvent("FavoriteUnlocksChanged", { changedId = unlockId, value = false })
}

function toggleUnlockFav(unlockId) {
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
    showInfoMsgBox(msg)
    return
  }

  addUnlockToFavorites(unlockId)
}

function fillUnlockFavCheckbox(obj) {
  let isUnlockInFavorites = isUnlockFav(obj.unlockId)
  if (obj?.isChecked != null) {
    obj.setValue(isUnlockInFavorites
      ? loc("preloaderSettings/untrackProgress")
      : loc("preloaderSettings/trackProgress")
    )
    obj.isChecked = isUnlockInFavorites ? "yes" : "no"
  } else
    obj.setValue(isUnlockInFavorites)

  obj.tooltip = isUnlockInFavorites
    ? loc("mainmenu/UnlockAchievementsRemoveFromFavorite/hint")
    : loc("mainmenu/UnlockAchievementsToFavorite/hint")
}

function fillUnlockFav(unlockId, unlockObj) {
  let checkboxFavorites = unlockObj.findObject("checkbox_favorites")
  if (! checkObj(checkboxFavorites))
    return
  checkboxFavorites.unlockId = unlockId
  fillUnlockFavCheckbox(checkboxFavorites)
}

// TODO replace with toggleUnlockFav, do not pass visual object and callback here
function unlockToFavorites(obj, updateCb = null) {
  let unlockId = obj?.unlockId
  if (u.isEmpty(unlockId))
    return

  let isButton = obj?.isChecked != null
  let isChecked = isButton ? obj?.isChecked == "yes" : obj.getValue()

  if (!canAddFavorite()
      && isChecked // Don't notify if value set to false
      && !(unlockId in getFavoriteUnlocks())) { // Don't notify if unlock wasn't in list already
    let num = FAVORITE_UNLOCKS_LIMIT
    let msg = loc("mainmenu/unlockAchievements/limitReached", { num })
    addPopup("", colorize("warningTextColor", msg))
    if (isButton) {
      obj.isChecked = "no"
      obj.setValue(loc("preloaderSettings/trackProgress"))
    } else
      obj.setValue(false)
    return
  }

  obj.tooltip = isChecked
    ? addUnlockToFavorites(unlockId)
    : removeUnlockFromFavorites(unlockId)

  fillUnlockFavCheckbox(obj)

  if (updateCb)
    updateCb()
}

let invalidateCache = @() isFavUnlockCacheValid = false

addListenersWithoutEnv({
  UnlocksCacheInvalidate = @(_) invalidateCache()
  RegionalUnlocksChanged = @(_) invalidateCache()
}, CONFIG_VALIDATION)

return {
  getFavoriteUnlocks
  getFavoriteUnlocksNum
  canAddFavorite
  isUnlockFav
  toggleUnlockFav
  FAVORITE_UNLOCKS_LIMIT
  unlockToFavorites
  fillUnlockFav
}