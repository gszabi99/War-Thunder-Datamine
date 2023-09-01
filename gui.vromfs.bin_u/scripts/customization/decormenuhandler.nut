//checked for plus_string
from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { getDecorButtonView } = require("%scripts/customization/decorView.nut")
let { isCollectionItem } = require("%scripts/collections/collections.nut")
let { findChild } = require("%sqDagui/daguiUtil.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getCachedDataByType, getDecorator, getCachedOrderByType
} = require("%scripts/customization/decorCache.nut")
let { utf8ToLower } = require("%sqstd/string.nut")
let { setTimeout, clearTimer } = require("dagor.workcycle")
let bhvUnseen = require("%scripts/seen/bhvUnseen.nut")
let seenList = require("%scripts/seen/seenList.nut")
let { needMarkSeenResource, disableMarkSeenResource } = require("%scripts/seen/markSeenResources.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")

let class DecorMenuHandler extends gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.CUSTOM
  sceneBlkName = "%gui/customization/decorWnd.blk"

  categoryTpl = "%gui/customization/decorCategories.tpl"

  isOpened = false

  curUnit = null
  curDecorType = null
  curSlotDecorId = null
  preSelectDecorId = null
  applyFilterTimer = null

  decoratorsCache = {}
  decorsToMarkSeen = []

  currentSeenListId = ""
  currentSeenList = null

  function updateHandlerData(decorType, unit, slotDecorId, preSelectDecoratorId) {
    this.curDecorType = decorType
    this.curUnit = unit
    this.curSlotDecorId = slotDecorId
    this.preSelectDecorId = preSelectDecoratorId
    this.currentSeenListId = this.curDecorType.name == "DECALS" ? SEEN.DECALS : SEEN.DECORATORS
    this.currentSeenList = seenList.get(this.currentSeenListId)
  }

  function prepareDecoratorsCache(decorCache) {
    let needMarkSeen = needMarkSeenResource(this.currentSeenListId)
    this.decoratorsCache.clear()
    let categories = this.getCategories()
    foreach(categoryId in categories) {
      let groups = decorCache.catToGroupNames[categoryId]
      let hasGroups = groups.len() > 1 || groups[0] != "other"
      local listSummaryId = ""
      if(hasGroups) {
        listSummaryId = $"{categoryId}.summary"
        this.decoratorsCache[listSummaryId] <- []
      }
      foreach(groupId in groups) {
        let listId = $"{categoryId}.{groupId}"
        let decors = decorCache.catToGroups?[categoryId][groupId] ?? []
        let unit = this.curUnit
        let decorsListId = decors.filter(@(dec) dec.canUse(unit)).map(@(dec) dec.id)
        this.decoratorsCache[listId] <- decorsListId
        if(hasGroups)
          this.decoratorsCache[listSummaryId].extend(decorsListId)
        if(needMarkSeen)
          this.currentSeenList.markSeen(decorsListId)
      }
    }
    disableMarkSeenResource(this.currentSeenListId)
  }

  function createCategories() {
    if (!this.scene?.isValid())
      return
    let headerObj = this.scene.findObject("decals_wnd_header")
    headerObj.setValue(loc(this.curDecorType.listHeaderLocId))

    let decorType = this.curDecorType
    let decorCache = this.getDecorCache()
    this.prepareDecoratorsCache(decorCache)

    let categories = []
    foreach(categoryId in this.getCategories()) {
      let groups = decorCache.catToGroupNames[categoryId]
      let hasGroups = groups.len() > 1 || groups[0] != "other"
      let groupId = hasGroups ? "summary" : "other"

      let subListId = $"{categoryId}.{groupId}"
      this.currentSeenList.setSubListGetter(subListId, Callback(@() this.decoratorsCache.filter(@(_val, key) key == subListId).values()?[0] ?? [], this))
      categories.append({
        id = $"category_{categoryId}"
        headerText = $"#{decorType.categoryPathPrefix}{categoryId}"
        categoryId
        groupId
        hasGroups
        unseenIcon = bhvUnseen.makeConfigStr(this.currentSeenListId, subListId)
      })
    }

    let data = handyman.renderCached(this.categoryTpl, { categories })
    let listObj = this.scene.findObject("categories_list")
    this.guiScene.replaceContentFromText(listObj, data, data.len(), this)
    this.switchPanels("categories")
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
    if (showConsoleButtons.value)
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
    return getDecorator(decorId, decoratorType)
  }

  function getSavedPath() {
    return ::loadLocalByAccount(this.curDecorType.currentOpenedCategoryLocalSafePath, "").split("/")
  }

  function show(isShown) {
    this.isOpened = isShown
    this.scene.show(isShown)
    this.scene.enable(isShown)
    this.resetFilter()
    if(!isShown)
      this.markSeenDecors()
  }

  // private

  getCategories = @() getCachedOrderByType(this.curDecorType, this.curUnit.unitType.tag)
  getDecorCache = @() getCachedDataByType(this.curDecorType, this.curUnit.unitType.tag)
  getContentObj = @(obj) obj != null ? obj.findObject($"content_{obj.id}") : null
  hasGroupsList = @(obj) obj.type == "groupsList"

  function generateGroupsCategoryContent(categoryId) {
    let groups = this.getDecorCache().catToGroupNames[categoryId]
    let decorType = this.curDecorType
    let categories = []
    foreach(groupId in groups) {
      let subListId = $"{categoryId}.{groupId}"
      this.currentSeenList.setSubListGetter(subListId, Callback(@() this.decoratorsCache.filter(@(_val, key) key == subListId).values()[0], this))
      categories.append({
        id = $"group_{groupId}"
        headerText = $"#{decorType.groupPathPrefix}{groupId}"
        categoryId
        groupId
        hasGroups = false
        isGroup = true
        unseenIcon = bhvUnseen.makeConfigStr(this.currentSeenListId, subListId)
      })
    }
    return handyman.renderCached(this.categoryTpl, { categories })
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
    this.markSeenDecors()
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
      let decor = getDecorator(decorId, this.curDecorType)
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

  function getDecorButtonsView(decors) {
    let slotDecorId = this.curSlotDecorId
    let unit = this.curUnit
    let currentListId = this.currentSeenListId
    return {
      isTooltipByHold = showConsoleButtons.value
      buttons = decors.map(@(decorator) getDecorButtonView(decorator, unit, {
        needHighlight = decorator.id == slotDecorId
        onClick = "onDecorItemClick"
        onDblClick = "onDecorItemDoubleClick"
        onCollectionBtnClick = isCollectionItem(decorator)
          ? "onCollectionIconClick"
          : null
        unseenIcon = decorator.canUse(unit) ? bhvUnseen.makeConfigStr(currentListId, decorator.id) : ""
      }))
    }
  }

  function generateDecalCategoryContent(categoryId, groupId) {
    let decors = this.getDecorCache().catToGroups?[categoryId][groupId]
    if (!decors || decors.len() == 0)
      return ""

    let view = this.getDecorButtonsView(decors)
    let unit = this.curUnit
    this.storeSeenDecors(decors.filter(@(decor) decor.canUse(unit)).map(@(decor) decor.id))
    return handyman.renderCached("%gui/commonParts/imageButton.tpl", view)
  }

  storeSeenDecors = @(decors) this.decorsToMarkSeen.extend(decors)

  function markSeenDecors() {
    if(this.currentSeenList != null)
      this.currentSeenList.markSeen(this.decorsToMarkSeen)
    this.decorsToMarkSeen.clear()
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

    broadcastEvent("DecorMenuItemClick", { decorator })
  }

  function onDecorItemDoubleClick(obj) {
    let decorator = this.getDecoratorByObj(obj, this.curDecorType)
    if (!decorator)
      return

    broadcastEvent("DecorMenuItemDblClick", { decorator })
  }

  function onCollectionIconClick(obj) {
    let decoratorId = obj.holderId
    broadcastEvent("DecorMenuCollectionIconClick", { decoratorId })
  }

  function onDecorItemSelect() {
    broadcastEvent("DecorMenuItemSelect")
  }

  function onDecorItemActivate(listObj) {
    this.onDecorItemClick(this.getSelectedObj(listObj))
  }

  function onDecorListHoverChange() {
    broadcastEvent("DecorMenuListHoverChange")
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

  function onFilterCancel(filterObj) {
    if (filterObj.getValue() != "")
      filterObj.setValue("")
    else
      broadcastEvent("DecorMenuFilterCancel")
  }

  function resetFilter() {
    let filterEditBox = this.scene.findObject("filter_edit_box")
    if(!filterEditBox?.isValid())
      return

    filterEditBox.setValue("")
  }

  function generateDecoratorsContentByName(name) {
    let filteredDecors = []
    let decorCache = this.getDecorCache()
    foreach(cat in decorCache.categories) {
      let groups = decorCache.catToGroups[cat]
      foreach(decors in groups) {
        filteredDecors.extend(decors.filter(@(v) utf8ToLower(v.getName()).indexof(name) != null))
      }
    }
    if (filteredDecors.len() == 0)
      return ""

    let view = this.getDecorButtonsView(filteredDecors)
    return handyman.renderCached("%gui/commonParts/imageButton.tpl", view)
  }

  function applyFilter(obj) {
    clearTimer(this.applyFilterTimer)
    let filterText = utf8ToLower(obj.getValue())
    if(filterText == "") {
      this.switchPanels("categories")
      return
    }

    let applyCallback = Callback(@() this.applyFilterImpl(filterText), this)
    this.applyFilterTimer = setTimeout(0.8, @() applyCallback())
  }

  function applyFilterImpl(filterText) {
    let decoratorsObj = this.scene.findObject("filtered_decorators")
    if(!decoratorsObj?.isValid())
      return
    let data = this.generateDecoratorsContentByName(filterText)
    this.guiScene.replaceContentFromText(decoratorsObj, data, data.len(), this)
    this.switchPanels("decorators")
  }

  function switchPanels(currentPanel) {
    let panels = this.scene.findObject("panels")
    panels.currentPanel = currentPanel
  }
}

gui_handlers.DecorMenuHandler <- DecorMenuHandler

return function(scene) {
  if (!scene?.isValid())
    return null

  return handlersManager.loadHandler(DecorMenuHandler, { scene })
}