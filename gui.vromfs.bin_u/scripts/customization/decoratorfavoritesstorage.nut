from "%scripts/dagui_library.nut" import *

let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let { broadcastEvent, addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { convertBlk } = require("%sqstd/datablock.nut")
let { isArray } = require("%sqStdLibs/helpers/u.nut")
let g_listener_priority = require("%scripts/g_listener_priority.nut")

const FAVORITE_DECORATORS_SAVE_ID = "favoritesDecorators"
const FAVORITE_CATEGORY_ID = "favorites"
let favoritesCache = {}

function getSavedDecorId(decorTypeName) {
  return $"{FAVORITE_DECORATORS_SAVE_ID}/{decorTypeName}"
}

function getFavoriteDecorators(decorTypeName) {
  if (favoritesCache?[decorTypeName] == null) {
    let loadedBlk = loadLocalAccountSettings(getSavedDecorId(decorTypeName))
    let favorites = loadedBlk
      ? convertBlk(loadedBlk)?.array ?? []
      : []
    favoritesCache[decorTypeName] <- isArray(favorites) ? favorites : [favorites]
  }
  return favoritesCache[decorTypeName]
}

function saveFavoriteDecorators(decorTypeName) {
  saveLocalAccountSettings(getSavedDecorId(decorTypeName), favoritesCache[decorTypeName])
  broadcastEvent("UpdateFavoriteDecorators", {[decorTypeName] = true})
}

function isDecorInFavorites(decorId, decorTypeName) {
  let fav = getFavoriteDecorators(decorTypeName)
  return fav.indexof(decorId) != null
}

function addDecorToFavorite(decorId, decorTypeName) {
  let fav = getFavoriteDecorators(decorTypeName)
  if (isDecorInFavorites(decorId, decorTypeName)) {
    logerr($"addDecorToFavorite decor {decorId} exists in favorites {decorTypeName}")
    return
  }
  fav.append(decorId)
  saveFavoriteDecorators(decorTypeName)
}

function removeDecorFromFavorite(decorId, decorTypeName) {
  let fav = getFavoriteDecorators(decorTypeName)
  if (!isDecorInFavorites(decorId, decorTypeName)) {
    logerr($"removeDecorFromFavorite decor {decorId} not exists in favorites {decorTypeName}")
    return
  }
  fav.remove(fav.indexof(decorId))
  saveFavoriteDecorators(decorTypeName)
}

addListenersWithoutEnv({
  SignOut = @(_) favoritesCache.clear()
} g_listener_priority.CONFIG_VALIDATION)

return {
  isDecorInFavorites
  addDecorToFavorite
  removeDecorFromFavorite
  getFavoriteDecorators
  FAVORITE_CATEGORY_ID
}