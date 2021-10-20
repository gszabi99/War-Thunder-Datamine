local sheets = require("scripts/items/itemsShopSheets.nut")
local itemInfoHandler = require("scripts/items/itemInfoHandler.nut")
local workshop = require("scripts/items/workshop/workshop.nut")
local seenList = require("scripts/seen/seenList.nut")
local bhvUnseen = require("scripts/seen/bhvUnseen.nut")
local workshopCraftTreeWnd = require("scripts/items/workshop/workshopCraftTreeWnd.nut")
local tutorAction = require("scripts/tutorials/tutorialActions.nut")
local { canStartPreviewScene } = require("scripts/customization/contentPreview.nut")
local { setDoubleTextToButton, setColoredDoubleTextToButton } = require("scripts/viewUtils/objectTextUpdate.nut")
local mkHoverHoldAction = require("sqDagui/timer/mkHoverHoldAction.nut")
local { isMarketplaceEnabled, goToMarketplace } = require("scripts/items/itemsMarketplace.nut")
local { setBreadcrumbGoBackParams } = require("scripts/breadcrumb.nut")
local { addPromoAction } = require("scripts/promo/promoActions.nut")
local { fillDescTextAboutDiv } = require("scripts/items/itemVisual.nut")
local { needUseHangarDof } = require("scripts/viewUtils/hangarDof.nut")

::gui_start_itemsShop <- function gui_start_itemsShop(params = null)
{
  ::gui_start_items_list(itemsTab.SHOP, params)
}

::gui_start_inventory <- function gui_start_inventory(params = null)
{
  ::gui_start_items_list(itemsTab.INVENTORY, params)
}

::gui_start_items_list <- function gui_start_items_list(curTab, params = null)
{
  if (!::ItemsManager.isEnabled())
    return

  local handlerParams = { curTab = curTab }
  if (params != null)
    handlerParams = ::inherit_table(handlerParams, params)
  ::get_cur_gui_scene().performDelayed({},
    @() ::handlersManager.loadHandler(::gui_handlers.ItemsList, handlerParams))
}

