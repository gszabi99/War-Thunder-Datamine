class ::gui_handlers.FavoriteUnlocksListView extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM
  sceneBlkName = "gui/unlocks/favoriteUnlocksList.blk"
  curFavoriteUnlocksBlk = null

  listContainer = null

  unlocksListIsValid = false

  function initScreen()
  {
    scene.setUserData(this)
    curFavoriteUnlocksBlk = ::DataBlock()
    listContainer = scene.findObject("favorite_unlocks_list")
    updateList()
  }

  function updateList()
  {
    if (!::checkObj(listContainer))
      return

    if(!unlocksListIsValid)
      curFavoriteUnlocksBlk.setFrom(::g_unlocks.getFavoriteUnlocks())

    local unlocksObjCount = listContainer.childrenCount()
    local total = ::max(unlocksObjCount, curFavoriteUnlocksBlk.blockCount())
    if (unlocksObjCount == 0 && total > 0) {
      local blk = ::handyman.renderCached(("gui/unlocks/unlockItemSimplified"),
        { unlocks = array(total, { hasCloseButton = true, hasHiddenContent = true })})
      guiScene.appendWithBlk(listContainer, blk, this)
    }

    for(local i = 0; i < total; i++)
    {
      local unlockObj = getUnlockObj(i)
      ::g_unlock_view.fillSimplifiedUnlockInfo(curFavoriteUnlocksBlk.getBlock(i), unlockObj, this)
    }

    showSceneBtn("no_favorites_txt",
      ! (curFavoriteUnlocksBlk.blockCount() && listContainer.childrenCount()))
    unlocksListIsValid = true
  }

  function onEventFavoriteUnlocksChanged(params)
  {
    unlocksListIsValid = false
    doWhenActiveOnce("updateList")
  }

  function onEventProfileUpdated(params)
  {
    doWhenActiveOnce("updateList")
  }

  function onRemoveUnlockFromFavorites(obj)
  {
    ::g_unlocks.removeUnlockFromFavorites(obj.unlockId)
  }

  function getUnlockObj(idx)
  {
    if (listContainer.childrenCount() > idx)
        return listContainer.getChild(idx)

    return listContainer.getChild(idx-1).getClone(listContainer, this)
  }
}
