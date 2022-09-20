let class UnlockGroupWnd extends ::gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/emptyFrame.blk"
  unlocksLists = null
  currentTab = 0

  function initScreen() {
    if (!checkUnlocksLists(unlocksLists))
      return goBack()

    let fObj = scene.findObject("wnd_frame")
    fObj["max-height"] = "1@maxWindowHeight"
    fObj["max-width"] = "1@maxWindowWidth"
    fObj["class"] = "wnd"
    let blocksCount = (getMaximumListlength(unlocksLists) > 3) ? 2 : 1
    fObj.width="fw"

    let listObj = scene.findObject("wnd_content")
    listObj.width = $"{blocksCount}(@unlockBlockWidth + @framePadding) + @scrollBarSize"
    listObj["overflow-y"] = "auto"
    listObj.flow = "h-flow"
    listObj.scrollbarShortcuts = "yes"

    fillHeader()
    fillPage()
  }

  function reinitScreen(params = {}) {
    setParams(params)
    initScreen()
  }

  /**
   * Create tabs for several unlock lists or
   * jast fill header for one list
   */
  function fillHeader() {
    if (unlocksLists.len() > 1) {
      let view = { tabs = [] }
      foreach(i, list in unlocksLists)
        view.tabs.append({
          tabName = ::getTblValue("titleText", list, "")
          navImagesText = ::get_navigation_images_text(i, unlocksLists.len())
        })

      let markup = ::handyman.renderCached("%gui/frameHeaderTabs", view)
      let tabsObj = scene.findObject("tabs_list")
      tabsObj.show(true)
      tabsObj.enable(true)
      guiScene.replaceContentFromText(tabsObj, markup, markup.len(), this)
      tabsObj.setValue(0)
    }
    else {
      let titleText = ::getTblValue("titleText", unlocksLists[0], "")
      let titleObj = scene.findObject("wnd_title")
      titleObj.show(true)
      titleObj.setValue(titleText)
    }
  }

  /**
   * Goes throug lists and returns true
   * if lists are valid, otherwise returns false.
   */
  function checkUnlocksLists(lists) {
    if (!unlocksLists || !unlocksLists.len())
      return false

    foreach (unlockListData in lists) {
      if (!("unlocksList" in unlockListData))
        continue

      if (unlockListData.unlocksList.len())
        return true
    }
    return false
  }

  function getMaximumListlength(lists) {
    local result = 0
    foreach (list in lists) {
      let len = ::getTblValue("unlocksList", list, []).len()
      result = (result < len) ? len : result
    }
    return result
  }

  function addUnlock(idx, unlock, listObj) {
    let objId = "unlock_" + idx
    let obj = guiScene.createElementByObject(listObj, "%gui/unlocks/unlockBlock.blk", "frameBlock_dark", this)
    obj.id = objId
    obj.width = "1@unlockBlockWidth"
    obj["margin-bottom"] = "1@framePadding"
    obj["margin-right"] = "1@framePadding"

    ::fill_unlock_block(obj, unlock)
  }

  function onAwardTooltipOpen(obj) {
    let id = getTooltipObjId(obj)
    if (!id)
      return

    let unlock = getUnlock(id.tointeger())
    ::build_unlock_tooltip_by_config(obj, unlock , this)
  }

  function onHeaderTabSelect(obj) {
    currentTab = obj.getValue()
    fillPage()
  }

  function fillPage() {
    let unlocksList = unlocksLists[currentTab].unlocksList
    let listObj = scene.findObject("wnd_content")

    guiScene.setUpdatesEnabled(false, false)
    guiScene.replaceContentFromText(listObj, "", 0, this)
    for(local i = 0; i < unlocksList.len(); i++)
      addUnlock(i, unlocksList[i], listObj)
    guiScene.setUpdatesEnabled(true, true)
    ::move_mouse_on_child_by_value(listObj)
  }

  function getUnlock(id) {
    return ::getTblValue(idx, unlocksLists[currentTab])
  }
}

::gui_handlers.UnlockGroupWnd <- UnlockGroupWnd

let function showUnlocksGroupWnd(unlocksLists) {
  ::gui_start_modal_wnd(UnlockGroupWnd, { unlocksLists })
}

return showUnlocksGroupWnd