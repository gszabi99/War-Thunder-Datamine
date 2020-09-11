local sheets = require("scripts/items/itemsShopSheets.nut")
local workshop = require("scripts/items/workshop/workshop.nut")
local seenList = require("scripts/seen/seenList.nut")
local bhvUnseen = require("scripts/seen/bhvUnseen.nut")
local workshopCraftTreeWnd = require("scripts/items/workshop/workshopCraftTreeWnd.nut")
local daguiFonts = require("scripts/viewUtils/daguiFonts.nut")
local tutorAction = require("scripts/tutorials/tutorialActions.nut")
local { canStartPreviewScene } = require("scripts/customization/contentPreview.nut")
local { setDoubleTextToButton, setColoredDoubleTextToButton } = require("scripts/viewUtils/objectTextUpdate.nut")

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
  ::handlersManager.loadHandler(::gui_handlers.ItemsList, handlerParams)
}

class ::gui_handlers.ItemsList extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/items/itemsShop.blk"

  curTab = 0 //first itemsTab
  visibleTabs = null //[]
  curSheet = null
  curItem = null //last selected item to restore selection after change list

  isSheetsInUpdate = false
  isItemTypeChangeUpdate = false
  itemsPerPage = -1
  windowSize = 0
  itemsList = null
  curPage = 0
  shouldSetPageByItem = false
  currentFocusItem = 3

  slotbarActions = [ "preview", "testflightforced", "sec_weapons", "weapons", "info" ]
  displayItemTypes = null
  sheetsArray = null

  subsetList = null
  curSubsetId = null
  initSubsetId = null

  // Used to avoid expensive get...List and further sort.
  itemsListValid = false

  function initScreen()
  {
    sheets.updateWorkshopSheets()

    local sheetData = curTab < 0 && curItem ? sheets.getSheetDataByItem(curItem) : null
    if (sheetData)
    {
      curTab = sheetData.tab
      shouldSetPageByItem = true
    } else if (curTab < 0)
      curTab = 0

    curSheet = sheetData ? sheetData.sheet
      : curSheet ? sheets.findSheet(curSheet, sheets.ALL) //it can be simple table, need to find real sheeet by it
      : sheets.ALL
    initSubsetId = sheetData ? sheetData.subsetId : initSubsetId

    fillTabs()

    initFocusArray()
    local itemsListObj = getItemsListObj()
    if (itemsListObj.childrenCount() > 0)
      itemsListObj.select()

    scene.findObject("update_timer").setUserData(this)

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
  }

  function reinitScreen(params = {})
  {
    setParams(params)
    initScreen()
  }

  function getMainFocusObj()
  {
    return null
  }

  function getMainFocusObj2()
  {
    return getSheetsListObj()
  }

  function getMainFocusObj3()
  {
    local obj = getItemsListObj()
    return obj.childrenCount() ? obj : null
  }

  function focusSheetsList()
  {
    local obj = getSheetsListObj()
    obj.select()
    checkCurrentFocusItem(obj)
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

    local view = {
      items = sheetsArray.map(@(sh) {
        text = ::loc(sh.locId)
        autoScrollText = true
        unseenIcon = SEEN.ITEMS_SHOP //intial to create unseen block.real value will be set on update.
        unseenIconId = "unseen_icon"
      })
    }

    local data = ::handyman.renderCached("gui/items/shopFilters", view)
    guiScene.replaceContentFromText(scene.findObject("filter_tabs"), data, data.len(), this)
  }

  function updateSheets()
  {
    isSheetsInUpdate = true //there can be multiple sheets changed on switch tab, so no need to update items several times.
    guiScene.setUpdatesEnabled(false, false)
    initSheetsOnce()

    local typesObj = getSheetsListObj()
    local seenListId = getTabSeenId(curTab)
    local curValue = -1
    local hasSubLists = false
    local visibleSheetsArray = []
    foreach(idx, sh in sheetsArray)
    {
      local isEnabled = sh.isEnabled(curTab)
      local child = typesObj.getChild(idx)
      child.show(isEnabled)
      child.enable(isEnabled)

      if (!isEnabled)
        continue

      if (curValue < 0 || curSheet == sh)
        curValue = idx

      visibleSheetsArray.append({idx = idx, text = ::loc(sh.locId)})
      hasSubLists = hasSubLists || sh.hasSubLists()
      child.findObject("unseen_icon").setValue(bhvUnseen.makeConfigStr(seenListId, sh.getSeenId()))
    }
    if (curValue >= 0)
      typesObj.setValue(curValue)

    if (hasSubLists)
      setSheetsInOneLineWithSubset(visibleSheetsArray)
    showSceneBtn("subset_list_nest", hasSubLists)

    guiScene.setUpdatesEnabled(true, true)
    isSheetsInUpdate = false

    applyFilters()
  }

  function setSheetsInOneLineWithSubset(visibleSheetsArray)
  {
    initItemsListSizeOnce()

    local typesObj = getSheetsListObj()
    local visibleSheetsCount = visibleSheetsArray.len()
    local minSheetWidth = ::to_pixels("1@minShopFilterWidthWithUnseen")
    local subsetListWidthWithPadding = ::to_pixels("2@framePadding + 1@subsetComboBoxWidth + 1@listboxPad")
    local sheetIntervalWidth = ::to_pixels("(1 + {0})@listboxItemsInterval".subst(visibleSheetsCount))
    local maxSheetsListTextWidth = windowSize[0] - minSheetWidth * visibleSheetsCount
      - subsetListWidthWithPadding - sheetIntervalWidth

    foreach (idx, sh in visibleSheetsArray)
    {
      local maxTextWidth = maxSheetsListTextWidth / (visibleSheetsCount - idx)
      local textWidth = ::min(daguiFonts.getStringWidthPx(sh.text, "fontSmall", guiScene), maxTextWidth)
      maxSheetsListTextWidth = maxSheetsListTextWidth - textWidth
      if (textWidth < maxTextWidth)
        continue

      local sheetObj = typesObj.getChild(sh.idx)
      sheetObj["width"] = minSheetWidth + textWidth
      sheetObj.tooltip = sh.text
    }
  }

  function onItemTypeChange(obj)
  {
    markCurrentPageSeen()

    local newSheet = sheetsArray?[obj.getValue()]
    if (!newSheet)
      return

    isItemTypeChangeUpdate = true  //No need update item when fill subset if changed item type
    curSheet = newSheet
    itemsListValid = false

    fillSubset()
    isItemTypeChangeUpdate = false
    if (!isSheetsInUpdate)
      applyFilters()
  }

  function initItemsListSizeOnce()
  {
    if (itemsPerPage >= 1)
      return

    local wndItemsShopObj = scene.findObject("wnd_items_shop")
    local sizes = ::g_dagui_utils.adjustWindowSize(wndItemsShopObj, getItemsListObj(),
      "@itemWidth", "@itemHeight", "@itemSpacing", "@itemSpacing", { windowSizeY = 0 })
    scene.findObject("main_block").height = sizes.sizeY * sizes.itemsCountY //need const height of items list after resize
      + (sizes.itemsCountY + 1) * sizes.spaceY
    itemsPerPage = sizes.itemsCountX * sizes.itemsCountY
    windowSize = sizes.windowSize
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
      }))
    }
    ::g_item_limits.requestLimits()

    local listObj = getItemsListObj()
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
      local adviseMarketplace = curTab == itemsTab.INVENTORY && curSheet.isMarketplace && ::ItemsManager.isMarketplaceEnabled()
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

    local prevValue = listObj.getValue()
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
    updateInventoryItemsList()
  }

  function onEventUnitBought(params)
  {
    updateItemInfo()
  }

  function onEventUnitRented(params)
  {
    updateItemInfo()
  }

  function getCurItem()
  {
    local obj = getItemsListObj()
    if (!::check_obj(obj) || !obj.isFocused())
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

  function updateItemInfo()
  {
    markItemSeen(getCurItem())
    ::ItemsManager.fillItemDescr(getCurItem(), scene.findObject("item_info"), this, true, true)
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

  function updateButtons()
  {
    local item = getCurItem()
    local mainActionData = item ? item.getMainActionData() : null
    local limitsCheckData = item ? item.getLimitsCheckData() : null
    local limitsCheckResult = ::getTblValue("result", limitsCheckData, true)
    local showMainAction = mainActionData && limitsCheckResult
    local buttonObj = showSceneBtn("btn_main_action", showMainAction)
    local curSet = curSheet?.getSet()
    local craftTree = curSet?.getCraftTree()
    local needShowCraftTree = craftTree != null
    local openCraftTreeBtnText = ::loc(craftTree?.openButtonLocId ?? "")
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

    local craftTreeBtnObj = showSceneBtn("btn_open_craft_tree", needShowCraftTree)
    if (curSet != null && needShowCraftTree)
    {
      craftTreeBtnObj.setValue(openCraftTreeBtnText)
      if (curSet.needShowAccentToCraftTreeBtn())
        showAccentToCraftTreeBtn(curSet, craftTreeBtnObj)
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
    local id = buttonObj?.holderId ?? "-1"
    local item = ::getTblValue(id.tointeger(), itemsList)
    local obj = scene.findObject("shop_item_" + id)
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
      item.doMainAction(
        ::Callback(@(result) updateItemInfo(), this),
        this,
        { obj = obj })

    markItemSeen(item)
  }

  function onAltAction(obj)
  {
    local item = getCurItem()
    if (item)
      item.doAltAction({ obj = obj, align = "top" })
  }

  function onUnitHover(obj)
  {
    openUnitActionsList(obj, true, true)
  }

  function onTimer(obj, dt)
  {
    if (!itemsListValid)
      return

    local startIdx = curPage * itemsPerPage
    local lastIdx = min((curPage + 1) * itemsPerPage, itemsList.len())
    for(local i=startIdx; i < lastIdx; i++)
    {
      if (!itemsList[i].hasTimer())
        continue
      local listObj = getItemsListObj()
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
  }

  function onToShopButton(obj)
  {
    curTab = itemsTab.SHOP
    fillTabs()
  }

  function onToMarketplaceButton(obj)
  {
    ::ItemsManager.goToMarketplace()
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
    return scene.findObject("sheets_list")
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
    updateWarbondsBalance()
    updateInventoryItemsList()
  }

  //dependence by blk
  onChangeSortOrder = @(obj) null
  onChangeSortParam = @(obj) null

  function onEventBeforeStartCustomMission(params)
  {
    ::handlersManager.requestHandlerRestore(this, ::gui_handlers.MainMenu)
  }

  function updateInventoryItemsList()
  {
    if (curTab != itemsTab.SHOP)
    {
      itemsListValid = false
      applyFilters(false)
    }
  }

  function onItemsListFocusChange()
  {
    if (isValid())
      updateItemInfo()
  }

  function onOpenCraftTree()
  {
    openCraftTree()
  }

  function openCraftTree(showItem = null)
  {
    local curSet = curSheet?.getSet()
    if (curSet?.getCraftTree() == null)
      return

    workshopCraftTreeWnd.open({
      workshopSet = curSet
      showItemOnInit = showItem
    })
  }

  function getSubsetListView()
  {
    local view = {
      id       = "subset_list"
      btnName  = "RB"
      funcName = "onSubsetChange"
      values   = subsetList.map((@(subset) {
        valueId    = subset.id
        text       = ::loc(subset.locId)
        unseenIcon = bhvUnseen.makeConfigStr(getTabSeenId(curTab), curSheet.getSubsetSeenListId(subset.id))
      }).bindenv(this))
    }

    return ::handyman.renderCached("gui/commonParts/comboBox", view)
  }

  function fillSubset()
  {
    local hasSubLists = curSheet.hasSubLists()
    local subsetNestObj = showSceneBtn("subset_list_bg", hasSubLists)
    if (!hasSubLists)
    {
      subsetList = null
      curSubsetId = null
      return
    }

    local subsetListParameters = curSheet.getSubsetsListParameters()
    subsetList = subsetListParameters.subsetList
    curSubsetId = initSubsetId != null ? initSubsetId : subsetListParameters.curSubsetId
    initSubsetId = null
    local curIdx = subsetList.findindex((@(subset) subset.id == curSubsetId).bindenv(this)) ?? 0
    local data = getSubsetListView()
    guiScene.replaceContentFromText(subsetNestObj, data, data.len(), this)
    scene.findObject("subset_list").setValue(curIdx)
  }

  function onSubsetChange(obj)
  {
    if (isItemTypeChangeUpdate || !curSheet.hasSubLists())
      return

    markCurrentPageSeen()

    local curSubsetIdx = obj.getValue()
    curSubsetId = subsetList[curSubsetIdx].id
    curSheet.setSubset(curSubsetId)

    itemsListValid = false
    applyFilters()
  }

  onShowSpecialTasks = @(obj) null

  function showAccentToCraftTreeBtn(curSet, craftTreeBtnObj) {
    curSet.saveShowedAccentCraftTreeBtn()
    local steps = [{
      obj = [craftTreeBtnObj]
      text = ::loc("workshop/accentCraftTreeButton", {
        buttonName = ::loc(curSet.getCraftTree()?.openButtonLocId ?? "")
      })
      shortcut = ::SHORTCUT.GAMEPAD_RSTICK_PRESS
      actionType = tutorAction.OBJ_CLICK
      cb = openCraftTree
    }]
    ::gui_modal_tutor(steps, this, true)
  }
}