class ::gui_handlers.ItemsList extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.BASE
  sceneBlkName = "gui/items/itemsShop.blk"
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

  function initScreen()
  {
    setBreadcrumbGoBackParams(this)
    updateMouseMode()
    updateShowItemButton()
    infoHandler = itemInfoHandler(scene.findObject("item_info"))
    initNavigation()
    sheets.updateWorkshopSheets()
    initSheetsOnce()

    local sheetData = curTab < 0 && curItem ? sheets.getSheetDataByItem(curItem) : null
    if (sheetData)
    {
      curTab = sheetData.tab
      shouldSetPageByItem = true
    } else if (curTab < 0)
      curTab = 0

    curSheet = sheetData ? sheetData.sheet
      : curSheet ? sheets.findSheet(curSheet, sheets.ALL) //it can be simple table, need to find real sheeet by it
      : sheetsArray.findvalue((@(s) s.isEnabled(curTab)).bindenv(this))
    initSubsetId = sheetData ? sheetData.subsetId : initSubsetId

    fillTabs()

    scene.findObject("update_timer").setUserData(this)
    hoverHoldAction = mkHoverHoldAction(scene.findObject("hover_hold_timer"))

    // If items shop was opened not in menu - player should not
    // be able to navigate through sheets and tabs.
    local checkIsInMenu = ::isInMenu() || ::has_feature("devItemShop")
    local checkEnableShop = checkIsInMenu && ::has_feature("ItemsShop")
    if (!checkEnableShop)
      scene.findObject("wnd_title").setValue(::loc(getTabName(itemsTab.INVENTORY)))

    ::show_obj(getTabsListObj(), checkEnableShop)
    ::show_obj(getSheetsListObj(), isInMenu)
    showSceneBtn("sorting_block", false)

    updateWarbondsBalance()
    moveMouseToMainList()
  }

  function reinitScreen(params = {})
  {
    setParams(params)
    initScreen()
  }

  focusSheetsList = @() ::move_mouse_on_child_by_value(getSheetsListObj())

  function initNavigation()
  {
    if (navigationHandlerWeak)
      return

    local handler = ::handlersManager.loadHandler(
      ::gui_handlers.navigationPanel,
      { scene                  = scene.findObject("control_navigation")
        onSelectCb             = ::Callback(doNavigateToSection, this)
        onClickCb              = ::Callback(onNavItemClickCb, this)
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

    local newSheet = sheetsArray?[obj.shIdx]
    if (!newSheet)
      return

    isItemTypeChangeUpdate = true  //No need update item when fill subset if changed item type
    curSheet = newSheet
    itemsListValid = false

    if (obj?.subsetId)
    {
      subsetList = curSheet.getSubsetsListParameters().subsetList
      curSubsetId = initSubsetId ?? obj.subsetId
      initSubsetId = null
      curSheet.setSubset(curSubsetId)
    }

    isItemTypeChangeUpdate = false
    if (!isSheetsInUpdate)
      applyFilters()
  }

  function onNavItemClickCb(obj)
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

  function getTabName(tabIdx)
  {
    switch (tabIdx)
    {
      case itemsTab.SHOP:          return "items/shop"
      case itemsTab.INVENTORY:     return "items/inventory"
      case itemsTab.WORKSHOP:      return "items/workshop"
    }
    return ""
  }

  isTabVisible = @(tabIdx) tabIdx != itemsTab.WORKSHOP || workshop.isAvailable()
  getTabSeenList = @(tabIdx) seenList.get(getTabSeenId(tabIdx))

  function getTabSeenId(tabIdx)
  {
    switch (tabIdx)
    {
      case itemsTab.SHOP:          return SEEN.ITEMS_SHOP
      case itemsTab.INVENTORY:     return SEEN.INVENTORY
      case itemsTab.WORKSHOP:      return SEEN.WORKSHOP
    }
    return null
  }

  function fillTabs()
  {
    visibleTabs = []
    for (local i = 0; i < itemsTab.TOTAL; i++)
      if (isTabVisible(i))
        visibleTabs.append(i)

    local view = {
      tabs = []
    }
    local selIdx = -1
    foreach(idx, tabIdx in visibleTabs)
    {
      view.tabs.append({
        tabName = ::loc(getTabName(tabIdx))
        unseenIcon = getTabSeenId(tabIdx)
        navImagesText = ::get_navigation_images_text(idx, visibleTabs.len())
      })
      if (tabIdx == curTab)
        selIdx = idx
    }
    if (selIdx < 0)
    {
      selIdx = 0
      curTab = visibleTabs[selIdx]
    }

    local data = ::handyman.renderCached("gui/frameHeaderTabs", view)
    local tabsObj = getTabsListObj()
    guiScene.replaceContentFromText(tabsObj, data, data.len(), this)
    tabsObj.setValue(selIdx)
  }

  function onTabChange()
  {
    markCurrentPageSeen()

    local value = getTabsListObj().getValue()
    curTab = visibleTabs?[value] ?? curTab

    itemsListValid = false
    updateSheets()
  }

  function initSheetsOnce()
  {
    if (sheetsArray && sheetsArray.len())
      return

    sheetsArray = displayItemTypes?
        sheets.types.filter(function(sh) {
            return ::isInArray(sh.id, displayItemTypes)
          }.bindenv(this) )
      : sheets.types

    local count = 0
    navItems = []
    foreach(idx, sh in sheetsArray)
    {
      local isCollapsable = sh.hasSubLists()
      local item = {
        shIdx = idx
        unseenIcon = SEEN.ITEMS_SHOP
        unseenIconId = "unseen_icon"
      }
      navItems.append(item.__merge({
        idx = count++
        text = ::loc(sh.locId)
        isCollapsable = isCollapsable
        isHeader = true
        }))
      if (isCollapsable)
        foreach(param in sh.getSubsetsListParameters().subsetList)
          navItems.append(item.__merge({
            idx = count++
            text = ::loc(param.locId)
            subsetId = param.id
         }))
    }

    if (navigationHandlerWeak)
      navigationHandlerWeak.setNavItems(navItems)
  }

  function updateSheets()
  {
    isSheetsInUpdate = true //there can be multiple sheets changed on switch tab, so no need to update items several times.
    guiScene.setUpdatesEnabled(false, false)
    initSheetsOnce()

    local typesObj = getSheetsListObj() //!!FIX ME: Why we use object from navigation panel here?
    local seenListId = getTabSeenId(curTab)
    local curValue = -1
    local childsTotal = typesObj.childrenCount()

    if (childsTotal < navItems.len()) {
      local navItemsTotal = navItems.len() // warning disable: -declared-never-used
      ::script_net_assert_once("Bad count on update unseen tabs",
        "ItemsShop: Not all sheets exist on update sheets list unseen icon")
    }

    foreach(idx, item in navItems) {
      if (idx >= childsTotal)
        break

      local sh = sheetsArray[item.shIdx]
      local isEnabled = sh.isEnabled(curTab)
      local child = typesObj.getChild(idx)
      child.show(isEnabled)
      child.enable(isEnabled)

      if (!isEnabled)
        continue

      if ((curValue < 0 || curSheet == sh) && !item?.isCollapsable)
        curValue = idx

      child.findObject("unseen_icon").setValue(bhvUnseen.makeConfigStr(seenListId,
        item?.subsetId ? sh.getSubsetSeenListId(item.subsetId) : sh.getSeenId()))
    }

    if (curValue >= 0)
      typesObj.setValue(curValue)

    guiScene.setUpdatesEnabled(true, true)
    isSheetsInUpdate = false

    applyFilters()
  }

  function onEventWorkshopAvailableChanged(p)
  {
    if (curTab == itemsTab.WORKSHOP)
      updateSheets()
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
    local mainBlockHeight = "@rh-2@frameHeaderHeight-1@frameFooterHeight-1@bottomMenuPanelHeight-1@blockInterval"
    local itemsCountX = ::max(::to_pixels($"@rw-1@shopInfoMinWidth-({leftPos})-({nawWidth})")
      / ::max(1, ::to_pixels(itemWidthWithSpace)), 1)
    local itemsCountY = ::max(::to_pixels(mainBlockHeight)
      / ::max(1, ::to_pixels(itemHeightWithSpace)), 1)
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

  function applyFilters(resetPage = true)
  {
    initItemsListSizeOnce()

    if (!itemsListValid)
    {
      itemsListValid = true
      itemsList = curSheet.getItemsList(curTab, curSubsetId)
      if (curTab == itemsTab.INVENTORY)
        itemsList.sort(::ItemsManager.getItemsSortComparator(getTabSeenList(curTab)))
    }

    if (resetPage && !shouldSetPageByItem)
      curPage = 0
    else
    {
      shouldSetPageByItem = false
      local lastIdx = getLastSelItemIdx()
      if (lastIdx >= 0)
        curPage = (lastIdx / itemsPerPage).tointeger()
      else if (curPage * itemsPerPage > itemsList.len())
        curPage = ::max(0, ((itemsList.len() - 1) / itemsPerPage).tointeger())
    }

    fillPage()
  }

  function fillPage()
  {
    local view = { items = [] }
    local pageStartIndex = curPage * itemsPerPage
    local pageEndIndex = min((curPage + 1) * itemsPerPage, itemsList.len())
    local seenListId = getTabSeenId(curTab)
    local craftTree = curSheet?.getSet().getCraftTree()
    for(local i=pageStartIndex; i < pageEndIndex; i++)
    {
      local item = itemsList[i]
      if (item.hasLimits())
        ::g_item_limits.enqueueItem(item.id)

      view.items.append(item.getViewData({
        itemIndex = i.tostring(),
        showSellAmount = curTab == itemsTab.SHOP,
        unseenIcon = bhvUnseen.makeConfigStr(seenListId, item.getSeenId())
        isItemLocked = isItemLocked(item)
        showButtonInactiveIfNeed = true
        overrideMainActionData = craftTree != null && item.canCraftOnlyInCraftTree()
          ? {
            isInactive = false
            btnName = ::loc(craftTree?.openButtonLocId ?? "")
            needShowActionButtonAlways = false
          }
          : null
        showTooltip = isMouseMode
        onHover = "onItemHover"
      }))
    }
    ::g_item_limits.requestLimits()

    local listObj = getItemsListObj()
    local prevValue = listObj.getValue()
    local data = ::handyman.renderCached(("gui/items/item"), view)
    if (::checkObj(listObj))
    {
      listObj.show(data != "")
      listObj.enable(data != "")
      guiScene.replaceContentFromText(listObj, data, data.len(), this)
    }

    local emptyListObj = scene.findObject("empty_items_list")
    if (::checkObj(emptyListObj))
    {
      local adviseMarketplace = curTab == itemsTab.INVENTORY && curSheet.isMarketplace && isMarketplaceEnabled()
      local itemsInShop = curTab == itemsTab.SHOP? itemsList : curSheet.getItemsList(itemsTab.SHOP, curSubsetId)
      local adviseShop = ::has_feature("ItemsShop") && curTab != itemsTab.SHOP && !adviseMarketplace && itemsInShop.len() > 0

      emptyListObj.show(data.len() == 0)
      emptyListObj.enable(data.len() == 0)
      showSceneBtn("items_shop_to_marketplace_button", adviseMarketplace)
      showSceneBtn("items_shop_to_shop_button", adviseShop)
      local emptyListTextObj = scene.findObject("empty_items_list_text")
      if (::checkObj(emptyListTextObj))
      {
        local caption = ::loc(curSheet.emptyTabLocId, "")
        if (!caption.len())
          caption = ::loc("items/shop/emptyTab/default")
        if (caption.len() > 0)
        {
          local noItemsAdviceLocId =
              adviseMarketplace ? "items/shop/emptyTab/noItemsAdvice/marketplaceEnabled"
            : adviseShop        ? "items/shop/emptyTab/noItemsAdvice/shopEnabled"
            :                     "items/shop/emptyTab/noItemsAdvice/shopDisabled"
          caption += " " + ::loc(noItemsAdviceLocId)
        }
        emptyListTextObj.setValue(caption)
      }
    }

    local value = findLastValue(prevValue)
    if (value >= 0)
      listObj.setValue(value)

    updateItemInfo()

    generatePaginator(scene.findObject("paginator_place"), this,
      curPage, ::ceil(itemsList.len().tofloat() / itemsPerPage) - 1, null, true /*show last page*/)

    if (!itemsList.len())
      focusSheetsList()
  }

  function isItemLocked(item)
  {
    return false
  }

  function isLastItemSame(item)
  {
    if (!curItem || curItem.id != item.id)
      return false
    if (!curItem.uids || !item.uids)
      return true
    foreach(uid in curItem.uids)
      if (::isInArray(uid, item.uids))
        return true
    return false
  }

  function findLastValue(prevValue)
  {
    local offset = curPage * itemsPerPage
    local total = ::clamp(itemsList.len() - offset, 0, itemsPerPage)
    if (!total)
      return -1

    local res = ::clamp(prevValue, 0, total - 1)
    if (curItem)
      for(local i = 0; i < total; i++)
      {
        local item = itemsList[offset + i]
        if (curItem.id != item.id)
          continue
        res = i
        if (isLastItemSame(item))
          break
      }
    return res
  }

  function getLastSelItemIdx()
  {
    local res = -1
    if (!curItem)
      return res

    foreach(idx, item in itemsList)
      if (curItem.id == item.id)
      {
        res = idx
        if (isLastItemSame(item))
          break
      }
    return res
  }

  function onEventInventoryUpdate(p)
  {
    doWhenActiveOnce("updateInventoryItemsList")
  }

  function onEventUnitBought(params)
  {
    updateItemInfo()
  }

  function onEventUnitRented(params)
  {
    updateItemInfo()
  }

  moveMouseToMainList = @() ::move_mouse_on_child_by_value(getItemsListObj())

  function getCurItem()
  {
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

  function goToPage(obj)
  {
    markCurrentPageSeen()
    curPage = obj.to_page.tointeger()
    fillPage()
  }

  function updateItemsList()
  {
    itemsListValid = false
    applyFilters(false)
  }

  function updateItemInfo()
  {
    local item = getCurItem()
    markItemSeen(item)
    infoHandler?.updateHandlerData(item, true, true)
    showSceneBtn("jumpToDescPanel", ::show_console_buttons && item != null)
    updateButtons()
  }

  function markItemSeen(item)
  {
    if (item)
      getTabSeenList(curTab).markSeen(item.getSeenId())
  }

  function markCurrentPageSeen()
  {
    if (!itemsList)
      return

    local pageStartIndex = curPage * itemsPerPage
    local pageEndIndex = min((curPage + 1) * itemsPerPage, itemsList.len())
    local list = []
    for(local i = pageStartIndex; i < pageEndIndex; ++i)
      list.append(itemsList[i].getSeenId())
    getTabSeenList(curTab).markSeen(list)
  }

  function updateButtonsBar() {
    local obj = getItemsListObj()
    local isButtonsVisible = isMouseMode || (::check_obj(obj) && obj.isHovered())
    showSceneBtn("item_actions_bar", isButtonsVisible)
    return isButtonsVisible
  }

  function updateButtons()
  {
    local item = getCurItem()
    local mainActionData = item?.getMainActionData()
    local limitsCheckData = item?.getLimitsCheckData()
    local limitsCheckResult = limitsCheckData?.result ?? true
    local showMainAction = mainActionData && limitsCheckResult
    local curSet = curSheet?.getSet()
    local craftTree = curSet?.getCraftTree()
    local needShowCraftTree = craftTree != null
    local openCraftTreeBtnText = ::loc(craftTree?.openButtonLocId ?? "")

    local craftTreeBtnObj = showSceneBtn("btn_open_craft_tree", needShowCraftTree)
    if (curSet != null && needShowCraftTree)
    {
      craftTreeBtnObj.setValue(openCraftTreeBtnText)
      local tutorialItem = curSet.findTutorialItem()
      if (tutorialItem)
        startCraftTutorial(curSet, tutorialItem, craftTreeBtnObj)
    }

    if (!updateButtonsBar()) //buttons below are hidden if item action bar is hidden
      return

    local buttonObj = showSceneBtn("btn_main_action", showMainAction)
    local canCraftOnlyInCraftTree = needShowCraftTree && (item?.canCraftOnlyInCraftTree() ?? false)
    if (showMainAction)
    {
      buttonObj.visualStyle = curTab == itemsTab.INVENTORY? "secondary" : "purchase"
      buttonObj.inactiveColor = mainActionData?.isInactive && !canCraftOnlyInCraftTree ? "yes" : "no"
      local btnText = canCraftOnlyInCraftTree ? openCraftTreeBtnText : mainActionData.btnName
      local btnColoredText = canCraftOnlyInCraftTree
        ? openCraftTreeBtnText
        : mainActionData?.btnColoredName ?? mainActionData.btnName
      setDoubleTextToButton(scene, "btn_main_action", btnText, btnColoredText)
    }

    local activateText = !showMainAction && item?.isInventoryItem && item.amount ? item.getActivateInfo() : ""
    scene.findObject("activate_info_text").setValue(activateText)
    showSceneBtn("btn_preview", item ? (item.canPreview() && ::isInMenu()) : false)

    local altActionText = item ? item.getAltActionName() : ""
    showSceneBtn("btn_alt_action", altActionText != "")
    setColoredDoubleTextToButton(scene, "btn_alt_action", altActionText)

    local warningText = ""
    if (!limitsCheckResult && item && !item.isInventoryItem)
      warningText = limitsCheckData.reason
    setWarningText(warningText)

    local showLinkAction = item && item.hasLink()
    local linkObj = showSceneBtn("btn_link_action", showLinkAction)
    if (showLinkAction)
    {
      local linkActionText = ::loc(item.linkActionLocId)
      setDoubleTextToButton(scene, "btn_link_action", linkActionText, linkActionText)
      if (item.linkActionIcon != "")
      {
        linkObj["class"] = "image"
        linkObj.findObject("img")["background-image"] = item.linkActionIcon
      }
    }
  }

  function onLinkAction(obj)
  {
    local item = getCurItem()
    if (item)
      item.openLink()
  }

  function onItemPreview(obj)
  {
    if (!isValid())
      return

    local item = getCurItem()
    if (item && canStartPreviewScene(true, true))
      item.doPreview()
  }

  function onItemAction(buttonObj)
  {
    local id = ::to_integer_safe(buttonObj?.holderId, -1)
    local item = itemsList?[id]
    local obj = scene.findObject("shop_item_" + id)

    // Need to change list object current index because of
    // we can click on action button in non selected item
    // and wrong item will be updated after main action
    local listObj = getItemsListObj()
    if (listObj.getValue() != id && id >= 0 && id < listObj.childrenCount())
      listObj.setValue(id)

    doMainAction(item, obj)
  }

  function onMainAction(obj)
  {
    doMainAction()
  }

  function doMainAction(item = null, obj = null)
  {
    item = item || getCurItem()
    if (item == null)
      return

    obj = obj || getCurItemObj()
    if (item.canCraftOnlyInCraftTree() && curSheet?.getSet().getCraftTree() != null)
      openCraftTree(item)
    else
    {
      local updateFn = item?.needUpdateListAfterAction ? updateItemsList : updateItemInfo
      item.doMainAction(
        ::Callback(@(result) updateFn(), this),
        this,
        { obj = obj })
    }

    markItemSeen(item)
  }

  function onAltAction(obj)
  {
    local item = getCurItem()
    if (item)
      item.doAltAction({ obj = obj, align = "top" })
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

  function onTimer(obj, dt)
  {
    if (!itemsListValid)
      return

    local listObj = getItemsListObj()
    local startIdx = curPage * itemsPerPage
    local lastIdx = min((curPage + 1) * itemsPerPage, itemsList.len())
    for(local i=startIdx; i < lastIdx; i++)
    {
      if (!itemsList[i].hasTimer())
        continue

      local itemObj = ::check_obj(listObj) ? listObj.getChild(i - curPage * itemsPerPage) : null
      if (::check_obj(itemObj))
      {
        local timeTxtObj = itemObj.findObject("expire_time")
        if (::check_obj(timeTxtObj))
          timeTxtObj.setValue(itemsList[i].getTimeLeftText())
        timeTxtObj = itemObj.findObject("craft_time")
        if (::check_obj(timeTxtObj))
          timeTxtObj.setValue(itemsList[i].getCraftTimeTextShort())
      }
    }

    local selItem = getCurItem()
    if (selItem?.hasTimer())
      fillDescTextAboutDiv(selItem, infoHandler.scene)

  }

  function onToShopButton(obj)
  {
    curTab = itemsTab.SHOP
    fillTabs()
  }

  function onToMarketplaceButton(obj)
  {
    goToMarketplace()
  }

  function goBack()
  {
    markCurrentPageSeen()
    base.goBack()
  }

  function getItemsListObj()
  {
    return scene.findObject("items_list")
  }

  function getTabsListObj()
  {
    return scene.findObject("tabs_list")
  }

  function getSheetsListObj()
  {
    return scene.findObject("nav_list")
  }

  /**
   * Returns all the data required to restore current window state:
   * curSheet, curTab, selected item, etc...
   */
  function getHandlerRestoreData()
  {
    local data = {
      openData = {
        curTab = curTab
        curSheet = curSheet
      }
      stateData = {
        currentItemId = ::getTblValue("id", getCurItem(), null)
      }
    }
    return data
  }

  /**
   * Returns -1 if item was not found.
   */
  function getItemIndexById(itemId)
  {
    foreach (itemIndex, item in itemsList)
    {
      if (item.id == itemId)
        return itemIndex
    }
    return -1
  }

  function restoreHandler(stateData)
  {
    local itemIndex = getItemIndexById(stateData.currentItemId)
    if (itemIndex == -1)
      return
    curPage = ::ceil(itemIndex / itemsPerPage).tointeger()
    fillPage()
    getItemsListObj().setValue(itemIndex % itemsPerPage)
  }

  function onEventBeforeStartShowroom(params)
  {
    ::handlersManager.requestHandlerRestore(this, ::gui_handlers.MainMenu)
  }

  function onEventBeforeStartTestFlight(params)
  {
    ::handlersManager.requestHandlerRestore(this, ::gui_handlers.MainMenu)
  }

  function onEventItemLimitsUpdated(params)
  {
    updateItemInfo()
  }

  function setWarningText(text)
  {
    local warningTextObj = scene.findObject("warning_text")
    if (::checkObj(warningTextObj))
      warningTextObj.setValue(::colorize("redMenuButtonColor", text))
  }

  function onEventActiveHandlersChanged(p)
  {
    showSceneBtn("black_screen", ::handlersManager.findHandlerClassInScene(::gui_handlers.trophyRewardWnd) != null)
  }

  function updateWarbondsBalance()
  {
    if (!::has_feature("Warbonds"))
      return

    local warbondsObj = scene.findObject("balance_text")
    warbondsObj.setValue(::g_warbonds.getBalanceText())
    warbondsObj.tooltip = ::loc("warbonds/maxAmount", {warbonds = ::g_warbonds.getLimit()})
  }

  function onEventProfileUpdated(p)
  {
    doWhenActiveOnce("updateWarbondsBalance")
    doWhenActiveOnce("updateInventoryItemsList")
  }

  //dependence by blk
  onChangeSortOrder = @(obj) null
  onChangeSortParam = @(obj) null
  onShowBattlePass = @(obj) null

  function onEventBeforeStartCustomMission(params)
  {
    ::handlersManager.requestHandlerRestore(this, ::gui_handlers.MainMenu)
  }

  function updateInventoryItemsList()
  {
    if (curTab != itemsTab.SHOP)
      updateItemsList()
  }

  function onItemsListFocusChange()
  {
    if (isValid())
      updateButtons()
  }

  function onOpenCraftTree()
  {
    openCraftTree()
  }

  function openCraftTree(showItem = null, tutorialItem = null)
  {
    local curSet = curSheet?.getSet()
    if (curSet?.getCraftTree() == null)
      return

    workshopCraftTreeWnd.open({
      workshopSet = curSet
      showItemOnInit = showItem
      tutorialItem = tutorialItem
    })
  }

  onShowSpecialTasks = @(obj) null

  function startCraftTutorial(curSet, tutorialItem, craftTreeBtnObj) {
    curSet.saveTutorialWasShown()
    local steps = [{
      obj = [craftTreeBtnObj]
      text = ::loc("workshop/accentCraftTreeButton", {
        buttonName = ::loc(curSet.getCraftTree()?.openButtonLocId ?? "")
      })
      shortcut = ::SHORTCUT.GAMEPAD_RSTICK_PRESS
      actionType = tutorAction.OBJ_CLICK
      cb = @() openCraftTree(null, tutorialItem)
    }]
    ::gui_modal_tutor(steps, this, true)
  }

  function onItemHover(obj) {
    if (!::show_console_buttons)
      return
    local wasMouseMode = isMouseMode
    updateMouseMode()
    if (wasMouseMode != isMouseMode)
      updateShowItemButton()
    if (isMouseMode)
      return
    hoverHoldAction(obj, function(focusObj) {
      local idx = focusObj.holderId.tointeger()
      local value = idx - curPage * itemsPerPage
      local listObj = getItemsListObj()
      if (listObj.getValue() != value && value >= 0 && value < listObj.childrenCount())
        listObj.setValue(value)
    }.bindenv(this))
  }

  updateMouseMode = @() isMouseMode = !::show_console_buttons || ::is_mouse_last_time_used()
  function updateShowItemButton() {
    local listObj = getItemsListObj()
    if (listObj?.isValid())
      listObj.showItemButton = isMouseMode ? "yes" : "no"
  }
}

local function openItemsWndFromPromo(owner, params = []) {
  local tab = getconsttable()?.itemsTab?[(params?[1] ?? "SHOP").toupper()] ?? itemsTab.INVENTORY

  local curSheet = null
  local sheetSearchId = params?[0]
  local initSubsetId = params?[2]
  if (sheetSearchId)
    curSheet = {searchId = sheetSearchId}

  if (tab >= itemsTab.TOTAL)
    tab = itemsTab.INVENTORY

  ::gui_start_items_list(tab, {curSheet = curSheet, initSubsetId = initSubsetId})
}

addPromoAction("items", @(handler, params, obj) openItemsWndFromPromo(handler, params))
