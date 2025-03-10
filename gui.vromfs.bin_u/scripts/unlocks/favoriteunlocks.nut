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
let { isProfileReceived } = require("%appGlobals/login/loginState.nut")

const FAVORITE_UNLOCKS_LIST_SAVE_ID = "favorite_unlocks"
const CHECKBOX_BTN_ID = "checkbox_favorites"
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
        favoriteInvisibleUnlocks[unlockId] = true 
      else {
        favoriteUnlocks.addBlock(unlockId) 
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

function tryAddAddToFav(unlockId) {
  if (!canAddFavorite()) {
    let num = FAVORITE_UNLOCKS_LIMIT
    let msg = loc("mainmenu/unlockAchievements/limitReached", { num })
    addPopup("", colorize("warningTextColor", msg))
    return false
  }
  addUnlockToFavorites(unlockId)
  return true
}

function toggleUnlockFav(unlockId) {
  if (!unlockId)
    return false

  let isFav = isUnlockFav(unlockId)
  if (isFav) {
    removeUnlockFromFavorites(unlockId)
    return false
  }

  return tryAddAddToFav(unlockId)
}

function updateUnlockFavObj(obj) {
  let isUnlockInFavorites = isUnlockFav(obj.unlockId)
  if (obj?.isChecked != null) {
    obj.setValue(isUnlockInFavorites
      ? loc("preloaderSettings/untrackProgress")
      : loc("preloaderSettings/trackProgress")
    )
    obj.isChecked = isUnlockInFavorites ? "yes" : "no"
  } else {
    if (obj?.on_change_value != null) {
      obj.setValue(isUnlockInFavorites)
      return
    }
    obj.setValue(isUnlockInFavorites)
  }

  obj.tooltip = isUnlockInFavorites
    ? loc("mainmenu/UnlockAchievementsRemoveFromFavorite/hint")
    : loc("mainmenu/UnlockAchievementsToFavorite/hint")

  this.guiScene.updateTooltip(obj)
}

function initUnlockFavObj(unlockId, unlockObj) {
  if (!unlockObj.isValid())
    return
  unlockObj.unlockId = unlockId
  updateUnlockFavObj(unlockObj)
}

function initUnlockFavInContainer(unlockId, container, favBtnId = CHECKBOX_BTN_ID) {
  let unlockObj = container.findObject(favBtnId)
  initUnlockFavObj(unlockId, unlockObj)
}

function toggleUnlockFavCheckBox(obj) {
  let unlockId = obj?.unlockId
  if (u.isEmpty(unlockId))
    return false

  let isFav = isUnlockFav(unlockId)
  if (obj.getValue() != isFav) {
    let isToggeled = toggleUnlockFav(unlockId) != isFav
    if (isToggeled)
      updateUnlockFavObj(obj)
    return isToggeled
  }
}

function toggleUnlockFavButton(obj) {
  if (obj?.on_change_value != null || obj?.isChecked == null) {
    logerr("use toggleUnlockFavCheckBox() for checkboxes")
    return false
  }

  let unlockId = obj?.unlockId
  if (u.isEmpty(unlockId))
    return false

  let isFav = isUnlockFav(unlockId)
  let isToggeled = toggleUnlockFav(unlockId) != isFav
  if (isToggeled)
    updateUnlockFavObj(obj)
  return isToggeled
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
  initUnlockFavObj
  initUnlockFavInContainer
  toggleUnlockFavButton
  toggleUnlockFavCheckBox
}