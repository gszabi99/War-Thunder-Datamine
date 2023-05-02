//checked for plus_string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let DataBlock = require("DataBlock")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { getFavoriteUnlocks, toggleUnlockFav } = require("%scripts/unlocks/favoriteUnlocks.nut")

::gui_handlers.FavoriteUnlocksListView <- class extends ::gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.CUSTOM
  sceneBlkName = "%gui/unlocks/favoriteUnlocksList.blk"
  curFavoriteUnlocksBlk = null

  listContainer = null

  unlocksListIsValid = false

  function initScreen() {
    this.scene.setUserData(this)
    this.curFavoriteUnlocksBlk = DataBlock()
    this.listContainer = this.scene.findObject("favorite_unlocks_list")
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
      let blk = ::handyman.renderCached(("%gui/unlocks/unlockItemSimplified.tpl"),
        { unlocks = array(total, { hasCloseButton = true, hasHiddenContent = true }) })
      this.guiScene.appendWithBlk(this.listContainer, blk, this)
    }

    for (local i = 0; i < total; i++) {
      let unlockObj = this.getUnlockObj(i)
      ::g_unlock_view.fillSimplifiedUnlockInfo(this.curFavoriteUnlocksBlk.getBlock(i), unlockObj, this)
    }

    this.showSceneBtn("no_favorites_txt",
      ! (this.curFavoriteUnlocksBlk.blockCount() && this.listContainer.childrenCount()))
    this.unlocksListIsValid = true
  }

  function onEventFavoriteUnlocksChanged(_params) {
    this.unlocksListIsValid = false
    this.doWhenActiveOnce("updateList")
  }

  function onEventProfileUpdated(_params) {
    this.doWhenActiveOnce("updateList")
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
