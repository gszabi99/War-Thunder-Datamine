class ::gui_handlers.navigationPanel extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM
  sceneTplName = "gui/wndWidgets/navigationPanel"
  sceneBlkName = null

  // ==== Handler params ====

  onSelectCb = null

  // ==== Handler template params ====

  panelWidth        = null  // Panel width
  headerHeight      = null  // Panel header height
  headerOffsetX     = "0.015@sf"  // Panel header left and right offset
  headerOffsetY     = "0.015@sf"  // Panel header top and bottom offset

  collapseShortcut  = "R3"
  expandShortcut    = null  // default: collapseShortcut
  navShortcutGroup  = "RS"  // "RS", "LS" or "DPad"
  prevShortcut      = null  // default: navShortcutGroup + "Up"
  nextShortcut      = null  // default: navShortcutGroup + "Down"

  // ==== Privates ====

  itemList = null

  shouldCallCallback = true
  isPanelVisible = true

  static panelObjId = "panel"
  static panelHeaderObjId = "panel_header"
  static collapseButtonObjId = "collapse_button"
  static expandButtonObjId = "expand_button"
  static navListObjId = "nav_list"


  // ==== Functions ====

  function getSceneTplView()
  {
    return {
      panelWidth        = panelWidth
      headerHeight      = headerHeight
      headerOffsetX     = headerOffsetX
      headerOffsetY     = headerOffsetY
      collapseShortcut  = collapseShortcut
      needShowCollapseButton = ::is_low_width_screen()
      expandShortcut    = expandShortcut || collapseShortcut
      navShortcutGroup  = navShortcutGroup
      prevShortcut      = prevShortcut || navShortcutGroup + "Up"
      nextShortcut      = nextShortcut || navShortcutGroup + "Down"
    }
  }

  function initScreen()
  {
    setNavItems(itemList || [])
  }

  function showPanel(isVisible)
  {
    isPanelVisible = isVisible
    updateVisibility()
  }

  function setNavItems(navItems)
  {
    local navListObj = scene.findObject(navListObjId)
    if (!::checkObj(navListObj))
      return

    itemList = navItems
    local view = {items = []}
    foreach (idx, navItem in itemList)
    {
      view.items.append({
        id = "nav_" + idx.tostring()
        isSelected = idx == 0
        itemText = ::getTblValue("text", navItem, ::getTblValue("id", navItem, ""))
      })
    }

    local data = ::handyman.renderCached("gui/missions/missionBoxItemsList", view)
    guiScene.replaceContentFromText(navListObj, data, data.len(), this)

    updateVisibility()
  }

  function getNavItems()
  {
    return itemList
  }

  function setCurrentItem(item)
  {
    local itemIdx = itemList.indexof(item)
    if (itemIdx != null)
      setCurrentItemIdx(itemIdx)
  }

  function setCurrentItemIdx(itemIdx)
  {
    shouldCallCallback = false
    doNavigate(itemIdx)
    shouldCallCallback = true
  }

  function doNavigate(itemIdx, isRelative = false)
  {
    local navListObj = scene.findObject(navListObjId)
    if (!::checkObj(navListObj))
      return false

    local itemsCount = itemList.len()
    if (itemsCount < 1)
      return

    if (isRelative)
      itemIdx += navListObj.getValue()
    itemIdx = ::clamp(itemIdx, 0, itemsCount - 1)

    if (itemIdx == navListObj.getValue())
      return

    navListObj.setValue(itemIdx)
    notifyNavChanged(itemIdx)
  }

  function notifyNavChanged(itemIdx)
  {
    if (shouldCallCallback && onSelectCb && itemIdx in itemList)
      onSelectCb(itemList[itemIdx])
  }

  function updateVisibility()
  {
    local isNavRequired = itemList.len() > 1
    showSceneBtn(panelObjId, isNavRequired && isPanelVisible)
    showSceneBtn(expandButtonObjId, isNavRequired && !isPanelVisible)
  }

  function onNavPrev(obj = null)
  {
    doNavigate(-1, true)
  }

  function onNavNext(obj = null)
  {
    doNavigate(1, true)
  }

  function onNavClick(obj = null)
  {
    local navListObj = scene.findObject(navListObjId)
    if (!::checkObj(navListObj))
      return false

    notifyNavChanged(navListObj.getValue())
  }

  function onExpand(obj = null)
  {
    showPanel(true)
  }

  function onCollapse(obj = null)
  {
    showPanel(false)
  }
}
