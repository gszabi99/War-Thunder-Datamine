
let { getDecorButtonView } = require("%scripts/customization/decorView.nut")
let { isCollectionItem } = require("%scripts/collections/collections.nut")
let { findChild } = require("%sqDagui/daguiUtil.nut")

let class DecorMenuHandler extends ::gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.CUSTOM
  sceneBlkName = "%gui/customization/decorWnd.blk"

  categoryTpl = "%gui/customization/decorCategories"

  isOpened = false

  curUnit = null
  curDecorType = null
  curSlotDecorId = null
  preSelectDecorId = null

  function updateHandlerData(decorType, unit, slotDecorId, preSelectDecoratorId) {
    curDecorType = decorType
    curUnit = unit
    curSlotDecorId = slotDecorId
    preSelectDecorId = preSelectDecoratorId
  }

  function createCategories() {
    if (!scene?.isValid())
      return

    let headerObj = scene.findObject("decals_wnd_header")
    headerObj.setValue(::loc(curDecorType.listHeaderLocId))

    let decorType = curDecorType
    let decorCache = getDecorCache()
    let categories = getCategories().map(function(categoryId) {
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

    let data = ::handyman.renderCached(categoryTpl, { categories })
    let listObj = scene.findObject("categories_list")
    guiScene.replaceContentFromText(listObj, data, data.len(), this)
  }

  function updateSelectedCategory(decorator) {
    if (!isOpened)
      return

    let categoryObj = getSelectedCategoryObj()
    if (!categoryObj?.isValid() || hasGroupsList(categoryObj))
      return

    let decorListObj = getContentObj(categoryObj)
    if (!decorListObj?.isValid())
      return

    let data = generateDecalCategoryContent(categoryObj.categoryId, categoryObj.groupId)
    guiScene.replaceContentFromText(decorListObj, data, data.len(), this)
    decorListObj.getChild(decorListObj.getValue()).selected = "yes"
  }

  function collapseOpenedCategory() {
    let listObj = getSelectedCategoryObj()?.getParent()
    if (!listObj?.isValid())
      return

    let prevValue = listObj.getValue()
    listObj.setValue(-1)
    guiScene.applyPendingChanges(false)
    if (::show_console_buttons)
      ::move_mouse_on_child(listObj, prevValue)
  }

  function selectCategory(categoryId, groupId) {
    if (categoryId == "")
      return false

    let listObj = scene.findObject("categories_list")
    let { childIdx, childObj } = findChild(listObj, @(c) c.categoryId == categoryId)
    if (!childObj?.isValid())
      return false

    listObj.setValue(childIdx)

    if (!hasGroupsList(childObj) || groupId == "")
      return true

    let groupList = getContentObj(childObj)
    let groupIdx = findChild(groupList, @(g) g.groupId == groupId).childIdx
    if (groupIdx == -1)
      return false

    groupList.setValue(groupIdx)
    return true
  }

  function isCurCategoryListObjHovered() {
    let listObj = getContentObj(getSelectedCategoryObj())
    return (listObj?.isValid() ?? false) && listObj.isHovered()
  }

  function getSelectedDecor() {
    let listObj = getOpenedDecorListObj()
    let decalObj = getSelectedObj(listObj)
    return getDecoratorByObj(decalObj, curDecorType)
  }

  function getDecoratorByObj(obj, decoratorType) {
    if (!obj?.isValid())
      return null

    let decorId = ::getObjIdByPrefix(obj, "decal_") ?? ""
    return ::g_decorator.getDecorator(decorId, decoratorType)
  }

  function getSavedPath() {
    return ::loadLocalByAccount(curDecorType.currentOpenedCategoryLocalSafePath, "").split("/")
  }

  function show(isShown) {
    isOpened = isShown
    scene.show(isShown)
    scene.enable(isShown)
    ::enableHangarControls(!scene.findObject("hangar_control_tracking").isHovered())
  }

  // private

  getCategories = @() ::g_decorator.getCachedOrderByType(curDecorType, curUnit.unitType.tag)
  getDecorCache = @() ::g_decorator.getCachedDataByType(curDecorType, curUnit.unitType.tag)
  getContentObj = @(obj) obj != null ? obj.findObject($"content_{obj.id}") : null
  hasGroupsList = @(obj) obj.type == "groupsList"

  function generateGroupsCategoryContent(categoryId) {
    let groups = getDecorCache().catToGroupNames[categoryId]
    let decorType = curDecorType
    let categories = groups.map(@(groupId) {
      id = $"group_{groupId}"
      headerText = $"#{decorType.groupPathPrefix}{groupId}"
      categoryId
      groupId
      hasGroups = false
      isGroup = true
    })
    return ::handyman.renderCached(categoryTpl, { categories })
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

    let categoryObj = getSelectedObj(listObj)
    if (!categoryObj?.isValid()) {
      savePath("")
      scrollDecalsCategory()
      return
    }

    let categoryId = categoryObj.categoryId
    let groupId = categoryObj.groupId
    let isGroupList = hasGroupsList(categoryObj)
    let data = isGroupList
      ? generateGroupsCategoryContent(categoryId)
      : generateDecalCategoryContent(categoryId, groupId)

    let contentListObj = getContentObj(categoryObj)
    guiScene.replaceContentFromText(contentListObj, data, data.len(), this)

    savePath(categoryId, groupId)

    if (!isGroupList) {
      let decorId = preSelectDecorId ?? curSlotDecorId
      let decor = ::g_decorator.getDecorator(decorId, curDecorType)
      let index = (decor && decor.category == categoryId) ? decor.catIndex : 0
      contentListObj.setValue(index)
    }
    else
      contentListObj.setValue(-1)

    scrollDecalsCategory()
    guiScene.applyPendingChanges(false)
    let idx = contentListObj.getValue()
    ::move_mouse_on_child(contentListObj, idx != -1 ? idx : 0)
  }

  function savePath(categoryId, groupId = "") {
    let localPath = curDecorType.currentOpenedCategoryLocalSafePath
    ::saveLocalByAccount(localPath, "/".join([categoryId, groupId], true))
  }

  function generateDecalCategoryContent(categoryId, groupId) {
    let decors = getDecorCache().catToGroups?[categoryId][groupId]
    if (!decors || decors.len() == 0)
      return ""

    let slotDecorId = curSlotDecorId
    let unit = curUnit
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
    return ::handyman.renderCached("%gui/commonParts/imageButton", view)
  }

  function scrollDecalsCategory() {
    let categoryObj = getSelectedCategoryObj()
    if (!categoryObj?.isValid())
      return

    let headerObj = categoryObj.findObject($"btn_{categoryObj.id}")
    if (headerObj?.isValid())
      headerObj.scrollToView(true)

    let contentListObj = getContentObj(categoryObj)
    if (!contentListObj?.isValid() || contentListObj.childrenCount() == 0)
      return

    let idx = contentListObj.getValue()
    let itemObj = contentListObj.getChild(idx == -1 ? 0 : idx)
    if (itemObj?.isValid())
      itemObj.scrollToView()
  }

  function getSelectedCategoryObj() {
    let categoryObj = getSelectedObj(scene.findObject("categories_list"))
    if (!categoryObj?.isValid())
      return null

    return hasGroupsList(categoryObj)
      ? getSelectedObj(getContentObj(categoryObj)) ?? categoryObj
      : categoryObj
  }

  function getOpenedDecorListObj() {
    let categoryObj = getSelectedCategoryObj()
    if (!categoryObj?.isValid())
      return null

    return hasGroupsList(categoryObj) ? null : getContentObj(categoryObj)
  }

  function moveMouseOnDecalsHeader(listObj, valueDiff = 0) {
    let newValue = listObj.getValue() + valueDiff
    if (newValue < 0 || listObj.childrenCount() <= newValue)
      return false

    ::move_mouse_on_child(listObj.getChild(newValue), 0)
    return true
  }

  function onBtnCloseDecalsMenu() {
    show(false)
  }

  function onDecorCategorySelect(listObj) {
    fillDecalsCategoryContent(listObj)
  }

  function onDecorCategoryActivate(listObj) {
    collapseOpenedCategory()
  }

  function onDecorItemClick(obj) {
    let decorator = getDecoratorByObj(obj, curDecorType)
    if (!decorator)
      return

    let listObj = obj.getParent()
    if (listObj.getValue() != decorator.catIndex)
      listObj.setValue(decorator.catIndex)

    ::broadcastEvent("DecorMenuItemClick", { decorator })
  }

  function onDecorItemDoubleClick(obj) {
    let decorator = getDecoratorByObj(obj, curDecorType)
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
    onDecorItemClick(getSelectedObj(listObj))
  }

  function onDecorListHoverChange() {
    ::broadcastEvent("DecorMenuListHoverChange")
  }

  function onDecorItemHeader(listObj) {
    let parentList = listObj.getParent().getParent()
    moveMouseOnDecalsHeader(parentList)
  }

  function onDecorItemNextHeader(listObj) {
    let parentList = listObj.getParent().getParent()
    if (!moveMouseOnDecalsHeader(parentList, 1))
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