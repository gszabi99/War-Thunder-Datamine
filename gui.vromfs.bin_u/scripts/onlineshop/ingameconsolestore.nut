local bhvUnseen = require("scripts/seen/bhvUnseen.nut")
local { setColoredDoubleTextToButton } = require("scripts/viewUtils/objectTextUpdate.nut")
local mkHoverHoldAction = require("sqDagui/timer/mkHoverHoldAction.nut")

class ::gui_handlers.IngameConsoleStore extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/items/itemsShop.blk"

  itemsCatalog = null
  chapter = null
  afterCloseFunc = null

  seenList = null
  sheetsArray = null

  titleLocId = ""
  storeLocId = ""
  openStoreLocId = ""
  seenEnumId = "other" // replacable

  curSheet = null
  curSheetId = null
  curItem = null

  needHoverSelect = null

  itemsPerPage = -1
  itemsList = null
  curPage = 0

  navItems  = null
  navigationHandlerWeak = null
  headerOffsetX = null
  isNavCollapsed = false

  // Used to avoid expensive get...List and further sort.
  itemsListValid = false

  sortBoxId = "sort_params_list"
  lastSorting = 0

  needWaitIcon = false
  isLoadingInProgress = false
  hoverHoldAction = null

  function initScreen()
  {
    needHoverSelect = ::show_console_buttons

    local infoObj = scene.findObject("item_info")
    guiScene.replaceContent(infoObj, "gui/items/itemDesc.blk", this)

    local titleObj = scene.findObject("wnd_title")
    titleObj.setValue(::loc(titleLocId))

    ::show_obj(getTabsListObj(), false)
    ::show_obj(getSheetsListObj(), false)
    hoverHoldAction = mkHoverHoldAction(scene.findObject("hover_hold_timer"))

    fillItemsList()
    moveMouseToMainList()
  }

  function reinitScreen(params)
  {
    itemsCatalog = params?.itemsCatalog
    itemsListValid = false
    applyFilters()
  }

  function fillItemsList()
  {
    initNavigation()
    markCurrentPageSeen()
    initSheets()
  }

  function initSheets()
  {
    if (!sheetsArray.len() && isLoadingInProgress)
    {
      fillPage()
      return
    }

    navItems = []
    foreach(idx, sh in sheetsArray)
    {
      if (curSheetId && curSheetId == sh.categoryId)
        curSheet = sh

      if (!curSheet && ::isInArray(chapter, sh.contentTypes))
        curSheet = sh

      navItems.append({
        idx = idx
        text = sh?.locText ?? ::loc(sh.locId)
        unseenIconId = "unseen_icon"
        unseenIcon = bhvUnseen.makeConfigStr(seenEnumId, sh.getSeenId())
      })
    }

    if (navigationHandlerWeak)
      navigationHandlerWeak.setNavItems(navItems)

    local sheetIdx = sheetsArray.indexof(curSheet) ?? 0
    getSheetsListObj().setValue(sheetIdx)

    //Update this objects only once. No need to do it on each updateButtons
    showSceneBtn("btn_preview", false)
    local warningTextObj = scene.findObject("warning_text")
    if (::checkObj(warningTextObj))
      warningTextObj.setValue(::colorize("warningTextColor", ::loc("warbond/alreadyBoughtMax")))

    applyFilters()
  }

  function initNavigation()
  {
    local handler = ::handlersManager.loadHandler(
      ::gui_handlers.navigationPanel,
      { scene                  = scene.findObject("control_navigation")
        onSelectCb             = ::Callback(doNavigateToSection, this)
        onClickCb              = ::Callback(onItemClickCb, this)
        onCollapseCb           = ::Callback(onNavCollapseCb, this)
        needShowCollapseButton = true
        headerHeight           = "1@buttonHeight"
      })
    registerSubHandler(navigationHandlerWeak)
    navigationHandlerWeak = handler.weakref()
    headerOffsetX = handler.headerOffsetX
  }

  function doNavigateToSection(obj) {
    if (obj?.isCollapsable)
      return

    markCurrentPageSeen()

    local newSheet = sheetsArray?[obj.idx]
    if (!newSheet)
      return

    curSheet = newSheet
    itemsListValid = false

    if (obj?.subsetId)
    {
      subsetList = curSheet.getSubsetsListParameters().subsetList
      curSubsetId = initSubsetId ?? obj.subsetId
      initSubsetId = null
      curSheet.setSubset(curSubsetId)
    }

    applyFilters()
  }

  function onItemClickCb(obj)
  {
    if (!obj?.isCollapsable || !navigationHandlerWeak)
      return

    local collapseBtnObj = scene.findObject($"btn_nav_{obj.idx}")
    local subsetId = curSubsetId
    navigationHandlerWeak.onCollapse(collapseBtnObj)
    if (collapseBtnObj.getParent().collapsed == "no")
      getSheetsListObj().setValue(//set selection on chapter item if not found item with subsetId just in case to avoid crash
        ::u.search(navItems, @(item) item?.subsetId == subsetId)?.idx ?? obj.idx)
  }

  function applyFilters()
  {
    initItemsListSizeOnce()
    if (!itemsListValid)
    {
      itemsListValid = true
      loadCurSheetItemsList()
      updateSortingList()
    }

    curPage = 0
    if (curItem)
    {
      local lastIdx = itemsList.findindex(function(item) { return item.id == curItem.id}.bindenv(this)) ?? -1
      if (lastIdx >= 0)
        curPage = (lastIdx / itemsPerPage).tointeger()
      else if (curPage * itemsPerPage > itemsCatalog.len())
        curPage = ::max(0, ((itemsCatalog.len() - 1) / itemsPerPage).tointeger())
    }
    fillPage()
  }

  function fillPage()
  {
    local view = { items = [], hasFocusBorder = true, onHover = "onItemHover" }

    if (!isLoadingInProgress)
    {
      local pageStartIndex = curPage * itemsPerPage
      local pageEndIndex = min((curPage + 1) * itemsPerPage, itemsList.len())
      for (local i=pageStartIndex; i < pageEndIndex; i++)
      {
        local item = itemsList[i]
        if (!item)
          continue
        view.items.append(item.getViewData({
          itemIndex = i.tostring(),
          unseenIcon = item.canBeUnseen()? null : bhvUnseen.makeConfigStr(seenEnumId, item.getSeenId())
        }))
      }
    }

    local listObj = getItemsListObj()
    local prevValue = listObj.getValue()
    local data = ::handyman.renderCached(("gui/items/item"), view)
    local isEmptyList = data.len() == 0 || isLoadingInProgress

    showSceneBtn("sorting_block", !isEmptyList)
    ::show_obj(listObj, !isEmptyList)
    guiScene.replaceContentFromText(listObj, data, data.len(), this)

    local emptyListObj = scene.findObject("empty_items_list")
    ::show_obj(emptyListObj, isEmptyList)
    ::show_obj(emptyListObj.findObject("loadingWait"), isEmptyList && needWaitIcon)

    showSceneBtn("items_shop_to_marketplace_button", false)
    showSceneBtn("items_shop_to_shop_button", false)
    local emptyListTextObj = scene.findObject("empty_items_list_text")
    emptyListTextObj.setValue(::loc($"items/shop/emptyTab/default{isLoadingInProgress ? "/loading" : ""}"))

    updateItemInfo()

    if (isLoadingInProgress)
      ::hidePaginator(scene.findObject("paginator_place"))
    else
      generatePaginator(scene.findObject("paginator_place"), this,
        curPage, ::ceil(itemsList.len().tofloat() / itemsPerPage) - 1, null, true /*show last page*/)

    if (!itemsList?.len() && sheetsArray.len())
      focusSheetsList()

    if (!isLoadingInProgress)
    {
      local value = findLastValue(prevValue)
      if (value >= 0)
        listObj.setValue(value)
    }
  }

  focusSheetsList = @() ::move_mouse_on_child_by_value(getSheetsListObj())

  function findLastValue(prevValue)
  {
    local offset = curPage * itemsPerPage
    local total = ::clamp(itemsList.len() - offset, 0, itemsPerPage)
    if (!total)
      return 0

    local res = ::clamp(prevValue, 0, total - 1)
    if (curItem)
      for(local i = 0; i < total; i++)
      {
        local item = itemsList[offset + i]
        if (curItem.id != item.id)
          continue
        res = i
      }
    return res
  }

  function goToPage(obj)
  {
    markCurrentPageSeen()
    curPage = obj.to_page.tointeger()
    fillPage()
  }

  function onItemAction(buttonObj)
  {
    local id = buttonObj?.holderId
    if (id == null)
      return
    local item = ::getTblValue(id.tointeger(), itemsList)
    onShowDetails(item)
  }

  function onMainAction(obj)
  {
    onShowDetails()
  }

  function onAltAction(obj)
  {
    local item = getCurItem()
    if (!item)
      return

    item.showDescription()
  }

  function onShowDetails(item = null)
  {
    item = item || getCurItem()
    if (!item)
      return

    item.showDetails()
  }

  function onNavCollapseCb (isCollapsed)
  {
    isNavCollapsed = isCollapsed
    applyFilters()
  }

  function initItemsListSizeOnce()
  {
    local listObj = getItemsListObj()
    local emptyListObj = scene.findObject("empty_items_list")
    local infoObj = scene.findObject("item_info_nest")
    local collapseBtnWidth = $"1@cIco+2*({headerOffsetX})"
    local leftPos = isNavCollapsed ? collapseBtnWidth : "0"
    local nawWidth = isNavCollapsed ? "0" : "1@defaultNavPanelWidth"
    local itemHeightWithSpace = "1@itemHeight+1@itemSpacing"
    local itemWidthWithSpace = "1@itemWidth+1@itemSpacing"
    local mainBlockHeight = "@rh-2@frameHeaderHeight-1@bh-1@fontHeightMedium-1@frameFooterHeight-1@bottomMenuPanelHeight-1@blockInterval"
    local itemsCountX = ::to_pixels($"@rw-1@shopInfoMinWidth-({leftPos})-({nawWidth})")
      / ::max(1, ::to_pixels(itemWidthWithSpace))
    local itemsCountY = ::to_pixels(mainBlockHeight)
      / ::max(1, ::to_pixels(itemHeightWithSpace))
    local contentWidth = $"{itemsCountX}*({itemWidthWithSpace})+1@itemSpacing"
    scene.findObject("main_block").height = mainBlockHeight
    scene.findObject("paginator_place").left = $"0.5({contentWidth})-0.5w+{leftPos}+{nawWidth}"
    showSceneBtn("nav_separator", !isNavCollapsed)
    listObj.width = contentWidth
    listObj.left = leftPos
    emptyListObj.width = contentWidth
    emptyListObj.left = leftPos
    infoObj.left = leftPos
    infoObj.width = "fw"
    itemsPerPage = (itemsCountX * itemsCountY ).tointeger()
  }

  function onChangeSortParam(obj)
  {
    local val = ::get_obj_valid_index(obj)
    lastSorting = val < 0 ? 0 : val
    curPage = 0
    updateSorting()
    fillPage()
  }

  function updateSortingList()
  {
    local obj = scene.findObject("sorting_block_bg")
    if (!::checkObj(obj))
      return

    local curVal = lastSorting
    local view = {
      id = sortBoxId
      btnName = "Y"
      funcName = "onChangeSortParam"
      values = curSheet.sortParams.map(@(p, idx) {
        text = "{0} ({1})".subst(::loc($"items/sort/{p.param}"), ::loc(p.asc? "items/sort/ascending" : "items/sort/descending"))
        isSelected = curVal == idx
      })
    }

    local data = ::handyman.renderCached("gui/commonParts/comboBox", view)
    guiScene.replaceContentFromText(obj, data, data.len(), this)
    getSortListObj().setValue(curVal)
  }

  function updateSorting()
  {
    if (!curSheet)
      return

    local sortParam = getSortParam()
    local isAscendingSort = sortParam.asc
    local sortSubParam = curSheet.sortSubParam
    itemsList.sort(function(a, b) {
      return sortOrder(a, b, isAscendingSort, sortParam.param, sortSubParam)
    }.bindenv(this))
  }

  function sortOrder(a, b, isAscendingSort, sortParam, sortSubParam)
  {
    return (isAscendingSort? 1: -1) * (a[sortParam] <=> b[sortParam]) || a[sortSubParam] <=> b[sortSubParam]
  }

  function getSortParam()
  {
    return curSheet?.sortParams[getSortListObj().getValue()]
  }

  function markCurrentPageSeen()
  {
    if (!itemsList)
      return

    local pageStartIndex = curPage * itemsPerPage
    local pageEndIndex = min((curPage + 1) * itemsPerPage, itemsList.len())
    local list = []
    for (local i = pageStartIndex; i < pageEndIndex; ++i)
      list.append(itemsList[i].getSeenId())

    seenList.markSeen(list)
  }

  function updateItemInfo()
  {
    local item = getCurItem()
    fillItemInfo(item)
    showSceneBtn("jumpToDescPanel", ::show_console_buttons && item != null)
    updateButtons()

    if (!item && !isLoadingInProgress)
      return

    curItem = item
    markItemSeen(item)
  }

  function fillItemInfo(item)
  {
    local descObj = scene.findObject("item_info")

    local obj = null

    obj = descObj.findObject("item_name")
    obj.setValue(item?.name ?? "")

    obj = descObj.findObject("item_desc_div")
    local data = getPriceBlock(item)
    guiScene.replaceContentFromText(obj, data, data.len(), this)

    obj = descObj.findObject("item_desc_under_div")
    obj.setValue(item?.getDescription() ?? "")

    obj = descObj.findObject("item_icon")
    local imageData = item?.getBigIcon() ?? item?.getIcon() ?? ""
    obj.wideSize = "yes"
    local showImageBlock = imageData.len() != 0
    obj.show(showImageBlock)
    guiScene.replaceContentFromText(obj, imageData, imageData.len(), this)
  }

  function getPriceBlock(item)
  {
    if (item?.isBought)
      return ""
    //Generate price string as PSN requires and return blk format to replace it.
    return handyman.renderCached("gui/commonParts/discount", item)
  }

  function updateButtonsBar() {
    local obj = getItemsListObj()
    local isButtonsVisible = !::show_console_buttons || (::check_obj(obj) && obj.isHovered())
    showSceneBtn("item_actions_bar", isButtonsVisible)
    return isButtonsVisible
  }

  function updateButtons()
  {
    if (!updateButtonsBar())
      return

    local item = getCurItem()
    local showMainAction = item != null && !item.isBought
    local buttonObj = showSceneBtn("btn_main_action", showMainAction)
    if (showMainAction)
    {
      buttonObj.visualStyle = "secondary"
      setColoredDoubleTextToButton(scene, "btn_main_action", ::loc(storeLocId))
    }

    local showSecondAction = openStoreLocId != "" && (item?.isBought ?? false)
    showSceneBtn("btn_alt_action", showSecondAction)
    if (showSecondAction)
      setColoredDoubleTextToButton(scene, "btn_alt_action", ::loc(openStoreLocId))

    showSceneBtn("warning_text", showSecondAction)
  }

  function markItemSeen(item)
  {
    if (item)
      seenList.markSeen(item.getSeenId())
  }

  function getCurItem()
  {
    if (isLoadingInProgress)
      return null

    local obj = getItemsListObj()
    if (!::check_obj(obj))
      return null

    return itemsList?[obj.getValue() + curPage * itemsPerPage]
  }

  function getCurItemObj()
  {
    local itemListObj = getItemsListObj()
    local value = ::get_obj_valid_index(itemListObj)
    if (value < 0)
      return null

    return itemListObj.getChild(value)
  }

  onTabChange = @() null
  onToShopButton = @(obj) null
  onToMarketplaceButton = @(obj) null
  onLinkAction = @(obj) null
  onItemPreview = @(obj) null
  onOpenCraftTree = @(obj) null
  onShowSpecialTasks = @(obj) null
  onShowBattlePass = @(obj) null

  getTabsListObj = @() scene.findObject("tabs_list")
  getSheetsListObj = @() scene.findObject("nav_list")
  getSortListObj = @() scene.findObject(sortBoxId)
  getItemsListObj = @() scene.findObject("items_list")
  moveMouseToMainList = @() ::move_mouse_on_child_by_value(getItemsListObj())

  function goBack()
  {
    markCurrentPageSeen()
    base.goBack()
  }

  function afterModalDestroy()
  {
    if (afterCloseFunc)
      afterCloseFunc()
  }

  function onItemsListFocusChange()
  {
    if (isValid())
      updateItemInfo()
  }

  function onJumpToDescPanelAccessKey(obj)
  {
    if (!::show_console_buttons)
      return
    local containerObj = scene.findObject("item_info")
    if (::check_obj(containerObj) && containerObj.isHovered())
      ::move_mouse_on_obj(getCurItemObj())
    else
      ::move_mouse_on_obj(containerObj)
  }

  function onItemHover(obj) {
    if (!needHoverSelect)
      return

    hoverHoldAction(obj, function(focusObj) {
      local idx = focusObj.holderId.tointeger()
      local value = idx - curPage * itemsPerPage
      local listObj = getItemsListObj()
      if (listObj.getValue() != value && value >= 0 && value < listObj.childrenCount())
        listObj.setValue(value)
    }.bindenv(this))
  }
}