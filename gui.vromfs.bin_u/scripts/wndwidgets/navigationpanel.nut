from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { move_mouse_on_child_by_value, getObjValue } = require("%sqDagui/daguiUtil.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { is_low_width_screen } = require("%scripts/options/safeAreaMenu.nut")

gui_handlers.navigationPanel <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.CUSTOM
  sceneTplName = "%gui/wndWidgets/navigationPanel.tpl"
  sceneBlkName = null

  

  onSelectCb = null
  onClickCb  = null
  onCollapseCb = null

  

  panelWidth        = null  
  headerHeight      = null  
  headerOffsetX     = "0.015@sf"  
  headerOffsetY     = "0.015@sf"  

  collapseShortcut  = null
  needShowCollapseButton = null
  expandShortcut    = null  
  focusShortcut     = "LT"

  

  itemList = null

  shouldCallCallback = true
  isPanelVisible = true

  static panelObjId = "panel"
  static panelHeaderObjId = "panel_header"
  static collapseButtonObjId = "collapse_button"
  static expandButtonObjId = "expand_button"
  static navListObjId = "nav_list"


  

  function getSceneTplView() {
    return {
      panelWidth        = this.panelWidth
      headerHeight      = this.headerHeight
      headerOffsetX     = this.headerOffsetX
      headerOffsetY     = this.headerOffsetY
      collapseShortcut  = this.collapseShortcut
      needShowCollapseButton = this.needShowCollapseButton || is_low_width_screen()
      expandShortcut    = this.expandShortcut ?? this.collapseShortcut
      focusShortcut     = showConsoleButtons.value ? this.focusShortcut : null
    }
  }

  function initScreen() {
    this.setNavItems(this.itemList || [])
  }

  function showPanel(isVisible) {
    this.isPanelVisible = isVisible
    this.updateVisibility()
  }

  function setNavItems(navItems) {
    let navListObj = this.scene.findObject(this.navListObjId)
    if (!checkObj(navListObj))
      return

    this.itemList = navItems
    let view = { items = this.itemList.map(@(navItem, idx)
      navItem.__merge({
        id = $"nav_{idx.tostring()}"
        isSelected = idx == 0
        itemText = navItem?.text ?? navItem?.id ?? ""
        isCollapsable = navItem?.isCollapsable ?? false
      })
    ) }

    let data = handyman.renderCached("%gui/missions/missionBoxItemsList.tpl", view)
    this.guiScene.replaceContentFromText(navListObj, data, data.len(), this)

    this.updateVisibility()
  }

  function getNavItems() {
    return this.itemList
  }

  function setCurrentItem(item) {
    let itemIdx = this.itemList.indexof(item)
    if (itemIdx != null)
      this.setCurrentItemIdx(itemIdx)
  }

  function setCurrentItemIdx(itemIdx) {
    this.shouldCallCallback = false
    this.doNavigate(itemIdx)
    this.shouldCallCallback = true
  }

  function doNavigate(itemIdx, isRelative = false) {
    let navListObj = this.scene.findObject(this.navListObjId)
    if (!checkObj(navListObj))
      return false

    let itemsCount = this.itemList.len()
    if (itemsCount < 1)
      return

    if (isRelative)
      itemIdx += navListObj.getValue()
    itemIdx = clamp(itemIdx, 0, itemsCount - 1)

    if (itemIdx == navListObj.getValue())
      return

    navListObj.setValue(itemIdx)
    this.notifyNavChanged(itemIdx)
  }

  function notifyNavChanged(itemIdx) {
    if (this.shouldCallCallback && this.onSelectCb && itemIdx in this.itemList)
      this.onSelectCb(this.itemList[itemIdx])
  }

  function updateVisibility() {
    let isNavRequired = this.itemList.len() > 1
    showObjById(this.panelObjId, isNavRequired && this.isPanelVisible, this.scene)
    showObjById(this.expandButtonObjId, isNavRequired && !this.isPanelVisible, this.scene)
    this.guiScene.performDelayed(this, function() {
      if (this.isValid())
        this.updateMoveToPanelButton()
    })
  }

  function onNavClick(_obj = null) {
    let navListObj = this.scene.findObject(this.navListObjId)
    if (!checkObj(navListObj))
      return false

    let itemIdx = navListObj.getValue()
    if (this.shouldCallCallback && this.onClickCb && itemIdx in this.itemList)
      this.onClickCb(this.itemList[itemIdx])
  }

  function onNavSelect(_obj = null) {
    let navListObj = this.scene.findObject(this.navListObjId)
    if (!checkObj(navListObj))
      return false

    this.notifyNavChanged(navListObj.getValue())
  }

  function onExpand(_obj = null) {
    this.showPanel(true)
    if (this.shouldCallCallback && this.onCollapseCb)
      this.onCollapseCb(false)
  }

  function onNavCollapse(_obj = null) {
    this.showPanel(false)
    if (this.shouldCallCallback && this.onCollapseCb)
      this.onCollapseCb(true)
  }

  function onCollapse(obj) {
    let itemObj = obj?.collapse_header ? obj : obj.getParent()
    let listObj = checkObj(itemObj) ? itemObj.getParent() : null
    if (!checkObj(listObj) || !itemObj?.collapse_header)
      return

    itemObj.collapsing = "yes"
    let isShow = itemObj?.collapsed == "yes"
    let listLen = listObj.childrenCount()
    local selIdx = listObj.getValue()
    local headerIdx = -1
    local needReselect = false

    local found = false
    for (local i = 0; i < listLen; i++) {
      let child = listObj.getChild(i)
      if (!found) {
        if (child?.collapsing == "yes") {
          child.collapsing = "no"
          child.collapsed  = isShow ? "no" : "yes"
          headerIdx = i
          found = true
        }
      }
      else {
        if (child?.collapse_header)
          break
        child.show(isShow)
        child.enable(isShow)
        if (!isShow && i == selIdx)
          needReselect = true
      }
    }

    if (needReselect) {
      let indexes = []
      for (local i = selIdx + 1; i < listLen; i++)
        indexes.append(i)
      for (local i = selIdx - 1; i >= 0; i--)
        indexes.append(i)

      local newIdx = -1
      foreach (idx in indexes) {
        let child = listObj.getChild(idx)
        if (!child?.collapse_header != "yes"  && child.isEnabled()) {
          newIdx = idx
          break
        }
      }
      selIdx = newIdx != -1 ? newIdx : headerIdx
      listObj.setValue(selIdx)
    }
  }

  onFocusNavigationList = @() move_mouse_on_child_by_value(this.scene.findObject(this.navListObjId))
  function updateMoveToPanelButton() {
    if (this.isValid())
      showObjById("moveToLeftPanel", showConsoleButtons.value && !this.scene.findObject(this.navListObjId).isHovered(), this.scene)
  }

  function getCurrentItem() {
    let currentIdx = getObjValue(this.scene, this.navListObjId)
    if (currentIdx == null)
      return null

    return this.itemList?[currentIdx]
  }
}
