import "DataBlock" as DataBlock
from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler
from "%scripts/baseGuiHandlerWT.nut" import BaseGuiHandlerWT
from "%sqStdLibs/helpers/handyman.nut" import handyman
from "%scripts/sqDagui/framework/handlerType.nut" import handlerType
from "%scripts/unlocks/favoriteUnlocks.nut" import getFavoriteUnlocks, toggleUnlockFav
from "%scripts/unlocks/unlockProgressSnapshots.nut" import storeUnlockProgressSnapshot
from "%scripts/unlocks/unlocksCache.nut" import getUnlockById
from "%scripts/unlocks/unlocksState.nut" import buildConditionsConfig
from "%scripts/unlocks/unlocksViewModule.nut" import updateProgress, getSubunlockCfg, fillSimplifiedUnlockInfo
from "%globalScripts/loc_helpers.nut" import getVendorLocId, locByVendor
from "%scripts/dagui_library.nut" import *

let FavoriteUnlocksListView = class (BaseGuiHandlerWT) {
  wndType = handlerType.CUSTOM
  sceneBlkName = "%gui/unlocks/favoriteUnlocksList.blk"
  curFavoriteUnlocksBlk = null

  listContainer = null

  unlocksListIsValid = false

  function initScreen() {
    this.scene.setUserData(this)
    this.curFavoriteUnlocksBlk = DataBlock()
    this.listContainer = this.scene.findObject("favorite_unlocks_list")
    this.scene.findObject("no_favorites_txt").setValue(locByVendor("mainmenu/noFavoriteAchievements"))
    this.updateList()
  }

  function updateList() {
    if (!checkObj(this.listContainer))
      return

    if (!this.unlocksListIsValid)
      this.curFavoriteUnlocksBlk.setFrom(getFavoriteUnlocks())

    let unlocksObjCount = this.listContainer.childrenCount()
    let total = max(unlocksObjCount, this.curFavoriteUnlocksBlk.blockCount())
    if (unlocksObjCount == 0 && total > 0) {
      let view = {
        unlocks = array(total)
        removeFromFavoritesLocId = getVendorLocId("mainmenu/UnlockAchievementsRemoveFromFavorite/hint")
      }
      let blk = handyman.renderCached(("%gui/unlocks/unlockItemSimplified.tpl"), view)
      this.guiScene.appendWithBlk(this.listContainer, blk, this)
    }

    for (local i = 0; i < total; i++) {
      let unlockObj = this.getUnlockObj(i)
      fillSimplifiedUnlockInfo(this.curFavoriteUnlocksBlk.getBlock(i), unlockObj, this)
    }

    showObjById("no_favorites_txt",
      ! (this.curFavoriteUnlocksBlk.blockCount() && this.listContainer.childrenCount()), this.scene)
    this.unlocksListIsValid = true
  }

  function onEventFavoriteUnlocksChanged(_params) {
    this.unlocksListIsValid = false
    this.doWhenActiveOnce("updateList")
  }

  function onEventProfileUpdated(_params) {
    this.doWhenActiveOnce("updateList")
  }

  function onEventRegionalUnlocksChanged(_params) {
    this.unlocksListIsValid = false
    this.doWhenActiveOnce("updateList")
  }

  function onStoreSnapshot(obj) {
    let unlockCfg = buildConditionsConfig(getUnlockById(obj.unlockId))
    let subunlockCfg = getSubunlockCfg(unlockCfg.conditions)
    storeUnlockProgressSnapshot(subunlockCfg ?? unlockCfg)

    let unlockObj = this.listContainer.findObject(unlockCfg.id)
    updateProgress(subunlockCfg ?? unlockCfg, unlockObj)
  }

  function onRemoveUnlockFromFavorites(obj) {
    toggleUnlockFav(obj.unlockId)
  }

  function getUnlockObj(idx) {
    if (this.listContainer.childrenCount() > idx)
        return this.listContainer.getChild(idx)

    return this.listContainer.getChild(idx - 1).getClone(this.listContainer, this)
  }
}
register_gui_handler("FavoriteUnlocksListView", FavoriteUnlocksListView)

return freeze({ FavoriteUnlocksListView })
