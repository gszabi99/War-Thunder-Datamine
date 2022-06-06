::gui_handlers.navigationPanel <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM
  sceneTplName = "%gui/wndWidgets/navigationPanel"
  sceneBlkName = null

  // ==== Handler params ====

  onSelectCb = null
  onClickCb  = null
  onCollapseCb = null

  // ==== Handler template params ====

  panelWidth        = null  // Panel width
  headerHeight      = null  // Panel header height
  headerOffsetX     = "0.015@sf"  // Panel header left and right offset
  headerOffsetY     = "0.015@sf"  // Panel header top and bottom offset

  collapseShortcut  = null
  needShowCollapseButton = null
  expandShortcut    = null  // default: collapseShortcut
  focusShortcut     = "LT"

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
      needShowCollapseButton = needShowCollapseButton || ::is_low_width_screen()
      expandShortcut    = expandShortcut ?? collapseShortcut
      focusShortcut     = ::show_console_buttons ? focusShortcut : null
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
    let navListObj = scene.findObject(navListObjId)
    if (!::checkObj(navListObj))
      return

    itemList = navItems
    let view = {items = itemList.map(@(navItem, idx)
      navItem.__merge({
        id = $"nav_{idx.tostring()}"
        isSelected = idx == 0
        itemText = navItem?.text ?? navItem?.id ?? ""
        isCollapsable = navItem?.isCollapsable ?? false
      })
    )}

    let data = ::handyman.renderCached("%gui/missions/missionBoxItemsList", view)
    guiScene.replaceContentFromText(navListObj, data, data.len(), this)

    updateVisibility()
  }

  function getNavItems()
  {
    return itemList
  }

  function setCurrentItem(item)
  {
    let itemIdx = itemList.indexof(item)
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
    let navListObj = scene.findObject(navListObjId)
    if (!::checkObj(navListObj))
      return false

    let itemsCount = itemList.len()
    if (itemsCount < 1)
      return

    if (isRelative)
      itemIdx += navListObj.getValue()
    itemIdx = clamp(itemIdx, 0, itemsCount - 1)

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
    let isNavRequired = itemList.len() > 1
    this.showSceneBtn(panelObjId, isNavRequired && isPanelVisible)
    this.showSceneBtn(expandButtonObjId, isNavRequired && !isPanelVisible)
    guiScene.performDelayed(this, function() {
      if (isValid())
        updateMoveToPanelButton()
    })
  }

  function onNavClick(obj = null)
  {
    let navListObj = scene.findObject(navListObjId)
    if (!::checkObj(navListObj))
      return false

    let itemIdx = navListObj.getValue()
    if (shouldCallCallback && onClickCb && itemIdx in itemList)
      onClickCb(itemList[itemIdx])
  }

  function onNavSelect(obj = null)
  {
    let navListObj = scene.findObject(navListObjId)
    if (!::checkObj(navListObj))
      return false

    notifyNavChanged(navListObj.getValue())
  }

  function onExpand(obj = null)
  {
    showPanel(true)
    if (shouldCallCallback && onCollapseCb)
      onCollapseCb(false)
  }

  function onNavCollapse(obj = null)
  {
    showPanel(false)
    if (shouldCallCallback && onCollapseCb)
      onCollapseCb(true)
  }

  function onCollapse(obj)
  {
    let itemObj = obj?.collapse_header ? obj : obj.getParent()
    let listObj = ::check_obj(itemObj) ? itemObj.getParent() : null
    if (!::check_obj(listObj) || !itemObj?.collapse_header)
      return

    itemObj.collapsing = "yes"
    let isShow = itemObj?.collapsed == "yes"
    let listLen = listObj.childrenCount()
    local selIdx = listObj.getValue()
    local headerIdx = -1
    local needReselect = false

    local found = false
    for (local i = 0; i < listLen; i++)
    {
      let child = listObj.getChild(i)
      if (!found)
      {
        if (child?.collapsing == "yes")
        {
          child.collapsing = "no"
          child.collapsed  = isShow ? "no" : "yes"
          headerIdx = i
          found = true
        }
      }
      else
      {
        if (child?.collapse_header)
          break
        child.show(isShow)
        child.enable(isShow)
        if (!isShow && i == selIdx)
          needReselect = true
      }
    }

    if (needReselect)
    {
      let indexes = []
      for (local i = selIdx + 1; i < listLen; i++)
        indexes.append(i)
      for (local i = selIdx - 1; i >= 0; i--)
        indexes.append(i)

      local newIdx = -1
      foreach (idx in indexes)
      {
        let child = listObj.getChild(idx)
        if (!child?.collapse_header != "yes"  && child.isEnabled())
        {
          newIdx = idx
          break
        }
      }
      selIdx = newIdx != -1 ? newIdx : headerIdx
      listObj.setValue(selIdx)
    }
  }

  onFocusNavigationList = @() ::move_mouse_on_child_by_value(scene.findObject(navListObjId))
  function updateMoveToPanelButton() {
    if (isValid())
      this.showSceneBtn("moveToLeftPanel", ::show_console_buttons && !scene.findObject(navListObjId).isHovered())
  }

  function getCurrentItem() {
    let currentIdx = ::get_object_value(scene, navListObjId)
    if (currentIdx == null)
      return null

    return itemList?[currentIdx]
  }
}
