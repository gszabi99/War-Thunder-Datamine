//-file:plus-string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { ceil } = require("math")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
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
let { isMarketplaceEnabled, goToMarketplace } = require("%scripts/items/itemsMarketplace.nut")
let { setBreadcrumbGoBackParams } = require("%scripts/breadcrumb.nut")
let { addPromoAction } = require("%scripts/promo/promoActions.nut")
let { fillDescTextAboutDiv, updateExpireAlarmIcon,
  fillItemDescUnderTable } = require("%scripts/items/itemVisual.nut")
let { needUseHangarDof } = require("%scripts/viewUtils/hangarDof.nut")

::gui_start_itemsShop <- function gui_start_itemsShop(params = null) {
  ::gui_start_items_list(itemsTab.SHOP, params)
}

::gui_start_inventory <- function gui_start_inventory(params = null) {
  ::gui_start_items_list(itemsTab.INVENTORY, params)
}

::gui_start_items_list <- function gui_start_items_list(curTab, params = null) {
  if (!::ItemsManager.isEnabled())
    return

  local handlerParams = { curTab = curTab }
  if (params != null)
    handlerParams = ::inherit_table(handlerParams, params)
  ::get_cur_gui_scene().performDelayed({},
    @() ::handlersManager.loadHandler(::gui_handlers.ItemsList, handlerParams))
}

