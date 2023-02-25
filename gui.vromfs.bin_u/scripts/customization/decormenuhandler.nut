//checked for plus_string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this


let { getDecorButtonView } = require("%scripts/customization/decorView.nut")
let { isCollectionItem } = require("%scripts/collections/collections.nut")
let { findChild } = require("%sqDagui/daguiUtil.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")

let class DecorMenuHandler extends ::gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.CUSTOM
  sceneBlkName = "%gui/customization/decorWnd.blk"

  categoryTpl = "%gui/customization/decorCategories.tpl"

  isOpened = false

  curUnit = null
  curDecorType = null
  curSlotDecorId = null
  preSelectDecorId = null

  function updateHandlerData(decorType, unit, slotDecorId, preSelectDecoratorId) {
    this.curDecorType = decorType
    this.curUnit = unit
    this.curSlotDecorId = slotDecorId
    this.preSelectDecorId = preSelectDecoratorId
  }

  function createCategories() {
    if (!this.scene?.isValid())
      return

    let headerObj = this.scene.findObject("decals_wnd_header")
    headerObj.setValue(loc(this.curDecorType.listHeaderLocId))

    let decorType = this.curDecorType
    let decorCache = this.getDecorCache()
    let categories = this.getCategories().map(function(categoryId) {
      let groups = decorCache.catToGroupNames[categoryId]
      let hasGroups = groups.len() > 1 || groups[0] != "other"
      return {
        id = $"category_{categoryId}"
        headerText = $"#{decorType.categoryPathPrefix}{categoryId}"
        categoryId
        groupId = hasGroups ? "" : "other"
        hasGroups
      }
    })

    let data = ::handyman.renderCached(this.categoryTpl, { categories })
    let listObj = this.scene.findObject("categories_list")
    this.guiScene.replaceContentFromText(listObj, data, data.len(), this)
  }

  function updateSelectedCategory(_decorator) {
    if (!this.isOpened)
      return

    let categoryObj = this.getSelectedCategoryObj()
    if (!categoryObj?.isValid() || this.hasGroupsList(categoryObj))
      return

    let decorListObj = this.getContentObj(categoryObj)
    if (!decorListObj?.isValid())
      return

    let data = this.generateDecalCategoryContent(categoryObj.categoryId, categoryObj.groupId)
    this.guiScene.replaceContentFromText(decorListObj, data, data.len(), this)
    decorListObj.getChild(decorListObj.getValue()).selected = "yes"
  }

  function collapseOpenedCategory() {
    let listObj = this.getSelectedCategoryObj()?.getParent()
    if (!listObj?.isValid())
      return

    let prevValue = listObj.getValue()
    listObj.setValue(-1)
    this.guiScene.applyPendingChanges(false)
    if (::show_console_buttons)
      ::move_mouse_on_child(listObj, prevValue)
  }

  function selectCategory(categoryId, groupId) {
    if (categoryId == "")
      return false

    let listObj = this.scene.findObject("categories_list")
    let { childIdx, childObj } = findChild(listObj, @(c) c.categoryId == categoryId)
    if (!childObj?.isValid())
      return false

    listObj.setValue(childIdx)

    if (!this.hasGroupsList(childObj) || groupId == "")
      return true

    let groupList = this.getContentObj(childObj)
    let groupIdx = findChild(groupList, @(g) g.groupId == groupId).childIdx
    if (groupIdx == -1)
      return false

    groupList.setValue(groupIdx)
    return true
  }

  function isCurCategoryListObjHovered() {
    let listObj = this.getContentObj(this.getSelectedCategoryObj())
    return (listObj?.isValid() ?? false) && listObj.isHovered()
  }

  function getSelectedDecor() {
    let listObj = this.getOpenedDecorListObj()
    let decalObj = this.getSelectedObj(listObj)
    return this.getDecoratorByObj(decalObj, this.curDecorType)
  }

  function getDecoratorByObj(obj, decoratorType) {
    if (!obj?.isValid())
      return null

    let decorId = ::getObjIdByPrefix(obj, "decal_") ?? ""
    return ::g_decorator.getDecorator(decorId, decoratorType)
  }

  function getSavedPath() {
    return ::loadLocalByAccount(this.curDecorType.currentOpenedCategoryLocalSafePath, "").split("/")
  }

  function show(isShown) {
    this.isOpened = isShown
    this.scene.show(isShown)
    this.scene.enable(isShown)
    ::enableHangarControls(!this.scene.findObject("hangar_control_tracking").isHovered())
  }

  // private

  getCategories = @() ::g_decorator.getCachedOrderByType(this.curDecorType, this.curUnit.unitType.tag)
  getDecorCache = @() ::g_decorator.getCachedDataByType(this.curDecorType, this.curUnit.unitType.tag)
  getContentObj = @(obj) obj != null ? obj.findObject($"content_{obj.id}") : null
  hasGroupsList = @(obj) obj.type == "groupsList"

  function generateGroupsCategoryContent(categoryId) {
    let groups = this.getDecorCache().catToGroupNames[categoryId]
    let decorType = this.curDecorType
    let categories = groups.map(@(groupId) {
      id = $"group_{groupId}"
      headerText = $"#{decorType.groupPathPrefix}{groupId}"
      categoryId
      groupId
      hasGroups = false
      isGroup = true
    })
    return ::handyman.renderCached(this.categoryTpl, { categories })
  }

  function getSelectedObj(listObj) {
    if (!listObj?.isValid())
      return null

    let idx = listObj.getValue()
    if (idx == -1)
      return null

    return listObj.getChild(idx)
  }

  function fillDecalsCategoryContent(listObj) {
    if (!listObj?.isValid())
      return

    let categoryObj = this.getSelectedObj(listObj)
    if (!categoryObj?.isValid()) {
      this.savePath("")
      this.scrollDecalsCategory()
      return
    }

    let categoryId = categoryObj.categoryId
    let groupId = categoryObj.groupId
    let isGroupList = this.hasGroupsList(categoryObj)
    let data = isGroupList
      ? this.generateGroupsCategoryContent(categoryId)
      : this.generateDecalCategoryContent(categoryId, groupId)

    let contentListObj = this.getContentObj(categoryObj)
    this.guiScene.replaceContentFromText(contentListObj, data, data.len(), this)

    this.savePath(categoryId, groupId)

    if (!isGroupList) {
      let decorId = this.preSelectDecorId ?? this.curSlotDecorId
      let decor = ::g_decorator.getDecorator(decorId, this.curDecorType)
      let index = (decor && decor.category == categoryId) ? decor.catIndex : 0
      contentListObj.setValue(index)
    }
    else
      contentListObj.setValue(-1)

    this.scrollDecalsCategory()
    this.guiScene.applyPendingChanges(false)
    let idx = contentListObj.getValue()
    ::move_mouse_on_child(contentListObj, idx != -1 ? idx : 0)
  }

  function savePath(categoryId, groupId = "") {
    let localPath = this.curDecorType.currentOpenedCategoryLocalSafePath
    ::saveLocalByAccount(localPath, "/".join([categoryId, groupId], true))
  }

  function generateDecalCategoryContent(categoryId, groupId) {
    let decors = this.getDecorCache().catToGroups?[categoryId][groupId]
    if (!decors || decors.len() == 0)
      return ""

    let slotDecorId = this.curSlotDecorId
    let unit = this.curUnit
    let view = {
      isTooltipByHold = ::show_console_buttons
      buttons = decors.map(@(decorator) getDecorButtonView(decorator, unit, {
        needHighlight = decorator.id == slotDecorId
        onClick = "onDecorItemClick"
        onDblClick = "onDecorItemDoubleClick"
        onCollectionBtnClick = isCollectionItem(decorator)
          ? "onCollectionIconClick"
          : null
      }))
    }
    return ::handyman.renderCached("%gui/commonParts/imageButton.tpl", view)
  }

  function scrollDecalsCategory() {
    let categoryObj = this.getSelectedCategoryObj()
    if (!categoryObj?.isValid())
      return

    let headerObj = categoryObj.findObject($"btn_{categoryObj.id}")
    if (headerObj?.isValid())
      headerObj.scrollToView(true)

    let contentListObj = this.getContentObj(categoryObj)
    if (!contentListObj?.isValid() || contentListObj.childrenCount() == 0)
      return

    let idx = contentListObj.getValue()
    let itemObj = contentListObj.getChild(idx == -1 ? 0 : idx)
    if (itemObj?.isValid())
      itemObj.scrollToView()
  }

  function getSelectedCategoryObj() {
    let categoryObj = this.getSelectedObj(this.scene.findObject("categories_list"))
    if (!categoryObj?.isValid())
      return null

    return this.hasGroupsList(categoryObj)
      ? this.getSelectedObj(this.getContentObj(categoryObj)) ?? categoryObj
      : categoryObj
  }

  function getOpenedDecorListObj() {
    let categoryObj = this.getSelectedCategoryObj()
    if (!categoryObj?.isValid())
      return null

    return this.hasGroupsList(categoryObj) ? null : this.getContentObj(categoryObj)
  }

  function moveMouseOnDecalsHeader(listObj, valueDiff = 0) {
    let newValue = listObj.getValue() + valueDiff
    if (newValue < 0 || listObj.childrenCount() <= newValue)
      return false

    ::move_mouse_on_child(listObj.getChild(newValue), 0)
    return true
  }

  function onBtnCloseDecalsMenu() {
    this.show(false)
  }

  function onDecorCategorySelect(listObj) {
    this.fillDecalsCategoryContent(listObj)
  }

  function onDecorCategoryActivate(_listObj) {
    this.collapseOpenedCategory()
  }

  function onDecorItemClick(obj) {
    let decorator = this.getDecoratorByObj(obj, this.curDecorType)
    if (!decorator)
      return

    let listObj = obj.getParent()
    if (listObj.getValue() != decorator.catIndex)
      listObj.setValue(decorator.catIndex)

    ::broadcastEvent("DecorMenuItemClick", { decorator })
  }

  function onDecorItemDoubleClick(obj) {
    let decorator = this.getDecoratorByObj(obj, this.curDecorType)
    if (!decorator)
      return

    ::broadcastEvent("DecorMenuItemDblClick", { decorator })
  }

  function onCollectionIconClick(obj) {
    let decoratorId = obj.holderId
    ::broadcastEvent("DecorMenuCollectionIconClick", { decoratorId })
  }

  function onDecorItemSelect() {
    ::broadcastEvent("DecorMenuItemSelect")
  }

  function onDecorItemActivate(listObj) {
    this.onDecorItemClick(this.getSelectedObj(listObj))
  }

  function onDecorListHoverChange() {
    ::broadcastEvent("DecorMenuListHoverChange")
  }

  function onDecorItemHeader(listObj) {
    let parentList = listObj.getParent().getParent()
    this.moveMouseOnDecalsHeader(parentList)
  }

  function onDecorItemNextHeader(listObj) {
    let parentList = listObj.getParent().getParent()
    if (!this.moveMouseOnDecalsHeader(parentList, 1))
      ::set_dirpad_event_processed(false)
  }

  onDecorMenuHoverChange = @(obj) ::enableHangarControls(!obj.isHovered())
}

::gui_handlers.DecorMenuHandler <- DecorMenuHandler

return function(scene) {
  if (!scene?.isValid())
    return null

  return ::handlersManager.loadHandler(DecorMenuHandler, { scene })
}