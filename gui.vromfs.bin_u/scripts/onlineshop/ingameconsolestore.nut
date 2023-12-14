//checked for plus_string
from "%scripts/dagui_natives.nut" import is_mouse_last_time_used
from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { show_obj, getObjValidIndex } = require("%sqDagui/daguiUtil.nut")
let { ceil } = require("math")
let bhvUnseen = require("%scripts/seen/bhvUnseen.nut")
let { setColoredDoubleTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let mkHoverHoldAction = require("%sqDagui/timer/mkHoverHoldAction.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { move_mouse_on_child_by_value, move_mouse_on_obj, handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")

gui_handlers.IngameConsoleStore <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/items/itemsShop.blk"

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
  isMouseMode = true

  function initScreen() {
    this.updateMouseMode()
    this.updateShowItemButton()
    let infoObj = this.scene.findObject("item_info")
    this.guiScene.replaceContent(infoObj, "%gui/items/itemDesc.blk", this)

    let titleObj = this.scene.findObject("wnd_title")
    titleObj.setValue(loc(this.titleLocId))

    show_obj(this.getTabsListObj(), false)
    show_obj(this.getSheetsListObj(), false)
    this.hoverHoldAction = mkHoverHoldAction(this.scene.findObject("hover_hold_timer"))

    this.fillItemsList()
    this.moveMouseToMainList()
  }

  function reinitScreen(params) {
    this.itemsCatalog = params?.itemsCatalog
    this.curItem = params?.curItem ?? this.curItem
    this.itemsListValid = false
    this.applyFilters()
    this.moveMouseToMainList()
  }

  function fillItemsList() {
    this.initNavigation()
    this.initSheets()
  }

  function initSheets() {
    if (!this.sheetsArray.len() && this.isLoadingInProgress) {
      this.fillPage()
      return
    }

    this.navItems = []
    foreach (idx, sh in this.sheetsArray) {
      if (this.curSheetId && this.curSheetId == sh.categoryId)
        this.curSheet = sh

      if (!this.curSheet && isInArray(this.chapter, sh.contentTypes))
        this.curSheet = sh

      this.navItems.append({
        idx = idx
        text = sh?.locText ?? loc(sh.locId)
        unseenIconId = "unseen_icon"
        unseenIcon = bhvUnseen.makeConfigStr(this.seenEnumId, sh.getSeenId())
      })
    }

    if (this.navigationHandlerWeak)
      this.navigationHandlerWeak.setNavItems(this.navItems)

    let sheetIdx = this.sheetsArray.indexof(this.curSheet) ?? 0
    this.getSheetsListObj().setValue(sheetIdx)

    //Update this objects only once. No need to do it on each updateButtons
    this.showSceneBtn("btn_preview", false)
    let warningTextObj = this.scene.findObject("warning_text")
    if (checkObj(warningTextObj))
      warningTextObj.setValue(colorize("warningTextColor", loc("warbond/alreadyBoughtMax")))

    this.applyFilters()
  }

  function initNavigation() {
    let handler = handlersManager.loadHandler(
      gui_handlers.navigationPanel,
      { scene                  = this.scene.findObject("control_navigation")
        onSelectCb             = Callback(this.doNavigateToSection, this)
        onClickCb              = Callback(this.onItemClickCb, this)
        onCollapseCb           = Callback(this.onNavCollapseCb, this)
        needShowCollapseButton = true
        headerHeight           = "1@buttonHeight"
      })
    this.registerSubHandler(this.navigationHandlerWeak)
    this.navigationHandlerWeak = handler.weakref()
    this.headerOffsetX = handler.headerOffsetX
  }

  function doNavigateToSection(obj) {
    if (obj?.isCollapsable)
      return

    this.markCurrentPageSeen()

    let newSheet = this.sheetsArray?[obj.idx]
    if (!newSheet)
      return

    this.curSheet = newSheet
    this.itemsListValid = false

    if (obj?.subsetId) {
      this.subsetList = this.curSheet.getSubsetsListParameters().subsetList
      this.curSubsetId = this.initSubsetId ?? obj.subsetId
      this.initSubsetId = null
      this.curSheet.setSubset(this.curSubsetId)
    }

    this.applyFilters()
  }

  function onItemClickCb(obj) {
    if (!obj?.isCollapsable || !this.navigationHandlerWeak)
      return

    let collapseBtnObj = this.scene.findObject($"btn_nav_{obj.idx}")
    let subsetId = this.curSubsetId
    this.navigationHandlerWeak.onCollapse(collapseBtnObj)
    if (collapseBtnObj.getParent().collapsed == "no")
      this.getSheetsListObj().setValue( //set selection on chapter item if not found item with subsetId just in case to avoid crash
        u.search(this.navItems, @(item) item?.subsetId == subsetId)?.idx ?? obj.idx)
  }

  function recalcCurPage() {
    let lastIdx = this.itemsList.findindex(function(item) { return item.id == this.curItem?.id }.bindenv(this)) ?? -1
    if (lastIdx > 0)
      this.curPage = this.getPageNum(lastIdx)
    else if (this.curPage * this.itemsPerPage > this.itemsList.len())
      this.curPage = max(0, this.getPageNum(this.itemsList.len() - 1))
  }

  function applyFilters() {
    this.initItemsListSizeOnce()
    if (!this.itemsListValid) {
      this.itemsListValid = true
      this.loadCurSheetItemsList()
      this.updateSortingList()
    }

    this.recalcCurPage()
    this.fillPage()
  }

  function fillPage() {
    let view = { items = [], hasFocusBorder = true, onHover = "onItemHover" }

    if (!this.isLoadingInProgress) {
      let pageStartIndex = this.curPage * this.itemsPerPage
      let pageEndIndex = min((this.curPage + 1) * this.itemsPerPage, this.itemsList.len())
      for (local i = pageStartIndex; i < pageEndIndex; i++) {
        let item = this.itemsList[i]
        if (!item)
          continue
        view.items.append(item.getViewData({
          itemIndex = i.tostring(),
          unseenIcon = item.canBeUnseen() ? null : bhvUnseen.makeConfigStr(this.seenEnumId, item.getSeenId())
        }))
      }
    }

    let listObj = this.getItemsListObj()
    let prevValue = listObj.getValue()
    let data = handyman.renderCached(("%gui/items/item.tpl"), view)
    let isEmptyList = data.len() == 0 || this.isLoadingInProgress

    this.showSceneBtn("sorting_block", !isEmptyList)
    show_obj(listObj, !isEmptyList)
    this.guiScene.replaceContentFromText(listObj, data, data.len(), this)

    let emptyListObj = this.scene.findObject("empty_items_list")
    show_obj(emptyListObj, isEmptyList)
    show_obj(emptyListObj.findObject("loadingWait"), isEmptyList && this.needWaitIcon && this.isLoadingInProgress)

    this.showSceneBtn("items_shop_to_marketplace_button", false)
    this.showSceneBtn("items_shop_to_shop_button", false)
    let emptyListTextObj = this.scene.findObject("empty_items_list_text")
    emptyListTextObj.setValue(loc($"items/shop/emptyTab/default{this.isLoadingInProgress ? "/loading" : ""}"))

    if (this.isLoadingInProgress)
      ::hidePaginator(this.scene.findObject("paginator_place"))
    else {
      this.recalcCurPage()
      ::generatePaginator(this.scene.findObject("paginator_place"), this,
        this.curPage, this.getPageNum(this.itemsList.len() - 1), null, true /*show last page*/ )
    }

    if (!this.itemsList?.len() && this.sheetsArray.len())
      this.focusSheetsList()

    if (!this.isLoadingInProgress) {
      let value = this.findLastValue(prevValue)
      if (value >= 0)
        listObj.setValue(value)
    }
  }

  focusSheetsList = @() move_mouse_on_child_by_value(this.getSheetsListObj())

  function findLastValue(prevValue) {
    let offset = this.curPage * this.itemsPerPage
    let total = clamp(this.itemsList.len() - offset, 0, this.itemsPerPage)
    if (!total)
      return 0

    local res = clamp(prevValue, 0, total - 1)
    if (this.curItem)
      for (local i = 0; i < total; i++) {
        let item = this.itemsList[offset + i]
        if (this.curItem.id != item.id)
          continue
        res = i
      }
    return res
  }

  function goToPage(obj) {
    this.markCurrentPageSeen()
    this.curItem = null
    this.curPage = obj.to_page.tointeger()
    this.fillPage()
  }

  function onItemAction(buttonObj) {
    let id = buttonObj?.holderId
    if (id == null)
      return
    let item = getTblValue(id.tointeger(), this.itemsList)
    this.onShowDetails(item)
  }

  function onMainAction(_obj) {
    this.onShowDetails()
  }

  function onAltAction(_obj) {
    let item = this.getCurItem()
    if (!item)
      return

    item.showDescription()
  }

  function onShowDetails(item = null) {
    item = item || this.getCurItem()
    if (!item)
      return

    item.showDetails()
  }

  function onNavCollapseCb (isCollapsed) {
    this.isNavCollapsed = isCollapsed
    this.applyFilters()
  }

  function initItemsListSizeOnce() {
    let listObj = this.getItemsListObj()
    let emptyListObj = this.scene.findObject("empty_items_list")
    let infoObj = this.scene.findObject("item_info_nest")
    let collapseBtnWidth = $"1@cIco+2*({this.headerOffsetX})"
    let leftPos = this.isNavCollapsed ? collapseBtnWidth : "0"
    let nawWidth = this.isNavCollapsed ? "0" : "1@defaultNavPanelWidth"
    let itemHeightWithSpace = "1@itemHeight+1@itemSpacing"
    let itemWidthWithSpace = "1@itemWidth+1@itemSpacing"
    let mainBlockHeight = "@rh-2@frameHeaderHeight-1@fontHeightMedium-1@frameFooterHeight-1@bottomMenuPanelHeight-1@blockInterval"
    let itemsCountX = max(to_pixels($"@rw-1@shopInfoMinWidth-({leftPos})-({nawWidth})")
      / max(1, to_pixels(itemWidthWithSpace)), 1)
    let itemsCountY = max(to_pixels(mainBlockHeight)
      / max(1, to_pixels(itemHeightWithSpace)), 1)
    let contentWidth = $"{itemsCountX}*({itemWidthWithSpace})+1@itemSpacing"
    this.scene.findObject("main_block").height = mainBlockHeight
    this.scene.findObject("paginator_place").left = $"0.5({contentWidth})-0.5w+{leftPos}+{nawWidth}"
    listObj.width = contentWidth
    listObj.left = leftPos
    emptyListObj.width = contentWidth
    emptyListObj.left = leftPos
    infoObj.left = leftPos
    infoObj.width = "fw"
    this.itemsPerPage = (itemsCountX * itemsCountY).tointeger()
  }

  function onChangeSortParam(obj) {
    let val = getObjValidIndex(obj)
    this.lastSorting = val < 0 ? 0 : val
    this.updateSorting()
    this.applyFilters()
  }

  function updateSortingList() {
    let obj = this.scene.findObject("sorting_block_bg")
    if (!checkObj(obj))
      return

    let curVal = this.lastSorting
    let view = {
      id = this.sortBoxId
      btnName = "Y"
      funcName = "onChangeSortParam"
      values = this.curSheet?.sortParams.map(@(p, idx) {
        text = "{0} ({1})".subst(loc($"items/sort/{p.param}"), loc(p.asc ? "items/sort/ascending" : "items/sort/descending"))
        isSelected = curVal == idx
      }) ?? []
    }

    let data = handyman.renderCached("%gui/commonParts/comboBox.tpl", view)
    this.guiScene.replaceContentFromText(obj, data, data.len(), this)
    this.getSortListObj().setValue(curVal)
  }

  function updateSorting() {
    if (!this.curSheet)
      return

    let sortParam = this.getSortParam()
    let isAscendingSort = sortParam.asc
    let sortSubParam = this.curSheet.sortSubParam
    this.itemsList.sort(function(a, b) {
      return this.sortOrder(a, b, isAscendingSort, sortParam.param, sortSubParam)
    }.bindenv(this))
  }

  function sortOrder(a, b, isAscendingSort, sortParam, sortSubParam) {
    return (isAscendingSort ? 1 : -1) * (a[sortParam] <=> b[sortParam]) || a[sortSubParam] <=> b[sortSubParam]
  }

  function getSortParam() {
    return this.curSheet?.sortParams[this.getSortListObj().getValue()]
  }

  function markCurrentPageSeen() {
    if (!this.itemsList)
      return

    let pageStartIndex = this.curPage * this.itemsPerPage
    let pageEndIndex = min((this.curPage + 1) * this.itemsPerPage, this.itemsList.len())
    let list = []
    for (local i = pageStartIndex; i < pageEndIndex; ++i)
      list.append(this.itemsList[i].getSeenId())

    this.seenList.markSeen(list)
  }

  function updateItemInfo() {
    let item = this.getCurItem()
    this.fillItemInfo(item)
    this.showSceneBtn("jumpToDescPanel", showConsoleButtons.value && item != null)
    this.updateButtons()

    if (!item && !this.isLoadingInProgress)
      return

    this.curItem = item
    this.markItemSeen(item)
  }

  function fillItemInfo(item) {
    let descObj = this.scene.findObject("item_info")

    local obj = null

    obj = descObj.findObject("item_name")
    obj.setValue(item?.name ?? "")

    obj = descObj.findObject("item_desc_div")
    let itemsView = item?.getItemsView() ?? ""
    let data = $"{this.getPriceBlock(item)}{itemsView}"
    this.guiScene.replaceContentFromText(obj, data, data.len(), this)

    obj = descObj.findObject("item_desc_under_div")
    obj.setValue(item?.getDescription() ?? "")

    obj = descObj.findObject("item_icon")
    let imageData = item?.getBigIcon() ?? item?.getIcon() ?? ""
    obj.wideSize = "yes"
    let showImageBlock = imageData.len() != 0
    obj.show(showImageBlock)
    this.guiScene.replaceContentFromText(obj, imageData, imageData.len(), this)
  }

  function getPriceBlock(item) {
    if (item?.isBought)
      return ""
    //Generate price string as PSN requires and return blk format to replace it.
    return handyman.renderCached("%gui/commonParts/discount.tpl", item)
  }

  function updateButtonsBar() {
    let obj = this.getItemsListObj()
    let isButtonsVisible = this.isMouseMode || (checkObj(obj) && obj.isHovered())
    this.showSceneBtn("item_actions_bar", isButtonsVisible)
    return isButtonsVisible
  }

  function updateButtons() {
    if (!this.updateButtonsBar())
      return

    let item = this.getCurItem()
    let showMainAction = item != null && !item.isBought
    let buttonObj = this.showSceneBtn("btn_main_action", showMainAction)
    if (showMainAction) {
      buttonObj.visualStyle = "secondary"
      setColoredDoubleTextToButton(this.scene, "btn_main_action", loc(this.storeLocId))
    }

    let showSecondAction = this.openStoreLocId != "" && (item?.isBought ?? false)
    this.showSceneBtn("btn_alt_action", showSecondAction)
    if (showSecondAction)
      setColoredDoubleTextToButton(this.scene, "btn_alt_action", loc(this.openStoreLocId))

    this.showSceneBtn("warning_text", showSecondAction)
  }

  function markItemSeen(item) {
    if (item)
      this.seenList.markSeen(item.getSeenId())
  }

  function getCurItem() {
    if (this.isLoadingInProgress)
      return null

    let obj = this.getItemsListObj()
    if (!checkObj(obj))
      return null

    return this.itemsList?[obj.getValue() + this.curPage * this.itemsPerPage]
  }

  function getCurItemObj() {
    let itemListObj = this.getItemsListObj()
    let value = getObjValidIndex(itemListObj)
    if (value < 0)
      return null

    return itemListObj.getChild(value)
  }

  getPageNum = @(itemsIdx) ceil(itemsIdx.tofloat() / this.itemsPerPage).tointeger() - 1

  onTabChange = @() null
  onToShopButton = @(_obj) null
  onToMarketplaceButton = @(_obj) null
  onLinkAction = @(_obj) null
  onItemPreview = @(_obj) null
  onOpenCraftTree = @(_obj) null
  onShowSpecialTasks = @(_obj) null
  onShowBattlePass = @(_obj) null

  getTabsListObj = @() this.scene.findObject("tabs_list")
  getSheetsListObj = @() this.scene.findObject("nav_list")
  getSortListObj = @() this.scene.findObject(this.sortBoxId)
  getItemsListObj = @() this.scene.findObject("items_list")
  moveMouseToMainList = @() move_mouse_on_child_by_value(this.getItemsListObj())

  function goBack() {
    this.markCurrentPageSeen()
    base.goBack()
  }

  function afterModalDestroy() {
    if (this.afterCloseFunc)
      this.afterCloseFunc()
  }

  function onItemsListFocusChange() {
    if (this.isValid())
      this.updateItemInfo()
  }

  function onJumpToDescPanelAccessKey(_obj) {
    if (!showConsoleButtons.value)
      return
    let containerObj = this.scene.findObject("item_info")
    if (checkObj(containerObj) && containerObj.isHovered())
      move_mouse_on_obj(this.getCurItemObj())
    else
      move_mouse_on_obj(containerObj)
  }

  function onItemHover(obj) {
    if (!showConsoleButtons.value)
      return
    let wasMouseMode = this.isMouseMode
    this.updateMouseMode()
    if (wasMouseMode != this.isMouseMode)
      this.updateShowItemButton()
    if (this.isMouseMode)
      return

    if (obj.holderId == this.getCurItemObj()?.holderId)
      return
    this.hoverHoldAction(obj, function(focusObj) {
      let idx = focusObj.holderId.tointeger()
      let value = idx - this.curPage * this.itemsPerPage
      let listObj = this.getItemsListObj()
      if (listObj.getValue() != value && value >= 0 && value < listObj.childrenCount())
        listObj.setValue(value)
    }.bindenv(this))
  }

  updateMouseMode = @() this.isMouseMode = !showConsoleButtons.value || is_mouse_last_time_used()
  function updateShowItemButton() {
    let listObj = this.getItemsListObj()
    if (listObj?.isValid())
      listObj.showItemButton = this.isMouseMode ? "yes" : "no"
  }
}
