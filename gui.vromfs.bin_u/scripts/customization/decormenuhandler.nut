from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent
from "%sqstd/string.nut" import utf8ToLower
from "dagor.workcycle" import setTimeout, clearTimer
from "%scripts/dagui_library.nut" import *
from "%scripts/seen/seenIds.nut" import SEEN

let { getObjIdByPrefix } = require("%scripts/utils_sa.nut")
let { register_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")
let { BaseGuiHandlerWT } = require("%scripts/baseGuiHandlerWT.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { getDecorButtonView } = require("%scripts/customization/decorView.nut")
let { isCollectionItem } = require("%scripts/collections/collections.nut")
let { move_mouse_on_child, findChild } = require("%scripts/sqDagui/daguiUtil.nut")
let { handlerType } = require("%scripts/sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getDecorator, getCachedDataByType, getCachedOrderByType } = require("%scripts/customization/decoratorGetters.nut")
let bhvUnseen = require("%scripts/seen/bhvUnseen.nut")
let seenList = require("%scripts/seen/seenList.nut")
let { needMarkSeenResource, disableMarkSeenResource } = require("%scripts/seen/markSeenResources.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { loadLocalByAccount, saveLocalByAccount } = require("%scripts/clientState/localProfileDeprecated.nut")
let { getViewTypeByUnlockedItemType } = require("%scripts/customization/decoratorViewType.nut")
let { FAVORITE_CATEGORY_ID } = require("%scripts/customization/decoratorFavoritesStorage.nut")
let { filterDecorators } = require("%scripts/customization/decoratorUtils.nut")

const SEARCH_PAGE_ID = "search_result"
const CATEGORIES_PAGE_ID = "categories"

class DecorMenuHandler (BaseGuiHandlerWT) {
  wndType = handlerType.CUSTOM
  sceneBlkName = "%gui/customization/decorWnd.blk"
  categoryTpl = "%gui/customization/decorCategories.tpl"

  isOpened = false

  curUnit = null
  curDecorType = null
  curDecorViewType = null
  curSlotDecorId = null
  preSelectDecorId = null
  searchFilterTimer = null

  decoratorsCache = {}
  decorsToMarkSeen = []

  currentSeenListId = ""
  currentSeenList = null

  hideUnlockInfoList = []
  filtersOptions = null

  function initScreen() {
    if (this.filtersOptions == null)
      this.filtersOptions = { onlyRecieved = false, searchName = "" }

    this.scene.findObject("filter_only_avalible").setValue(this.filtersOptions.onlyRecieved)
  }

  function updateHandlerData(decorType, unit, slotDecorId, preSelectDecoratorId, hideUnlockInfoIds = []) {
    this.curDecorType = decorType
    this.curDecorViewType = getViewTypeByUnlockedItemType(decorType.unlockedItemType)
    this.curUnit = unit
    this.curSlotDecorId = slotDecorId
    this.preSelectDecorId = preSelectDecoratorId
    this.currentSeenListId = this.curDecorType.name == "DECALS" ? SEEN.DECALS : SEEN.DECORATORS
    this.currentSeenList = seenList.get(this.currentSeenListId)
    this.hideUnlockInfoList = hideUnlockInfoIds
  }

  function getFavoriteDecorators() {
    let favoritesIds = this.curDecorType.getFavorites()
    let list = []
    foreach (decorId in favoritesIds) {
      let decorator = getDecorator(decorId, this.curDecorType)
      if (decorator == null)
        continue
      list.append(decorator)
    }
    return list
  }

  function prepareDecoratorsCache(decorCache) {
    let needMarkSeen = needMarkSeenResource(this.currentSeenListId)
    this.decoratorsCache.clear()
    let categories = this.getCategories()
    foreach(categoryId in categories) {
      let groups = decorCache.catToGroupNames[categoryId]
      let hasGroups = groups.len() > 1 || groups[0] != "other"
      local listSummaryId = ""
      if (hasGroups) {
        listSummaryId = $"{categoryId}.summary"
        this.decoratorsCache[listSummaryId] <- []
      }
      foreach (groupId in groups) {
        let listId = $"{categoryId}.{groupId}"
        let decors = decorCache.catToGroups?[categoryId][groupId] ?? []
        let unit = this.curUnit
        let decorsListId = decors.filter(@(dec) dec.canUse(unit)).map(@(dec) dec.id)
        this.decoratorsCache[listId] <- decorsListId
        if (hasGroups)
          this.decoratorsCache[listSummaryId].extend(decorsListId)
        if (needMarkSeen)
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

    let decorCache = this.getDecorCache()
    this.prepareDecoratorsCache(decorCache)

    let categories = []
    foreach(categoryId in this.getCategories()) {
      let groups = decorCache.catToGroupNames[categoryId]
      let hasGroups = groups.len() > 1 || groups[0] != "other"
      let groupId = hasGroups ? "summary" : "other"
      let needShowCategory = this.needShowCategory(categoryId, decorCache.catToGroups[categoryId])

      let subListId = $"{categoryId}.{groupId}"
      this.currentSeenList.setSubListGetter(subListId, Callback(@() this.decoratorsCache.filter(@(_val, key) key == subListId).values()?[0] ?? [], this))
      categories.append({
        id = $"category_{categoryId}"
        headerText = $"#{this.curDecorViewType.categoryPathPrefix}{categoryId}"
        categoryId
        groupId
        hasGroups
        isHidden = needShowCategory ? null : true
        unseenIcon = bhvUnseen.makeConfigStr(this.currentSeenListId, subListId)
      })
    }
    categories.append({
      id = $"category_{FAVORITE_CATEGORY_ID}"
      headerText = $"#decor/category/{FAVORITE_CATEGORY_ID}"
      categoryId = FAVORITE_CATEGORY_ID
      groupId = "other"
      hasGroups = false
    })

    let data = handyman.renderCached(this.categoryTpl, { categories })
    let listObj = this.scene.findObject("categories_list")
    this.guiScene.replaceContentFromText(listObj, data, data.len(), this)
    this.switchPanels(CATEGORIES_PAGE_ID)
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

    let data = this.generateGroupContent(categoryObj.categoryId, categoryObj.groupId)
    this.guiScene.replaceContentFromText(decorListObj, data, data.len(), this)
    let decoratorsCount = decorListObj.childrenCount()
    if (decoratorsCount == 0)
      return
    let selectedIndex = decorListObj.getValue()
    decorListObj.getChild(decoratorsCount <= selectedIndex ? 0 : selectedIndex).selected = "yes"
  }

  function collapseOpenedCategory() {
    let listObj = this.getSelectedCategoryObj()?.getParent()
    if (!listObj?.isValid())
      return

    let prevValue = listObj.getValue()
    listObj.setValue(-1)
    this.guiScene.applyPendingChanges(false)
    if (showConsoleButtons.get())
      move_mouse_on_child(listObj, prevValue)
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

    let decorId = getObjIdByPrefix(obj, "decal_") ?? ""
    return getDecorator(decorId, decoratorType)
  }

  function getSavedPath() {
    return loadLocalByAccount(this.curDecorType.currentOpenedCategoryLocalSafePath, "").split("/")
  }

  function show(isShown) {
    this.isOpened = isShown
    this.scene.show(isShown)
    this.scene.enable(isShown)
    this.resetFilter()
    if(!isShown)
      this.markSeenDecors()
  }

  

  getCategories = @() getCachedOrderByType(this.curDecorType, this.curUnit.unitType.tag)
  getDecorCache = @() getCachedDataByType(this.curDecorType, this.curUnit.unitType.tag)
  getContentObj = @(obj) obj != null ? obj.findObject($"content_{obj.id}") : null
  hasGroupsList = @(obj) obj.type == "groupsList"

  function generateGroupsCategoryContent(categoryId) {
    let groups = this.getDecorCache().catToGroupNames[categoryId]
    let catToGroups = this.getDecorCache().catToGroups[categoryId]
    let categories = []

    foreach(groupId in groups) {
      let subListId = $"{categoryId}.{groupId}"
      let decalsInGroup = catToGroups[groupId]
      let isGroupVisible = filterDecorators(decalsInGroup, this.curDecorType, this.filtersOptions).len() > 0

      this.currentSeenList.setSubListGetter(subListId,
        Callback(@() this.decoratorsCache.filter(@(_val, key) key == subListId).values()[0], this))
      categories.append({
        id = $"group_{groupId}"
        headerText = $"#{this.curDecorViewType.groupPathPrefix}{groupId}"
        categoryId
        groupId
        hasGroups = false
        isGroup = true
        isHidden = isGroupVisible ? null : true
        unseenIcon = bhvUnseen.makeConfigStr(this.currentSeenListId, subListId)
      })
    }
    return handyman.renderCached(this.categoryTpl, { categories })
  }

  function getSelectedObj(listObj) {
    if (!listObj?.isValid())
      return null

    let idx = listObj.getValue() ?? -1
    let childrenCount = listObj.childrenCount()
    if ((idx < 0) || (idx >= childrenCount))
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
      : this.generateGroupContent(categoryId, groupId)

    let contentListObj = this.getContentObj(categoryObj)
    this.guiScene.replaceContentFromText(contentListObj, data, data.len(), this)

    this.savePath(categoryId, groupId)

    if (!isGroupList) {
      let decorId = this.preSelectDecorId ?? this.curSlotDecorId
      let decor = getDecorator(decorId, this.curDecorType, this.curUnit?.unitType.tag)
      let index = (decor && decor.category == categoryId) ? decor.catIndex : 0
      contentListObj.setValue(index)
    }
    else
      contentListObj.setValue(-1)

    this.scrollDecalsCategory()
    this.guiScene.applyPendingChanges(false)
    let idx = contentListObj.getValue()
    move_mouse_on_child(contentListObj, idx != -1 ? idx : 0)
  }

  function savePath(categoryId, groupId = "") {
    let localPath = this.curDecorType.currentOpenedCategoryLocalSafePath
    saveLocalByAccount(localPath, "/".join([categoryId, groupId], true))
  }

  function getDecorButtonsView(decors) {
    let slotDecorId = this.curSlotDecorId
    let unit = this.curUnit
    let currentListId = this.currentSeenListId
    let list = this.hideUnlockInfoList
    let curDecorType = this.curDecorType
    return {
      isTooltipByHold = showConsoleButtons.get()
      buttons = decors.map(@(decorator) getDecorButtonView(decorator, unit, {
        needHighlight = decorator.id == slotDecorId
        onClick = "onDecorItemClick"
        onDblClick = "onDecorItemDoubleClick"
        onCollectionBtnClick = isCollectionItem(decorator)
          ? "onCollectionIconClick"
          : null
        unseenIcon = decorator.canUse(unit) ? bhvUnseen.makeConfigStr(currentListId, decorator.id) : ""
        hideUnlockInfo = list.contains(decorator.id)
      }).__update({
        favoriteBtn = true,
        isFavorite = curDecorType.isInFavorites(decorator.id)
      }))
    }
  }

  function generateGroupContent(categoryId, groupId) {
    let isFavorites = categoryId == FAVORITE_CATEGORY_ID
    let decors = isFavorites
      ? this.getFavoriteDecorators()
      : this.getDecorCache().catToGroups?[categoryId][groupId]
    if (!decors || decors.len() == 0)
      return ""

    let filteredDecors = filterDecorators(decors, this.curDecorType, this.filtersOptions)
    let view = this.getDecorButtonsView(filteredDecors)
    let unit = this.curUnit
    this.storeSeenDecors(filteredDecors.filter(@(decor) decor.canUse(unit)).map(@(decor) decor.id))
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

    move_mouse_on_child(listObj.getChild(newValue), 0)
    return true
  }

  function onBtnCloseDecalsMenu() {
    broadcastEvent("DecalsMenuClosed")
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
      set_dirpad_event_processed(false)
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

  function generateSearchTabContent() {
    let filteredDecors = []
    let decorCache = this.getDecorCache()
    foreach(cat in decorCache.categories) {
      let groups = decorCache.catToGroups[cat]
      foreach (decors in groups)
        filteredDecors.extend(filterDecorators(decors, this.curDecorType, this.filtersOptions))
    }
    if (filteredDecors.len() == 0)
      return ""

    let view = this.getDecorButtonsView(filteredDecors)
    return handyman.renderCached("%gui/commonParts/imageButton.tpl", view)
  }

  function filterOnlyRecieved(obj) {
    this.filtersOptions.onlyRecieved = obj.getValue()
    this.onFiltersChange()
  }

  function needShowCategory(categoryId, groups, emptyGroups = null) {
    let catGroupNames = this.getDecorCache().catToGroupNames
    let groupsNames = catGroupNames[categoryId]
    let hasGroups = (groupsNames.len() > 1) || (groupsNames[0] != "other")

    if (hasGroups) {
      local isCategoryVisible = false
      foreach (groupName, groupData in groups) {
        let isGroupVisible = filterDecorators(groupData, this.curDecorType, this.filtersOptions).len() > 0
        isCategoryVisible = isCategoryVisible || isGroupVisible
        if (isCategoryVisible && !emptyGroups)
          return true
        if (emptyGroups && !isGroupVisible)
          emptyGroups.append(groupName)
      }
      return isCategoryVisible
    }

    return filterDecorators(groups["other"], this.curDecorType, this.filtersOptions).len() > 0
  }

  function updateCategoriesVisibility() {
    let decorCacheGroups = this.getDecorCache().catToGroups
    let listObj = this.scene.findObject("categories_list")

    if (this.filtersOptions.onlyRecieved == false) {
      foreach (categoryId, _groups in decorCacheGroups)
        showObjById($"category_{categoryId}", true, listObj)
      return
    }

    let selectedCategoryIndex = to_integer_safe(listObj.getValue(), -1)
    let selectedCategoryObj = selectedCategoryIndex >= 0
      ? listObj.getChild(selectedCategoryIndex)
      : null

    foreach(categoryId, groups in decorCacheGroups) {
      let categoryObjId = $"category_{categoryId}"
      let isSelectedCategory = selectedCategoryObj?.id == categoryObjId
      let emptyGroups = isSelectedCategory ? [] : null
      let isCategoryVisible = this.needShowCategory(categoryId, groups, emptyGroups)

      if (isCategoryVisible && emptyGroups != null) {
        let isAllGroupsVisible = emptyGroups.len() == 0
        foreach (groupName, _groupData in groups) {
          let needShowGroup = isAllGroupsVisible || !emptyGroups.contains(groupName)
          showObjById($"group_{groupName}", needShowGroup, selectedCategoryObj)
        }
      }

      showObjById(categoryObjId, isCategoryVisible, listObj)
    }
  }

  function onFiltersChange() {
    if (this.filtersOptions.searchName == "") {
      this.updateSelectedCategory(null)
      this.updateCategoriesVisibility()
      this.switchPanels(CATEGORIES_PAGE_ID)
      return
    }
    this.applySearchFilter()
  }

  function onSearchFieldChange(obj) {
    clearTimer(this.searchFilterTimer)
    let filterText = utf8ToLower(obj.getValue())
    this.filtersOptions.searchName = filterText
    if (filterText == "") {
      this.onFiltersChange()
      return
    }
    let applyCallback = Callback(@() this.onFiltersChange(), this)
    this.searchFilterTimer = setTimeout(0.8, @() applyCallback())
  }

  function applySearchFilter() {
    let decoratorsObj = this.scene.findObject("search_result")
    if(!decoratorsObj?.isValid())
      return
    let data = this.generateSearchTabContent()
    this.guiScene.replaceContentFromText(decoratorsObj, data, data.len(), this)
    this.switchPanels(SEARCH_PAGE_ID)
  }

  function switchPanels(currentPanel) {
    let panels = this.scene.findObject("panels")
    panels.currentPanel = currentPanel
  }

  function onAddToFavoriteBtn(btn) {
    if (btn == null)
      return
    let decorId = btn.getParent().decoratorId
    let isFavorite = this.curDecorType.isInFavorites(decorId)
    btn.getParent().isFavorite = isFavorite ? "no" : "yes"
    btn.tooltip = isFavorite ? loc("mainmenu/btnFavorite") : loc("mainmenu/btnFavoriteUnmark")
    this.guiScene.updateTooltip(btn)
    if (isFavorite)
      this.curDecorType.removeFromFavorites(decorId)
    else
      this.curDecorType.addToFavorites(decorId)
  }

  function onAddToFavoriteConsoleBtn() {
    let listObj = this.getOpenedDecorListObj()
    if (!listObj?.isValid())
      return

    local idx = listObj.childrenCount() - 1
    while (idx >= 0 && !listObj.getChild(idx)?.isHovered())
      idx--

    if (idx < 0)
      idx = listObj.getValue()
    if (idx < 0)
      return

    let decalObj = listObj.getChild(idx)
    let favBtnObj = decalObj?.isValid() ? decalObj.findObject("favorite_btn") : null
    if (favBtnObj == null)
      return

    this.onAddToFavoriteBtn(favBtnObj)
  }

  function onEventProfileUpdated(_p) {
    if (this.curUnit == null)
      return
    this.onFiltersChange()
  }

  function onEventUpdateFavoriteDecorators(eventData) {
    if (!this.isOpened)
      return
    if (eventData?[this.curDecorType.resourceType] == null)
      return
    let categoryObj = this.getSelectedCategoryObj()
    if (!categoryObj?.isValid() || this.hasGroupsList(categoryObj))
      return
    if (categoryObj.categoryId == FAVORITE_CATEGORY_ID)
      this.updateSelectedCategory(null)
  }
}

register_gui_handler("DecorMenuHandler", DecorMenuHandler)

return function(scene) {
  if (!scene?.isValid())
    return null

  return handlersManager.loadHandler(DecorMenuHandler, { scene })
}