::gui_handlers.ItemsList <- class extends ::gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.BASE
  sceneBlkName = "%gui/items/itemsShop.blk"
  shouldBlurSceneBgFn = needUseHangarDof

  curTab = 0 //first itemsTab
  visibleTabs = null //[]
  curSheet = null
  curItem = null //last selected item to restore selection after change list
  hoverHoldAction = null

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

  // Used to avoid expensive get...List and further sort.
  itemsListValid = false

  infoHandler = null
  isMouseMode = true

  function initScreen() {
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
      : this.curSheet ? sheets.findSheet(this.curSheet, sheets.ALL) //it can be simple table, need to find real sheeet by it
      : this.sheetsArray.findvalue((@(s) s.isEnabled(this.curTab)).bindenv(this))
    this.initSubsetId = sheetData ? sheetData.subsetId : this.initSubsetId

    this.fillTabs()

    this.scene.findObject("update_timer").setUserData(this)
    this.hoverHoldAction = mkHoverHoldAction(this.scene.findObject("hover_hold_timer"))

    // If items shop was opened not in menu - player should not
    // be able to navigate through sheets and tabs.
    let checkIsInMenu = ::isInMenu() || hasFeature("devItemShop")
    let checkEnableShop = checkIsInMenu && hasFeature("ItemsShop")
    if (!checkEnableShop)
      this.scene.findObject("wnd_title").setValue(loc(this.getTabName(itemsTab.INVENTORY)))

    ::show_obj(this.getTabsListObj(), checkEnableShop)
    ::show_obj(this.getSheetsListObj(), ::isInMenu)
    this.showSceneBtn("sorting_block", false)

    this.updateWarbondsBalance()
    this.moveMouseToMainList()
  }

  function reinitScreen(params = {}) {
    this.setParams(params)
    this.initScreen()
  }

  focusSheetsList = @() ::move_mouse_on_child_by_value(this.getSheetsListObj())

  function initNavigation() {
    if (this.navigationHandlerWeak)
      return

    let handler = ::handlersManager.loadHandler(
      ::gui_handlers.navigationPanel,
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

    this.isItemTypeChangeUpdate = true  //No need update item when fill subset if changed item type
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
      this.getSheetsListObj().setValue( //set selection on chapter item if not found item with subsetId just in case to avoid crash
        ::u.search(this.navItems, @(item) item?.subsetId == subsetId)?.idx ?? obj.idx)
  }

  function getTabName(tabIdx) {
    switch (tabIdx) {
      case itemsTab.SHOP:          return "items/shop"
      case itemsTab.INVENTORY:     return "items/inventory"
      case itemsTab.WORKSHOP:      return "items/workshop"
    }
    return ""
  }

  isTabVisible = @(tabIdx) tabIdx != itemsTab.WORKSHOP || workshop.isAvailable()
  getTabSeenList = @(tabIdx) seenList.get(this.getTabSeenId(tabIdx))

  function getTabSeenId(tabIdx) {
    switch (tabIdx) {
      case itemsTab.SHOP:          return SEEN.ITEMS_SHOP
      case itemsTab.INVENTORY:     return SEEN.INVENTORY
      case itemsTab.WORKSHOP:      return SEEN.WORKSHOP
    }
    return null
  }

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
        tabName = loc(this.getTabName(tabIdx))
        unseenIcon = this.getTabSeenId(tabIdx)
        navImagesText = ::get_navigation_images_text(idx, this.visibleTabs.len())
      })
      if (tabIdx == this.curTab)
        selIdx = idx
    }
    if (selIdx < 0) {
      selIdx = 0
      this.curTab = this.visibleTabs[selIdx]
    }

    let data = ::handyman.renderCached("%gui/frameHeaderTabs.tpl", view)
    let tabsObj = this.getTabsListObj()
    this.guiScene.replaceContentFromText(tabsObj, data, data.len(), this)
    tabsObj.setValue(selIdx)
  }

  function onTabChange() {
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
    this.isSheetsInUpdate = true //there can be multiple sheets changed on switch tab, so no need to update items several times.
    this.guiScene.setUpdatesEnabled(false, false)
    this.initSheetsOnce()

    let typesObj = this.getSheetsListObj() //!!FIX ME: Why we use object from navigation panel here?
    let seenListId = this.getTabSeenId(this.curTab)
    local curValue = -1
    let childsTotal = typesObj.childrenCount()

    if (childsTotal < this.navItems.len()) {
      let navItemsTotal = this.navItems.len() // warning disable: -declared-never-used
      ::script_net_assert_once("Bad count on update unseen tabs",
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

  function initItemsListSizeOnce() {
    let listObj = this.getItemsListObj()
    let emptyListObj = this.scene.findObject("empty_items_list")
    let infoObj = this.scene.findObject("item_info_nest")
    let collapseBtnWidth = $"1@cIco+2*({this.headerOffsetX})"
    let leftPos = this.isNavCollapsed ? collapseBtnWidth : "0"
    let nawWidth = this.isNavCollapsed ? "0" : "1@defaultNavPanelWidth"
    let itemHeightWithSpace = "1@itemHeight+1@itemSpacing"
    let itemWidthWithSpace = "1@itemWidth+1@itemSpacing"
    let mainBlockHeight = "@rh-2@frameHeaderHeight-1@frameFooterHeight-1@bottomMenuPanelHeight-1@blockInterval"
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

  function applyFilters(resetPage = true) {
    this.initItemsListSizeOnce()

    if (!this.itemsListValid) {
      this.itemsListValid = true
      this.itemsList = this.curSheet.getItemsList(this.curTab, this.curSubsetId)
      if (this.curTab == itemsTab.INVENTORY)
        this.itemsList.sort(::ItemsManager.getItemsSortComparator(this.getTabSeenList(this.curTab)))
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

    this.fillPage()
  }

  function fillPage() {
    let view = { items = [] }
    let pageStartIndex = this.curPage * this.itemsPerPage
    let pageEndIndex = min((this.curPage + 1) * this.itemsPerPage, this.itemsList.len())
    let seenListId = this.getTabSeenId(this.curTab)
    let craftTree = this.curSheet?.getSet().getCraftTree()
    for (local i = pageStartIndex; i < pageEndIndex; i++) {
      let item = this.itemsList[i]
      if (item.hasLimits())
        ::g_item_limits.enqueueItem(item.id)

      view.items.append(item.getViewData({
        itemIndex = i.tostring(),
        showSellAmount = this.curTab == itemsTab.SHOP,
        unseenIcon = bhvUnseen.makeConfigStr(seenListId, item.getSeenId())
        isUnseenAlarmIcon = item?.needUnseenAlarmIcon()
        isItemLocked = this.isItemLocked(item)
        showButtonInactiveIfNeed = true
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
    ::g_item_limits.requestLimits()

    let listObj = this.getItemsListObj()
    let prevValue = listObj.getValue()
    let data = ::handyman.renderCached(("%gui/items/item.tpl"), view)
    if (checkObj(listObj)) {
      listObj.show(data != "")
      listObj.enable(data != "")
      this.guiScene.replaceContentFromText(listObj, data, data.len(), this)
    }

    let emptyListObj = this.scene.findObject("empty_items_list")
    if (checkObj(emptyListObj)) {
      let adviseMarketplace = this.curTab == itemsTab.INVENTORY && this.curSheet.isMarketplace && isMarketplaceEnabled()
      let itemsInShop = this.curTab == itemsTab.SHOP ? this.itemsList : this.curSheet.getItemsList(itemsTab.SHOP, this.curSubsetId)
      let adviseShop = hasFeature("ItemsShop") && this.curTab != itemsTab.SHOP && !adviseMarketplace && itemsInShop.len() > 0

      emptyListObj.show(data.len() == 0)
      emptyListObj.enable(data.len() == 0)
      this.showSceneBtn("items_shop_to_marketplace_button", adviseMarketplace)
      this.showSceneBtn("items_shop_to_shop_button", adviseShop)
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
          caption += " " + loc(noItemsAdviceLocId)
        }
        emptyListTextObj.setValue(caption)
      }
    }

    let value = this.findLastValue(prevValue)
    if (value >= 0)
      listObj.setValue(value)

    this.updateItemInfo()

    ::generatePaginator(this.scene.findObject("paginator_place"), this,
      this.curPage, ceil(this.itemsList.len().tofloat() / this.itemsPerPage) - 1, null, true /*show last page*/ )

    if (!this.itemsList.len())
      this.focusSheetsList()
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

  moveMouseToMainList = @() ::move_mouse_on_child_by_value(this.getItemsListObj())

  function getCurItem() {
    let obj = this.getItemsListObj()
    if (!checkObj(obj))
      return null

    return this.itemsList?[obj.getValue() + this.curPage * this.itemsPerPage]
  }

  function getCurItemObj() {
    let itemListObj = this.getItemsListObj()
    let value = ::get_obj_valid_index(itemListObj)
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
    let item = this.getCurItem()
    this.markItemSeen(item)
    this.infoHandler?.updateHandlerData(item, true, true)
    this.showSceneBtn("jumpToDescPanel", ::show_console_buttons && item != null)
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
    this.showSceneBtn("item_actions_bar", isButtonsVisible)
    return isButtonsVisible
  }

  function updateButtons() {
    let item = this.getCurItem()
    let mainActionData = item?.getMainActionData()
    let limitsCheckData = item?.getLimitsCheckData()
    let limitsCheckResult = limitsCheckData?.result ?? true
    let showMainAction = mainActionData && limitsCheckResult
    let curSet = this.curSheet?.getSet()
    let craftTree = curSet?.getCraftTree()
    let needShowCraftTree = craftTree != null
    let openCraftTreeBtnText = loc(craftTree?.openButtonLocId ?? "")

    let craftTreeBtnObj = this.showSceneBtn("btn_open_craft_tree", needShowCraftTree)
    if (curSet != null && needShowCraftTree) {
      craftTreeBtnObj.setValue(openCraftTreeBtnText)
      let tutorialItem = curSet.findTutorialItem()
      if (tutorialItem)
        this.startCraftTutorial(curSet, tutorialItem, craftTreeBtnObj)
    }

    if (!this.updateButtonsBar()) //buttons below are hidden if item action bar is hidden
      return

    let buttonObj = this.showSceneBtn("btn_main_action", showMainAction)
    let canCraftOnlyInCraftTree = needShowCraftTree && (item?.canCraftOnlyInCraftTree() ?? false)
    if (showMainAction) {
      buttonObj.visualStyle = this.curTab == itemsTab.INVENTORY ? "secondary" : "purchase"
      buttonObj.inactiveColor = mainActionData?.isInactive && !canCraftOnlyInCraftTree ? "yes" : "no"
      let btnText = canCraftOnlyInCraftTree ? openCraftTreeBtnText : mainActionData.btnName
      let btnColoredText = canCraftOnlyInCraftTree
        ? openCraftTreeBtnText
        : mainActionData?.btnColoredName ?? mainActionData.btnName
      setDoubleTextToButton(this.scene, "btn_main_action", btnText, btnColoredText)
    }

    let activateText = !showMainAction && item?.isInventoryItem && item.amount ? item.getActivateInfo() : ""
    this.scene.findObject("activate_info_text").setValue(activateText)
    this.showSceneBtn("btn_preview", item ? (item.canPreview() && ::isInMenu()) : false)

    let altActionText = item?.getAltActionName({
      canRunCustomMission = !showMainAction
        || canCraftOnlyInCraftTree
        || !(mainActionData?.isRunCustomMission ?? false)
      canConsume = canCraftOnlyInCraftTree
    }) ?? ""
    this.showSceneBtn("btn_alt_action", altActionText != "")
    setColoredDoubleTextToButton(this.scene, "btn_alt_action", altActionText)

    local warningText = ""
    if (!limitsCheckResult && item && !item.isInventoryItem)
      warningText = limitsCheckData.reason
    this.setWarningText(warningText)

    let showLinkAction = item && item.hasLink()
    let linkObj = this.showSceneBtn("btn_link_action", showLinkAction)
    if (showLinkAction) {
      let linkActionText = loc(item.linkActionLocId)
      setDoubleTextToButton(this.scene, "btn_link_action", linkActionText, linkActionText)
      if (item.linkActionIcon != "") {
        linkObj["class"] = "image"
        linkObj.findObject("img")["background-image"] = item.linkActionIcon
      }
    }
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
    let id = ::to_integer_safe(buttonObj?.holderId, -1)
    let item = this.itemsList?[id]
    let obj = this.scene.findObject("shop_item_" + id)

    // Need to change list object current index because of
    // we can click on action button in non selected item
    // and wrong item will be updated after main action
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
      let updateFn = item?.needUpdateListAfterAction ? this.updateItemsList : this.updateItemInfo
      item.doMainAction(
        Callback(@(_result) updateFn(), this),
        this,
        { obj = obj })
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
    if (!::show_console_buttons)
      return
    let containerObj = this.scene.findObject("item_info")
    if (checkObj(containerObj) && containerObj.isHovered())
      ::move_mouse_on_obj(this.getCurItemObj())
    else
      ::move_mouse_on_obj(containerObj)
  }

  function onTimer(_obj, _dt) {
    if (!this.itemsListValid)
      return

    let listObj = this.getItemsListObj()
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

      let itemObj = checkObj(listObj) ? listObj.getChild(i - this.curPage * this.itemsPerPage) : null
      if (!checkObj(itemObj))
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

  /**
   * Returns all the data required to restore current window state:
   * curSheet, curTab, selected item, etc...
   */
  function getHandlerRestoreData() {
    let data = {
      openData = {
        curTab = this.curTab
        curSheet = this.curSheet
      }
      stateData = {
        currentItemId = getTblValue("id", this.getCurItem(), null)
      }
    }
    return data
  }

  /**
   * Returns -1 if item was not found.
   */
  function getItemIndexById(itemId) {
    foreach (itemIndex, item in this.itemsList) {
      if (item.id == itemId)
        return itemIndex
    }
    return -1
  }

  function restoreHandler(stateData) {
    let itemIndex = this.getItemIndexById(stateData.currentItemId)
    if (itemIndex == -1)
      return
    this.curPage = ceil(itemIndex / this.itemsPerPage).tointeger()
    this.fillPage()
    this.getItemsListObj().setValue(itemIndex % this.itemsPerPage)
  }

  function onEventBeforeStartShowroom(_params) {
    ::handlersManager.requestHandlerRestore(this, ::gui_handlers.MainMenu)
  }

  function onEventBeforeStartTestFlight(_params) {
    ::handlersManager.requestHandlerRestore(this, ::gui_handlers.MainMenu)
  }

  function onEventItemLimitsUpdated(_params) {
    this.updateItemInfo()
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
    this.showSceneBtn("black_screen", ::handlersManager.findHandlerClassInScene(::gui_handlers.trophyRewardWnd) != null)
  }

  function updateWarbondsBalance() {
    if (!hasFeature("Warbonds"))
      return

    let warbondsObj = this.scene.findObject("balance_text")
    warbondsObj.setValue(::g_warbonds.getBalanceText())
    warbondsObj.tooltip = loc("warbonds/maxAmount", { warbonds = ::g_warbonds.getLimit() })
  }

  function onEventProfileUpdated(_p) {
    this.doWhenActiveOnce("updateWarbondsBalance")
    this.doWhenActiveOnce("updateInventoryItemsList")
  }

  //dependence by blk
  onChangeSortOrder = @(_obj) null
  onChangeSortParam = @(_obj) null
  onShowBattlePass = @(_obj) null

  function onEventBeforeStartCustomMission(_params) {
    ::handlersManager.requestHandlerRestore(this, ::gui_handlers.MainMenu)
  }

  function updateInventoryItemsList() {
    if (this.curTab != itemsTab.SHOP)
      this.updateItemsList()
  }

  function onItemsListFocusChange() {
    if (this.isValid())
      this.updateButtons()
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
  }

  onShowSpecialTasks = @(_obj) null

  function startCraftTutorial(curSet, tutorialItem, craftTreeBtnObj) {
    curSet.saveTutorialWasShown()
    let steps = [{
      obj = [craftTreeBtnObj]
      text = loc("workshop/accentCraftTreeButton", {
        buttonName = loc(curSet.getCraftTree()?.openButtonLocId ?? "")
      })
      shortcut = ::GAMEPAD_ENTER_SHORTCUT
      actionType = tutorAction.OBJ_CLICK
      cb = @() this.openCraftTree(null, tutorialItem)
    }]
    ::gui_modal_tutor(steps, this, true)
  }

  function onItemHover(obj) {
    if (!::show_console_buttons)
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

  updateMouseMode = @() this.isMouseMode = !::show_console_buttons || ::is_mouse_last_time_used()
  function updateShowItemButton() {
    let listObj = this.getItemsListObj()
    if (listObj?.isValid())
      listObj.showItemButton = this.isMouseMode ? "yes" : "no"
  }
}

let function openItemsWndFromPromo(_owner, params = []) {
  local tab = getconsttable()?.itemsTab?[(params?[1] ?? "SHOP").toupper()] ?? itemsTab.INVENTORY
  local itemId = params?[3]

  let sheetSearchId = params?[0]
  let initSubsetId = params?[2]
  let curSheet = sheetSearchId ? { searchId = sheetSearchId } : null

  if (tab >= itemsTab.TOTAL)
    tab = itemsTab.INVENTORY

  itemId = ::to_integer_safe(itemId, itemId, false)
  let curItem = ::ItemsManager.findItemById(itemId)

  ::gui_start_items_list(tab, { curSheet, initSubsetId, curItem, shouldSetPageByItem = curItem != null })
}

addPromoAction("items", @(handler, params, _obj) openItemsWndFromPromo(handler, params))
