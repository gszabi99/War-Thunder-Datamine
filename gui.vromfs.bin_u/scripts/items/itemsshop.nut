from "%scripts/dagui_natives.nut" import is_mouse_last_time_used
from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import itemsTab
from "%scripts/mainConsts.nut" import SEEN
from "%scripts/controls/rawShortcuts.nut" import GAMEPAD_ENTER_SHORTCUT

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { show_obj, getObjValidIndex, enableObjsByTable, move_mouse_on_child_by_value,
  move_mouse_on_obj } = require("%sqDagui/daguiUtil.nut")
let { ceil } = require("math")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { isInMenu } = require("%scripts/clientState/clientStates.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let sheets = require("%scripts/items/itemsShopSheets.nut")
let itemInfoHandler = require("%scripts/items/itemInfoHandler.nut")
let workshop = require("%scripts/items/workshop/workshop.nut")
let seenList = require("%scripts/seen/seenList.nut")
let bhvUnseen = require("%scripts/seen/bhvUnseen.nut")
let workshopCraftTreeWnd = require("%scripts/items/workshop/workshopCraftTreeWnd.nut")
let tutorAction = require("%scripts/tutorials/tutorialActions.nut")
let { canStartPreviewScene } = require("%scripts/customization/contentPreview.nut")
let { setDoubleTextToButton, setColoredDoubleTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let mkHoverHoldAction = require("%sqDagui/timer/mkHoverHoldAction.nut")
let { isMarketplaceEnabled } = require("%scripts/items/itemsMarketplaceStatus.nut")
let { goToMarketplace } = require("%scripts/items/itemsMarketplace.nut")
let { setBreadcrumbGoBackParams } = require("%scripts/breadcrumb.nut")
let { addPromoAction } = require("%scripts/promo/promoActions.nut")
let { fillDescTextAboutDiv, updateExpireAlarmIcon,
  fillItemDescUnderTable } = require("%scripts/items/itemVisual.nut")
let { needUseHangarDof } = require("%scripts/viewUtils/hangarDof.nut")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { findItemById, getItemsSortComparator } = require("%scripts/items/itemsManager.nut")
let { gui_start_items_list } = require("%scripts/items/startItemsShop.nut")
let { defer } = require("dagor.workcycle")
let { generatePaginator } = require("%scripts/viewUtils/paginator.nut")
let { maxAllowedWarbondsBalance } = require("%scripts/warbonds/warbondsState.nut")
let { getWarbondsBalanceText } = require("%scripts/warbonds/warbondsManager.nut")
let { gui_modal_tutor } = require("%scripts/guiTutorial.nut")
let { ItemsRecycler, CRAFT_PART_TO_NEW_ITEM_RATIO, getRecyclingItemUniqKey, MAXIMUM_CRAFTS_AT_ONCE_TIME
} = require("%scripts/items/itemsRecycler.nut")
let { enqueueItem, requestLimits } = require("%scripts/items/itemLimits.nut")
let getNavigationImagesText = require("%scripts/utils/getNavigationImagesText.nut")

let tabIdxToName = {
  [itemsTab.SHOP] = "items/shop",
  [itemsTab.INVENTORY] = "items/inventory",
  [itemsTab.WORKSHOP] = "items/workshop",
  [itemsTab.RECYCLING] = "items/recycling",
}

let getNameByTabIdx = @(idx) tabIdxToName?[idx] ?? ""

let tabIdxToSeenId = {
  [itemsTab.SHOP] = SEEN.ITEMS_SHOP,
  [itemsTab.INVENTORY] = SEEN.INVENTORY,
  [itemsTab.WORKSHOP] = SEEN.WORKSHOP,
  [itemsTab.RECYCLING] = SEEN.RECYCLING,
}

let getSeenIdByTabIdx = @(idx) tabIdxToSeenId?[idx]

function isEqualItemsLists(curItemsList, newItemsList) {
  if (curItemsList == null || newItemsList == null)
    return false

  if (curItemsList.len() != newItemsList.len())
    return false

  foreach (idx, item in curItemsList) {
    let newItem = newItemsList[idx]
    if (item.id != newItem.id || item.getAmount() != newItem.getAmount())
      return false
  }

  return true
}

gui_handlers.ItemsList <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.BASE
  sceneBlkName = "%gui/items/itemsShop.blk"
  shouldBlurSceneBgFn = needUseHangarDof

  curTab = 0 
  visibleTabs = null 
  curSheet = null
  curItem = null 
  hoverHoldAction = null

  tabHasChanged = false
  isSheetsInUpdate = false
  isItemTypeChangeUpdate = false
  itemsPerPage = -1
  windowSize = 0
  itemsList = null
  curPage = 0
  shouldSetPageByItem = false

  slotbarActions = [ "preview", "testflightforced", "sec_weapons", "weapons", "info" ]
  displayItemTypes = null
  sheetsArray = null
  navItems = null

  subsetList = null
  curSubsetId = null
  initSubsetId = null

  navigationHandlerWeak = null
  headerOffsetX = null
  isNavCollapsed = false

  
  itemsListValid = false
  infoHandler = null
  isMouseMode = true
  isCraftTreeWndOpen = false
  craftTreeItem = null
  recycler = null

  currentHoveredItemId = -1
  currentSelectedId = -1
  lastMousePos = [0, 0]
  lastMouseDelta = [0, 0]

  isInRecyclingTab = @() this.curTab == itemsTab.RECYCLING

  function initScreen() {
    this.initRecyclingControls()
    setBreadcrumbGoBackParams(this)
    this.updateMouseMode()
    this.updateShowItemButton()
    this.infoHandler = itemInfoHandler(this.scene.findObject("item_info"))
    this.initNavigation()
    sheets.updateWorkshopSheets()
    this.initSheetsOnce()

    let sheetData = this.curTab < 0 && this.curItem ? sheets.getSheetDataByItem(this.curItem) : null
    if (sheetData) {
      this.curTab = sheetData.tab
      this.shouldSetPageByItem = true
    }
    else if (this.curTab < 0)
      this.curTab = 0

    this.curSheet = sheetData ? sheetData.sheet
      : this.curSheet ? sheets.findSheet(this.curSheet, sheets.ALL) 
      : this.sheetsArray.findvalue((@(s) s.isEnabled(this.curTab)).bindenv(this))
    this.initSubsetId = sheetData ? sheetData.subsetId : this.initSubsetId

    this.fillTabs()

    this.scene.findObject("update_timer").setUserData(this)
    if (showConsoleButtons.value)
      this.scene.findObject("mouse_timer").setUserData(this)

    this.hoverHoldAction = mkHoverHoldAction(this.scene.findObject("hover_hold_timer"))

    
    
    let checkIsInMenu = isInMenu.get() || hasFeature("devItemShop")
    let checkEnableShop = checkIsInMenu && hasFeature("ItemsShop")
    if (!checkEnableShop)
      this.scene.findObject("wnd_title").setValue(loc(getNameByTabIdx(itemsTab.INVENTORY)))

    show_obj(this.getTabsListObj(), checkEnableShop)
    show_obj(this.getSheetsListObj(), isInMenu.get())
    showObjById("sorting_block", false, this.scene)

    this.updateWarbondsBalance()
    this.moveMouseToMainList()

    if(this.isCraftTreeWndOpen)
      this.openCraftTree(this.craftTreeItem)
  }

  function reinitScreen(params = {}) {
    this.setParams(params)
    this.initScreen()
  }

  focusSheetsList = @() move_mouse_on_child_by_value(this.getSheetsListObj())

  function initNavigation() {
    if (this.navigationHandlerWeak)
      return

    let handler = handlersManager.loadHandler(
      gui_handlers.navigationPanel,
      { scene                  = this.scene.findObject("control_navigation")
        onSelectCb             = Callback(this.doNavigateToSection, this)
        onClickCb              = Callback(this.onNavItemClickCb, this)
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

    let newSheet = this.sheetsArray?[obj.shIdx]
    if (!newSheet)
      return

    this.isItemTypeChangeUpdate = true  
    this.curSheet = newSheet
    this.itemsListValid = false

    if (obj?.subsetId) {
      this.subsetList = this.curSheet.getSubsetsListParameters().subsetList
      this.curSubsetId = this.initSubsetId ?? obj.subsetId
      this.initSubsetId = null
      this.curSheet.setSubset(this.curSubsetId)
    }

    this.isItemTypeChangeUpdate = false
    if (!this.isSheetsInUpdate)
      this.applyFilters()
  }

  function onNavItemClickCb(obj) {
    if (!obj?.isCollapsable || !this.navigationHandlerWeak)
      return

    let collapseBtnObj = this.scene.findObject($"btn_nav_{obj.idx}")
    let subsetId = this.curSubsetId
    this.navigationHandlerWeak.onCollapse(collapseBtnObj)
    if (collapseBtnObj.getParent().collapsed == "no")
      this.getSheetsListObj().setValue( 
        u.search(this.navItems, @(item) item?.subsetId == subsetId)?.idx ?? obj.idx)
  }

  isTabVisible = @(tabIdx) (tabIdx != itemsTab.WORKSHOP || workshop.isAvailable())
    && (tabIdx != itemsTab.RECYCLING || hasFeature("RecycleItemShop"))
  getTabSeenList = @(tabIdx) seenList.get(getSeenIdByTabIdx(tabIdx))

  function fillTabs() {
    this.visibleTabs = []
    for (local i = 0; i < itemsTab.TOTAL; i++)
      if (this.isTabVisible(i))
        this.visibleTabs.append(i)

    let view = {
      tabs = []
    }
    local selIdx = -1
    foreach (idx, tabIdx in this.visibleTabs) {
      view.tabs.append({
        tabName = loc(getNameByTabIdx(tabIdx))
        unseenIcon = getSeenIdByTabIdx(tabIdx)
        navImagesText = getNavigationImagesText(idx, this.visibleTabs.len())
      })
      if (tabIdx == this.curTab)
        selIdx = idx
    }
    if (selIdx < 0) {
      selIdx = 0
      this.curTab = this.visibleTabs[selIdx]
    }

    let data = handyman.renderCached("%gui/frameHeaderTabs.tpl", view)
    let tabsObj = this.getTabsListObj()
    this.guiScene.replaceContentFromText(tabsObj, data, data.len(), this)
    tabsObj.setValue(selIdx)
  }

  function onTabChange() {
    this.tabHasChanged = true
    this.markCurrentPageSeen()

    let value = this.getTabsListObj().getValue()
    this.curTab = this.visibleTabs?[value] ?? this.curTab

    this.itemsListValid = false
    this.updateSheets()
  }

  function initSheetsOnce() {
    if (this.sheetsArray && this.sheetsArray.len())
      return

    this.sheetsArray = this.displayItemTypes ?
        sheets.types.filter(function(sh) {
            return isInArray(sh.id, this.displayItemTypes)
          }.bindenv(this))
      : sheets.types

    local count = 0
    this.navItems = []
    foreach (idx, sh in this.sheetsArray) {
      let isCollapsable = sh.hasSubLists()
      let item = {
        shIdx = idx
        unseenIcon = SEEN.ITEMS_SHOP
        unseenIconId = "unseen_icon"
      }
      this.navItems.append(item.__merge({
        idx = count++
        text = loc(sh.locId)
        isCollapsable = isCollapsable
        isHeader = true
        }))
      if (isCollapsable)
        foreach (param in sh.getSubsetsListParameters().subsetList)
          this.navItems.append(item.__merge({
            idx = count++
            text = loc(param.locId)
            subsetId = param.id
          }))
    }

    if (this.navigationHandlerWeak)
      this.navigationHandlerWeak.setNavItems(this.navItems)
  }

  function updateSheets(resetPage = true) {
    this.isSheetsInUpdate = true 
    this.guiScene.setUpdatesEnabled(false, false)
    this.initSheetsOnce()

    let typesObj = this.getSheetsListObj() 
    let seenListId = getSeenIdByTabIdx(this.curTab)
    local curValue = -1
    let childsTotal = typesObj.childrenCount()

    if (childsTotal < this.navItems.len()) {
      let navItemsTotal = this.navItems.len() 
      script_net_assert_once("Bad count on update unseen tabs",
        "ItemsShop: Not all sheets exist on update sheets list unseen icon")
    }

    foreach (idx, item in this.navItems) {
      if (idx >= childsTotal)
        break

      let sh = this.sheetsArray[item.shIdx]
      let isEnabled = sh.isEnabled(this.curTab)
      let child = typesObj.getChild(idx)
      child.show(isEnabled)
      child.enable(isEnabled)

      if (!isEnabled)
        continue

      if ((curValue < 0 || this.curSheet == sh) && !item?.isCollapsable)
        curValue = idx

      child.findObject("unseen_icon").setValue(bhvUnseen.makeConfigStr(seenListId,
        item?.subsetId ? sh.getSubsetSeenListId(item.subsetId) : sh.getSeenId()))
    }

    if (curValue >= 0)
      typesObj.setValue(curValue)

    this.guiScene.setUpdatesEnabled(true, true)
    this.isSheetsInUpdate = false

    this.applyFilters(resetPage)
  }

  function onEventWorkshopAvailableChanged(_p) {
    if (this.curTab == itemsTab.WORKSHOP)
      this.updateSheets()
  }

  function onNavCollapseCb (isCollapsed) {
    this.isNavCollapsed = isCollapsed
    this.applyFilters()
  }

  function initRecyclingControls() {
    if (this.scene.findObject("recycling_controls"))
      return
    let place = this.scene.findObject("recycling_controls_place")
    this.guiScene.replaceContent(place, "%gui/items/itemsRecyclingControls.blk", this)
  }

  function initItemsListSizeOnce() {
    let listObj = this.getItemsListObj()
    let emptyListObj = this.scene.findObject("empty_items_list")
    let infoObj = this.scene.findObject("item_info_nest")
    let collapseBtnWidth = $"1@cIco+2*({this.headerOffsetX})"
    let leftPos = this.isNavCollapsed ? collapseBtnWidth : "0"
    let nawWidth = this.isNavCollapsed ? "0" : "1@defaultNavPanelWidth"
    let itemHeightWithSpace = !this.isInRecyclingTab() ? "1@itemHeight+1@itemSpacing"
      : "1@itemHeight+1@itemWithRecyclingSpacingY"
    let itemWidthWithSpace = "1@itemWidth+1@itemSpacing"
    let mainBlockHeight = "@rh-2@frameHeaderHeight-1@frameFooterHeight-1@bottomMenuPanelHeight-1@blockInterval"
    let itemsCountX = max(to_pixels($"@rw-1@shopInfoMinWidth-({leftPos})-({nawWidth})")
      / max(1, to_pixels(itemWidthWithSpace)), 1)
    let contentWidth = $"{itemsCountX}*({itemWidthWithSpace})+1@itemSpacing"
    let contentPlaceX = $"0.5({contentWidth})-0.5w+{leftPos}+{nawWidth}"
    this.scene.findObject("main_block").height = mainBlockHeight
    this.scene.findObject("paginator_place").left = contentPlaceX
    listObj.width = contentWidth
    listObj.left = leftPos
    emptyListObj.width = contentWidth
    emptyListObj.left = leftPos
    infoObj.left = leftPos
    infoObj.width = "fw"

    local itemsListHeight = to_pixels(mainBlockHeight)

    if (this.isInRecyclingTab()) {
      let createItemsDescObj = this.scene.findObject("create_items_desc_with_count_txt")
      if (createItemsDescObj.getValue() == "") 
        createItemsDescObj.setValue(loc("items/recycling/descWithNumberOfRecycledItems",
          { unusedItemsCount = 0, maxNewItemsCount = 0 }))

      let recyclingControlsObj = this.scene.findObject("recycling_controls")
      recyclingControlsObj.width = $"{contentWidth}-2@blockInterval"
      recyclingControlsObj.pos = $"{contentPlaceX}, -h"

      this.guiScene.applyPendingChanges(false)

      let recyclingControlsHeight = recyclingControlsObj.getSize()[1]
      itemsListHeight -= recyclingControlsHeight
    }

    let itemsCountY = max(itemsListHeight
      / max(1, to_pixels(itemHeightWithSpace)), 1)
    this.itemsPerPage = (itemsCountX * itemsCountY).tointeger()
  }

  function applyFilters(resetPage = true) {
    this.scene.findObject("recycling_controls").show(this.isInRecyclingTab())

    this.initItemsListSizeOnce()

    let lastPage = this.curPage
    let lastItemsList = this.itemsList
    if (!this.itemsListValid) {
      this.itemsListValid = true
      this.itemsList = this.curSheet.getItemsList(this.curTab, this.curSubsetId)
      if (this.curTab == itemsTab.INVENTORY || this.isInRecyclingTab())
        this.itemsList.sort(getItemsSortComparator(this.getTabSeenList(this.curTab)))
    }

    if (resetPage && !this.shouldSetPageByItem)
      this.curPage = 0
    else {
      this.shouldSetPageByItem = false
      let lastIdx = this.getLastSelItemIdx()
      if (lastIdx >= 0)
        this.curPage = (lastIdx / this.itemsPerPage).tointeger()
      else if (this.curPage * this.itemsPerPage > this.itemsList.len())
        this.curPage = max(0, ((this.itemsList.len() - 1) / this.itemsPerPage).tointeger())
    }

    if (!this.tabHasChanged && lastPage == this.curPage && isEqualItemsLists(lastItemsList, this.itemsList))
      return

    this.fillPage()
  }

  function fillPage() {
    this.tabHasChanged = false
    this.currentSelectedId = -1
    this.currentHoveredItemId = -1
    let view = { items = [], canRecycle = this.isInRecyclingTab() }
    let pageStartIndex = this.curPage * this.itemsPerPage
    let pageEndIndex = min((this.curPage + 1) * this.itemsPerPage, this.itemsList.len())
    let seenListId = getSeenIdByTabIdx(this.curTab)
    let craftTree = this.curSheet?.getSet().getCraftTree()

    for (local i = pageStartIndex; i < pageEndIndex; i++) {
      let item = this.itemsList[i]
      if (item.hasLimits())
        enqueueItem(item.id)

      view.items.append(item.getViewData({
        showAction = !this.isInRecyclingTab(),
        itemIndex = i.tostring(),
        showSellAmount = this.curTab == itemsTab.SHOP,
        unseenIcon = bhvUnseen.makeConfigStr(seenListId, item.getSeenId())
        isUnseenAlarmIcon = item?.needUnseenAlarmIcon()
        isItemLocked = this.isItemLocked(item)
        showButtonInactiveIfNeed = true
        skipFocusBorderOrder = true
        overrideMainActionData = craftTree != null && item.canCraftOnlyInCraftTree()
          ? {
            isInactive = false
            btnName = loc(craftTree?.openButtonLocId ?? "")
            needShowActionButtonAlways = false
          }
          : null
        showTooltip = this.isMouseMode
        onHover = "onItemHover"
      }))
    }
    requestLimits()

    let listObj = this.getItemsListObj()
    let prevValue = listObj.getValue()
    let data = handyman.renderCached(("%gui/items/item.tpl"), view)
    if (checkObj(listObj)) {
      listObj.show(data != "")
      listObj.enable(data != "")
      this.guiScene.replaceContentFromText(listObj, data, data.len(), this)
    }

    let emptyListObj = this.scene.findObject("empty_items_list")
    if (checkObj(emptyListObj)) {
      let adviseMarketplace = this.curTab == itemsTab.INVENTORY && this.curSheet.isMarketplace && isMarketplaceEnabled()
      let itemsInShop = this.curTab == itemsTab.SHOP ? this.itemsList : this.curSheet.getItemsList(itemsTab.SHOP, this.curSubsetId)
      let adviseShop = hasFeature("ItemsShop") && this.curTab != itemsTab.SHOP
        && !this.isInRecyclingTab() && !adviseMarketplace && itemsInShop.len() > 0

      emptyListObj.show(data.len() == 0)
      emptyListObj.enable(data.len() == 0)
      showObjById("items_shop_to_marketplace_button", adviseMarketplace, this.scene)
      showObjById("items_shop_to_shop_button", adviseShop, this.scene)
      let emptyListTextObj = this.scene.findObject("empty_items_list_text")
      if (checkObj(emptyListTextObj)) {
        local caption = loc(this.curSheet.emptyTabLocId, "")
        if (!caption.len())
          caption = loc("items/shop/emptyTab/default")
        if (caption.len() > 0) {
          let noItemsAdviceLocId =
              adviseMarketplace ? "items/shop/emptyTab/noItemsAdvice/marketplaceEnabled"
            : adviseShop        ? "items/shop/emptyTab/noItemsAdvice/shopEnabled"
            :                     "items/shop/emptyTab/noItemsAdvice/shopDisabled"
          caption = " ".concat(caption, loc(noItemsAdviceLocId))
        }
        if (this.isInRecyclingTab())
          caption = loc("items/recycling/emptyTab")
        emptyListTextObj.setValue(caption)
      }
    }

    let value = this.findLastValue(prevValue)
    if (value >= 0)
      listObj.setValue(value)
    else
      this.updateItemInfo()

    generatePaginator(this.scene.findObject("paginator_place"), this,
      this.curPage, ceil(this.itemsList.len().tofloat() / this.itemsPerPage) - 1, null, true  )

    if (!this.itemsList.len())
      this.focusSheetsList()

    if (this.isInRecyclingTab()) {
      this.recycler = this.recycler ?? ItemsRecycler()
      this.updateCreateNewItemsTxtAndControls()
      this.updateRecycleButton()
      this.updateItemsToRecycleSliders()
      listObj.isSkipMoving = "yes" 
    } else {
      this.recycler = null
      listObj.isSkipMoving = "no"
    }
  }

  function isItemLocked(_item) {
    return false
  }

  function isLastItemSame(item) {
    if (!this.curItem || this.curItem.id != item.id)
      return false
    if (!this.curItem.uids || !item.uids)
      return true
    foreach (uid in this.curItem.uids)
      if (isInArray(uid, item.uids))
        return true
    return false
  }

  function findLastValue(prevValue) {
    let offset = this.curPage * this.itemsPerPage
    let total = clamp(this.itemsList.len() - offset, 0, this.itemsPerPage)
    if (!total)
      return -1

    local res = clamp(prevValue, 0, total - 1)
    if (this.curItem)
      for (local i = 0; i < total; i++) {
        let item = this.itemsList[offset + i]
        if (this.curItem.id != item.id)
          continue
        res = i
        if (this.isLastItemSame(item))
          break
      }
    return res
  }

  function getLastSelItemIdx() {
    local res = -1
    if (!this.curItem)
      return res

    foreach (idx, item in this.itemsList)
      if (this.curItem.id == item.id) {
        res = idx
        if (this.isLastItemSame(item))
          break
      }
    return res
  }

  function onEventInventoryUpdate(_p) {
    this.doWhenActiveOnce("updateInventoryItemsList")
    if (this.isInRecyclingTab()) {
      this.recycler.updateCraftParts()
      this.doWhenActiveOnce("updateCreateNewItemsTxtAndControls")
      this.doWhenActiveOnce("disableRecyclingItemsControls")
    }
  }

  function onEventItemsShopUpdate(_p) {
    this.doWhenActiveOnce("updateItemsList")
  }

  function onEventUnitBought(_params) {
    this.updateItemInfo()
  }

  function onEventUnitRented(_params) {
    this.updateItemInfo()
  }

  function onEventRecyclingItemsStart(_params) {
    this.disableRecyclingItemsControls()
  }

  moveMouseToMainList = @() move_mouse_on_child_by_value(this.getItemsListObj())

  function getItemIndexByList() {
    let obj = this.getItemsListObj()
    if (!checkObj(obj))
      return -1
    let listIndex = obj.getValue()
    return listIndex >= 0
      ? listIndex + this.curPage * this.itemsPerPage
      : -1
  }

  function getCurItem() {
    return this.itemsList?[this.getItemIndexByList()]
  }

  function getCurItemObj() {
    let itemListObj = this.getItemsListObj()
    let value = getObjValidIndex(itemListObj)
    if (value < 0)
      return null

    return itemListObj.getChild(value)
  }

  function goToPage(obj) {
    this.markCurrentPageSeen()
    this.curPage = obj.to_page.tointeger()
    this.fillPage()
  }

  function updateItemsList() {
    this.itemsListValid = false
    this.applyFilters(false)
  }

  function updateItemInfo() {
    this.currentSelectedId = this.getItemIndexByList()
    let item = this.getCurItem()
    this.markItemSeen(item)
    this.infoHandler?.updateHandlerData(item, true, true)
    showObjById("jumpToDescPanel", showConsoleButtons.value && item != null, this.scene)
    this.updateButtons()
  }

  function markItemSeen(item) {
    if (item)
      this.getTabSeenList(this.curTab).markSeen(item.getSeenId())
  }

  function markCurrentPageSeen() {
    if (!this.itemsList)
      return

    let pageStartIndex = this.curPage * this.itemsPerPage
    let pageEndIndex = min((this.curPage + 1) * this.itemsPerPage, this.itemsList.len())
    let list = []
    for (local i = pageStartIndex; i < pageEndIndex; ++i)
      list.append(this.itemsList[i].getSeenId())
    this.getTabSeenList(this.curTab).markSeen(list)
  }

  function updateButtonsBar() {
    let obj = this.getItemsListObj()
    let isButtonsVisible = this.isMouseMode || (checkObj(obj) && obj.isHovered())
    showObjById("item_actions_bar", isButtonsVisible, this.scene)
    return isButtonsVisible
  }

  function updateButtons() {
    let item = this.getCurItem()
    let mainActionData = item?.getMainActionData()
    let limitsCheckData = item?.getLimitsCheckData()
    let btnStyle = mainActionData?.btnStyle
    let limitsCheckResult = limitsCheckData?.result ?? true
    let showMainAction = mainActionData && limitsCheckResult && !this.isInRecyclingTab()
    let curSet = this.curSheet?.getSet()
    let craftTree = curSet?.getCraftTree()
    let needShowCraftTree = craftTree != null
    let openCraftTreeBtnText = loc(craftTree?.openButtonLocId ?? "")

    let craftTreeBtnObj = showObjById("btn_open_craft_tree", needShowCraftTree, this.scene)
    if (curSet != null && needShowCraftTree) {
      craftTreeBtnObj.setValue(openCraftTreeBtnText)
      let tutorialItem = curSet.findTutorialItem()
      if (tutorialItem)
        this.startCraftTutorial(curSet, tutorialItem, craftTreeBtnObj)
    }

    if (!this.updateButtonsBar()) 
      return

    let buttonObj = showObjById("btn_main_action", showMainAction, this.scene)
    let canCraftOnlyInCraftTree = needShowCraftTree && (item?.canCraftOnlyInCraftTree() ?? false)
    if (showMainAction) {
      buttonObj.visualStyle = btnStyle != null ? btnStyle
        : this.curTab == itemsTab.INVENTORY ? "secondary"
        : "purchase"
      buttonObj.inactiveColor = mainActionData?.isInactive && !canCraftOnlyInCraftTree ? "yes" : "no"
      let btnText = canCraftOnlyInCraftTree ? openCraftTreeBtnText : mainActionData.btnName
      let btnColoredText = canCraftOnlyInCraftTree
        ? openCraftTreeBtnText
        : mainActionData?.btnColoredName ?? mainActionData.btnName
      setDoubleTextToButton(this.scene, "btn_main_action", btnText, btnColoredText)

      let { needCrossedOldPrice = false } = mainActionData
      let redLine = showObjById("redLine", needCrossedOldPrice, this.scene)
      if (needCrossedOldPrice) {
        redLine.width = mainActionData.realCostNoTagsLength
        redLine["pos"] = mainActionData.redLinePos
      }
    }

    let activateText = (!showMainAction && item?.isInventoryItem
      && item.amount && !this.isInRecyclingTab()) ? item.getActivateInfo() : ""
    this.scene.findObject("activate_info_text").setValue(activateText)
    showObjById("btn_preview", item ? (item.canPreview() && isInMenu.get()) : false, this.scene)

    let altActionText = item?.getAltActionName({
      canRunCustomMission = !showMainAction
        || canCraftOnlyInCraftTree
        || !(mainActionData?.isRunCustomMission ?? false)
      canConsume = canCraftOnlyInCraftTree
    }) ?? ""
    showObjById("btn_alt_action", altActionText != "", this.scene)
    setColoredDoubleTextToButton(this.scene, "btn_alt_action", altActionText)

    local warningText = ""
    if (!limitsCheckResult && item && !item.isInventoryItem)
      warningText = limitsCheckData.reason
    this.setWarningText(warningText)

    let showLinkAction = item && item.hasLink()
    let linkObj = showObjById("btn_link_action", showLinkAction, this.scene)
    if (showLinkAction) {
      let linkActionText = loc(item.linkActionLocId)
      setDoubleTextToButton(this.scene, "btn_link_action", linkActionText, linkActionText)
      if (item.linkActionIcon != "") {
        linkObj["class"] = "image"
        linkObj.findObject("img")["background-image"] = item.linkActionIcon
      }
    }
  }

  function onRecycle() {
    this.recycler.recycleSelectedItems()
    this.updateRecycleButton()
  }

  function onCreateItems() {
    let sliderObj = this.scene.findObject("select_amount_slider_create_items")
    let amount = sliderObj.getValue()

    this.recycler.craftNewItems(amount)
    sliderObj.setValue(0)
  }

  function disableRecyclingItemsControls() {
    if (!this.recycler.recyclingItemsIds)
      return
    foreach (itemId, _amount in this.recycler.recyclingItemsIds) {
      let idx = this.getItemIndexByRecyclingKey(itemId)
      let itemCont = this.scene.findObject($"shop_item_cont_{idx}")
      if (itemCont)
        itemCont.disabled = "yes"
    }
  }

  function onItemRecycleAmountChange(sliderObj) {
    let idx = sliderObj.holderId.tointeger()
    let amount = sliderObj.getValue()
    let item = this.itemsList[idx]
    let itemsListObj = this.getItemsListObj()

    if (itemsListObj.getValue() != idx)
      itemsListObj.setValue(idx)

    this.recycler.selectItemToRecycle(item, amount)
    this.updateRecycleButton()
    this.updateSelectAmountTextAndButtons(sliderObj)
  }

  function onCreateItemsAmountChange(obj) {
    let val = obj.getValue()
    let createItemsBtnValTxt = val > 0 ? $"({val})" : ""
    let createItemsBtnTxt = " ".concat(loc("items/recycling/createItems"), createItemsBtnValTxt)
    let createItemsBtnObj = this.scene.findObject("create_items_btn")

    createItemsBtnObj.setValue(createItemsBtnTxt)
    createItemsBtnObj.enable(val > 0)
    this.updateSelectAmountTextAndButtons(obj)
  }

  function updateSelectAmountTextAndButtons(sliderObj) {
    let val = sliderObj.getValue()
    let { holderId, maxvalue } = sliderObj

    this.scene.findObject($"select_amount_value_txt_{holderId}").setValue($"{val}/{maxvalue}")
    enableObjsByTable(this.scene, {
      [$"select_amount_btn_dec_{holderId}"] = val > 0,
      [$"select_amount_btn_inc_{holderId}"] = val < maxvalue.tointeger()
    })
  }

  function updateCreateNewItemsTxtAndControls() {
    let unusedItemsCount = this.recycler.craftPartsCount
    let maxNewItemsCount = unusedItemsCount / CRAFT_PART_TO_NEW_ITEM_RATIO
    let txt = loc("items/recycling/descWithNumberOfRecycledItems",
      { unusedItemsCount, maxNewItemsCount })
    let createItemsSliderObj = this.scene.findObject("select_amount_slider_create_items")

    this.scene.findObject("create_items_desc_with_count_txt").setValue(txt)

    createItemsSliderObj.maxvalue = min(unusedItemsCount / CRAFT_PART_TO_NEW_ITEM_RATIO, MAXIMUM_CRAFTS_AT_ONCE_TIME)
    this.updateSelectAmountTextAndButtons(createItemsSliderObj)
  }

  function updateRecycleButton() {
    let count = this.recycler.selectedItemsToRecycleCount
    let itemsCountTxt = count > 0 ? $"({count})" : ""
    let recycleBtnObj = this.scene.findObject("recycle_btn")

    recycleBtnObj.setValue(" ".concat(loc("items/recycling/recycle"), itemsCountTxt))
    recycleBtnObj.inactiveColor = (count > 0) ? "no" : "yes"
  }

  function updateItemsToRecycleSliders() {
    foreach (k, sel in this.recycler.selectedItemsToRecycle) {
      let idx = this.getItemIndexByRecyclingKey(k)
      let sliderObj = this.scene.findObject($"select_amount_slider_{idx}")
      if (sliderObj?.isValid())
        sliderObj.setValue(sel.amount)
    }
  }

  onAmountSliderBtnDec = @(obj) this.increaseSliderValByDelta(obj, -1)
  onAmountSliderBtnInc = @(obj) this.increaseSliderValByDelta(obj, 1)
  function increaseSliderValByDelta(obj, delta) {
    let holderId = obj?.holderId
    let sliderObj = this.scene.findObject($"select_amount_slider_{holderId}")
    let curVal = sliderObj.getValue()
    sliderObj.setValue(curVal + delta)
  }

  function onLinkAction(_obj) {
    let item = this.getCurItem()
    if (item)
      item.openLink()
  }

  function onItemPreview(_obj) {
    if (!this.isValid())
      return

    let item = this.getCurItem()
    if (item && canStartPreviewScene(true, true))
      item.doPreview()
  }

  function onItemAction(buttonObj) {
    let id = to_integer_safe(buttonObj?.holderId, -1)
    let item = this.itemsList?[id]
    let obj = this.scene.findObject($"shop_item_{id}")

    
    
    
    let listObj = this.getItemsListObj()
    if (listObj.getValue() != id && id >= 0 && id < listObj.childrenCount())
      listObj.setValue(id)

    this.doMainAction(item, obj)
  }

  function onMainAction(_obj) {
    this.doMainAction()
  }

  function doMainAction(item = null, obj = null) {
    item = item || this.getCurItem()
    if (item == null)
      return

    obj = obj || this.getCurItemObj()
    if (item.canCraftOnlyInCraftTree() && this.curSheet?.getSet().getCraftTree() != null)
      this.openCraftTree(item)
    else {
      let prevActiveStatus = item.isActive()
      let callBackFn = Callback(function() {
        let updateFn = item?.needUpdateListAfterAction || item.isActive() != prevActiveStatus ? this.updateItemsList
          : this.updateItemInfo
        updateFn()
      }, this)
      item.doMainAction(@(_result) defer(@() callBackFn()), this, { obj = obj })
    }

    this.markItemSeen(item)
  }

  function onAltAction(obj) {
    let item = this.getCurItem()
    if (!item)
      return

    let hasCraftTree = this.curSheet?.getSet().getCraftTree() != null
    let canCraftOnlyInCraftTree = hasCraftTree && (item.canCraftOnlyInCraftTree() ?? false)

    item.doAltAction({
      obj,
      canConsume = canCraftOnlyInCraftTree,
      canRunCustomMission = canCraftOnlyInCraftTree
        || !(item.getLimitsCheckData()?.result ?? true)
        || !(item.getMainActionData()?.isRunCustomMission ?? false)
      align = "top"
    })
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

  function onTimer(_obj, _dt) {
    if (!this.itemsListValid)
      return

    let listObj = this.getItemsListObj()
    if (!listObj?.isValid())
      return

    let listObjChildrenCount = listObj.childrenCount()
    let startIdx = this.curPage * this.itemsPerPage
    let lastIdx = min((this.curPage + 1) * this.itemsPerPage, this.itemsList.len())
    for (local i = startIdx; i < lastIdx; i++) {
      let item = this.itemsList[i]

      if (this.curTab == itemsTab.SHOP && item?.isExpired()) {
        this.updateItemsList()
        return
      }

      if (!item.hasTimer() && !item?.hasLifetimeTimer())
        continue

      let childIdx = i - this.curPage * this.itemsPerPage
      if (childIdx >= listObjChildrenCount)
        continue

      let itemObj = listObj.getChild(childIdx)
      if (!itemObj.isValid())
        continue

      local timeTxtObj = itemObj.findObject("expire_time")
      if (checkObj(timeTxtObj))
        timeTxtObj.setValue(item.getTimeLeftText())

      timeTxtObj = itemObj.findObject("craft_time")
      if (checkObj(timeTxtObj))
        timeTxtObj.setValue(item.getCraftTimeTextShort())

      timeTxtObj = itemObj.findObject("remaining_lifetime")
      if (timeTxtObj?.isValid())
        timeTxtObj.setValue(item.getRemainingLifetimeText())

      updateExpireAlarmIcon(item, itemObj)
    }

    let selItem = this.getCurItem()
    if (selItem?.hasTimer())
      fillDescTextAboutDiv(selItem, this.infoHandler.scene)

    if (selItem?.hasLifetimeTimer())
      fillItemDescUnderTable(selItem, this.infoHandler.scene)
  }

  function onToShopButton(_obj) {
    this.curTab = itemsTab.SHOP
    this.fillTabs()
  }

  function onToMarketplaceButton(_obj) {
    goToMarketplace()
  }

  function goBack() {
    this.markCurrentPageSeen()
    base.goBack()
  }

  function getItemsListObj() {
    return this.scene.findObject("items_list")
  }

  function getTabsListObj() {
    return this.scene.findObject("tabs_list")
  }

  function getSheetsListObj() {
    return this.scene.findObject("nav_list")
  }

  



  function getHandlerRestoreData() {
    let data = {
      openData = {
        curTab = this.curTab
        curSheet = this.curSheet
        isCraftTreeWndOpen = this.isCraftTreeWndOpen
        craftTreeItem  = this.craftTreeItem
      }
      stateData = {
        currentItemId = getTblValue("id", this.getCurItem(), null)
      }
    }
    return data
  }

  


  function getItemIndexById(itemId) {
    foreach (itemIndex, item in this.itemsList) {
      if (item.id == itemId)
        return itemIndex
    }
    return -1
  }

  getItemIndexByRecyclingKey = @(key) this.itemsList.findindex(@(item) getRecyclingItemUniqKey(item) == key) ?? -1

  function restoreHandler(stateData) {
    let itemIndex = this.getItemIndexById(stateData.currentItemId)
    if (itemIndex == -1)
      return
    this.curPage = ceil(itemIndex / this.itemsPerPage).tointeger()
    this.fillPage()
    this.getItemsListObj().setValue(itemIndex % this.itemsPerPage)
  }

  function onEventBeforeStartShowroom(_params) {
    handlersManager.requestHandlerRestore(this, gui_handlers.MainMenu)
  }

  function onEventBeforeStartTestFlight(_params) {
    handlersManager.requestHandlerRestore(this, gui_handlers.MainMenu)
  }

  function onEventItemLimitsUpdated(_params) {
    this.updateItemInfo()
  }

  function onEventDiscountsDataUpdated(_params) {
    this.fillPage()
  }

  function onEventUpdateTrophiesVisibility(_) {
    if (this.curTab != itemsTab.SHOP)
      return

    this.itemsListValid = false
    this.updateSheets(false)
  }

  function onEventUpdateTrophyUnseenIcons(_) {
    if (this.curTab != itemsTab.SHOP)
      return

    this.applyFilters(false)
  }

  function setWarningText(text) {
    let warningTextObj = this.scene.findObject("warning_text")
    if (checkObj(warningTextObj))
      warningTextObj.setValue(colorize("redMenuButtonColor", text))
  }

  function onEventActiveHandlersChanged(_p) {
    let needBlackScreen = handlersManager.findHandlerClassInScene(gui_handlers.trophyRewardWnd) != null
      || handlersManager.findHandlerClassInScene(gui_handlers.recycleCompleteWnd) != null
    showObjById("black_screen", needBlackScreen, this.scene)
  }

  function updateWarbondsBalance() {
    if (!hasFeature("Warbonds"))
      return

    let warbondsObj = this.scene.findObject("balance_text")
    warbondsObj.setValue(getWarbondsBalanceText())
    warbondsObj.tooltip = loc("warbonds/maxAmount", { warbonds = maxAllowedWarbondsBalance.get() })
  }

  function onEventProfileUpdated(_p) {
    this.doWhenActiveOnce("updateWarbondsBalance")
    this.doWhenActiveOnce("updateInventoryItemsList")
  }

  
  onChangeSortOrder = @(_obj) null
  onChangeSortParam = @(_obj) null
  onShowBattlePass = @(_obj) null

  function onEventBeforeStartCustomMission(_params) {
    handlersManager.requestHandlerRestore(this, gui_handlers.MainMenu)
  }

  function updateInventoryItemsList() {
    if (this.curTab != itemsTab.SHOP)
      this.updateItemsList()
  }

  function onItemsListFocusChange() {
    if (!this.isValid())
      return
    this.updateButtons()
    this.currentHoveredItemId = this.currentSelectedId
  }

  function onOpenCraftTree() {
    this.openCraftTree()
  }

  function openCraftTree(showItem = null, tutorialItem = null) {
    let curSet = this.curSheet?.getSet()
    if (curSet?.getCraftTree() == null)
      return

    workshopCraftTreeWnd.open({
      workshopSet = curSet
      showItemOnInit = showItem
      tutorialItem = tutorialItem
    })

    this.isCraftTreeWndOpen = true
    this.craftTreeItem = showItem
  }

  onShowSpecialTasks = @(_obj) null

  function startCraftTutorial(curSet, tutorialItem, craftTreeBtnObj) {
    curSet.saveTutorialWasShown()
    let steps = [{
      obj = [craftTreeBtnObj]
      text = loc("workshop/accentCraftTreeButton", {
        buttonName = loc(curSet.getCraftTree()?.openButtonLocId ?? "")
      })
      shortcut = GAMEPAD_ENTER_SHORTCUT
      actionType = tutorAction.OBJ_CLICK
      cb = @() this.openCraftTree(null, tutorialItem)
    }]
    gui_modal_tutor(steps, this, true)
  }

  function onItemHover(obj) {
    if (!showConsoleButtons.value)
      return
    let wasMouseMode = this.isMouseMode
    this.updateMouseMode()
    if (wasMouseMode != this.isMouseMode)
      this.updateShowItemButton()
    let id = obj.holderId.tointeger()
    this.currentHoveredItemId = obj.isHovered() ? id
      : this.currentHoveredItemId == id ? -1
      : this.currentHoveredItemId
  }

  function onHoverTimerUpdate(_obj, _dt) {
    if (this.isMouseMode || this.currentSelectedId == this.currentHoveredItemId || this.currentHoveredItemId == -1)
      return

    let mousePos = get_dagui_mouse_cursor_pos_RC()
    let mouseDelta = [mousePos[0] - this.lastMousePos[0], mousePos[1] - this.lastMousePos[1]]
    this.lastMousePos = mousePos

    if (mouseDelta[0] != 0 || mouseDelta[1] != 0) {
      this.lastMouseDelta = mouseDelta
      return
    }

    if (this.lastMouseDelta[0] == 0 && this.lastMouseDelta[1] == 0)
      return

    this.lastMouseDelta = mouseDelta
    let value = this.currentHoveredItemId - this.curPage * this.itemsPerPage
    let listObj = this.getItemsListObj()
    if (listObj.getValue() != value && value >= 0 && value < listObj.childrenCount())
      listObj.setValue(value)
    this.currentSelectedId = this.currentHoveredItemId
  }

  updateMouseMode = @() this.isMouseMode = !showConsoleButtons.value || is_mouse_last_time_used()
  function updateShowItemButton() {
    let listObj = this.getItemsListObj()
    if (listObj?.isValid())
      listObj.showItemButton = this.isMouseMode ? "yes" : "no"
  }

  function onEventModalWndDestroy(p) {
    base.onEventModalWndDestroy(p)
    if (this.isSceneActiveNoModals())
      this.isCraftTreeWndOpen = false
  }
}

function openItemsWndFromPromo(_owner, params = []) {
  local tab = itemsTab?[(params?[1] ?? "SHOP").toupper()] ?? itemsTab.INVENTORY
  local itemId = params?[3]

  let sheetSearchId = params?[0]
  let initSubsetId = params?[2]
  let curSheet = sheetSearchId ? { searchId = sheetSearchId } : null

  if (tab >= itemsTab.TOTAL)
    tab = itemsTab.INVENTORY

  itemId = to_integer_safe(itemId, itemId, false)
  let curItem = findItemById(itemId)

  gui_start_items_list(tab, { curSheet, initSubsetId, curItem, shouldSetPageByItem = curItem != null })
}

addPromoAction("items", @(handler, params, _obj) openItemsWndFromPromo(handler, params))
