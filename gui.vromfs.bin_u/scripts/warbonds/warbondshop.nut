local time = require("scripts/time.nut")
local bhvUnseen = require("scripts/seen/bhvUnseen.nut")
local seenWarbondsShop = require("scripts/seen/seenList.nut").get(SEEN.WARBONDS_SHOP)
local { setColoredDoubleTextToButton } = require("scripts/viewUtils/objectTextUpdate.nut")
local mkHoverHoldAction = require("sqDagui/timer/mkHoverHoldAction.nut")
local { openBattlePassWnd } = require("scripts/battlePass/battlePassWnd.nut")

class ::gui_handlers.WarbondsShop extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/items/itemsShop.blk"

  filterFunc = null

  wbList = null
  curWbIdx = 0
  curWb = null
  curPage = 0
  curPageAwards = null
  itemsPerPage = 1

  slotbarActions = [ "preview", "testflight", "sec_weapons", "weapons", "info" ]

  hoverHoldAction = null

  function initScreen()
  {
    wbList = ::g_warbonds.getList(filterFunc)
    if (!wbList.len())
      return goBack()

    local infoObj = scene.findObject("item_info")
    guiScene.replaceContent(infoObj, "gui/items/itemDesc.blk", this)

    curPageAwards = []
    if (!(curWbIdx in wbList))
      curWbIdx = 0
    curWb = wbList[curWbIdx]

    local obj = scene.findObject("warbond_shop_progress_block")
    if (::check_obj(obj))
      obj.show(true)

    initItemsListSize()
    fillTabs()
    updateBalance()
    ::move_mouse_on_child(getItemsListObj(), 0)

    scene.findObject("update_timer").setUserData(this)
    hoverHoldAction = mkHoverHoldAction(scene.findObject("hover_hold_timer"))
  }

  function fillTabs()
  {
    local view = { tabs = [] }
    foreach(i, wb in wbList)
      view.tabs.append({
        id = getTabId(i)
        object = wb.haveAnyOrdinaryRequirements()? ::g_warbonds_view.getCurrentLevelItemMarkUp(wb) : null
        navImagesText = ::get_navigation_images_text(i, wbList.len())
        unseenIcon = bhvUnseen.makeConfigStr(SEEN.WARBONDS_SHOP, wb.getSeenId())
      })

    local data = ::handyman.renderCached("gui/frameHeaderTabs", view)
    local tabsObj = getTabsListObj()
    guiScene.replaceContentFromText(tabsObj, data, data.len(), this)

    tabsObj.setValue(0)
    updateTabsTexts()
  }

  function getTabId(idx)
  {
    return "warbond_tab_" + idx
  }

  function getTabsListObj()
  {
    return scene.findObject("tabs_list")
  }

  function getItemsListObj()
  {
    return scene.findObject("items_list")
  }

  function onTabChange(obj)
  {
    if (!obj || !wbList.len())
      return

    markCurrentPageSeen()

    local i = obj.getValue()
    curWbIdx = (i in wbList) ? i : 0
    curWb = wbList[curWbIdx]
    curPage = 0
    initItemsProgress()
    fillPage()
    updateBalance()
    updateTabsTexts() //to reccount tabs textarea colors
  }

  function initItemsListSize()
  {
    guiScene.applyPendingChanges(false)

    local itemHeightWithSpace = "1@itemHeight+1@itemSpacing"
    local itemWidthWithSpace = "1@itemWidth+1@itemSpacing"
    local mainBlockHeight = "@rh-2@frameHeaderHeight-1@frameFooterHeight-1@bottomMenuPanelHeight-0.08@scrn_tgt-1@blockInterval"
    local itemsCountX = ::to_pixels("@rw-1@shopInfoMinWidth-3@itemSpacing")
      / ::max(1, ::to_pixels(itemWidthWithSpace))
    local itemsCountY = ::to_pixels(mainBlockHeight)
      / ::max(1, ::to_pixels(itemHeightWithSpace))
    local contentWidth = $"{itemsCountX}*({itemWidthWithSpace})+1@itemSpacing"
    scene.findObject("main_block").height = mainBlockHeight
    showSceneBtn("nav_separator", false)
    getItemsListObj().width = contentWidth
    scene.findObject("empty_items_list").width = contentWidth
    scene.findObject("item_info_nest").width = "fw"
    scene.findObject("shop_level_progress_place").left = $"0.5({contentWidth})-0.5w"
    scene.findObject("special_tasks_progress_block").pos = $"0.5({contentWidth})+0.5pw-0.5w,0.5ph-0.5h"
    scene.findObject("paginator_place").left = $"0.5({contentWidth})-0.5w"
    itemsPerPage = (itemsCountX * itemsCountY ).tointeger()
  }

  function updateCurPageAwardsList()
  {
    curPageAwards.clear()
    if (!curWb)
      return

    local fullList = curWb.getAwardsList()
    local pageStartIndex = curPage * itemsPerPage
    local pageEndIndex = min((curPage + 1) * itemsPerPage, fullList.len())
    for(local i=pageStartIndex; i < pageEndIndex; i++)
      curPageAwards.append(fullList[i])
  }

  function fillPage()
  {
    updateCurPageAwardsList()

    local view = {
      items = curPageAwards
      enableBackground = true
      hasButton = true
      hasFocusBorder = true
      onHover = "onItemHover"
      tooltipFloat = "left"
    }

    local listObj = getItemsListObj()
    local data = ::handyman.renderCached(("gui/items/item"), view)
    listObj.enable(data != "")
    guiScene.replaceContentFromText(listObj, data, data.len(), this)

    local value = listObj.getValue()
    local total = curPageAwards.len()
    if (total && value >= total)
      listObj.setValue(total - 1)
    if (value < 0)
      listObj.setValue(0)
    ::move_mouse_on_child_by_value(listObj)

    updateItemInfo()

    updatePaginator()
  }

  function updatePaginator()
  {
    local totalPages = curWb ? ::ceil(curWb.getAwardsList().len().tofloat() / itemsPerPage) : 1
    ::generatePaginator(scene.findObject("paginator_place"), this,
      curPage, totalPages - 1, null, true /*show last page*/)
  }

  function goToPage(obj)
  {
    markCurrentPageSeen()
    goToPageIdx(obj.to_page.tointeger())
  }

  function goToPageIdx(idx)
  {
    curPage = idx
    fillPage()
  }

  function getCurAward()
  {
    local value = getItemsListObj().getValue()
    return ::getTblValue(value, curPageAwards)
  }

  function getCurAwardObj()
  {
    local itemListObj = getItemsListObj()
    local value = ::get_obj_valid_index(itemListObj)
    if (value < 0)
      return null

    return itemListObj.getChild(value)
  }

  function fillItemDesc(award)
  {
    local obj = scene.findObject("item_info")
    local hasItemDesc = award != null && award.fillItemDesc(obj, this)
    obj.show(hasItemDesc)
  }

  function fillCommonDesc(award)
  {
    local obj = scene.findObject("common_info")
    local hasCommonDesc = award != null && award.hasCommonDesc()
    obj.show(hasCommonDesc)
    if (!hasCommonDesc)
      return

    obj.findObject("info_name").setValue(award.getNameText())
    obj.findObject("info_desc").setValue(award.getDescText())

    local iconObj = obj.findObject("info_icon")
    iconObj.doubleSize = award.imgNestDoubleSize
    local imageData = award.getDescriptionImage()
    guiScene.replaceContentFromText(iconObj, imageData, imageData.len(), this)
  }

  function updateItemInfo()
  {
    local award = getCurAward()
    markAwardSeen(award)
    fillItemDesc(award)
    fillCommonDesc(award)
    showSceneBtn("jumpToDescPanel", ::show_console_buttons && award != null)
    updateButtons()
  }

  function updateButtonsBar() {
    local obj = getItemsListObj()
    local isButtonsVisible = !::show_console_buttons || (::check_obj(obj) && obj.isHovered())
    showSceneBtn("item_actions_bar", isButtonsVisible)
    return isButtonsVisible
  }

  function updateButtons()
  {
    if (::has_feature("BattlePass"))
      showSceneBtn("btn_battlePass", !::isHandlerInScene(::gui_handlers.BattlePassWnd))

    if (!updateButtonsBar()) //buttons below are hidden if item action bar is hidden
      return

    local award = getCurAward()
    showSceneBtn("btn_specialTasks", award != null
      && award.isRequiredSpecialTasksComplete()
      && !::isHandlerInScene(::gui_handlers.BattleTasksWnd)
    )

    local mainActionBtn = showSceneBtn("btn_main_action", award != null)
    if (!award)
      return

    if (::check_obj(mainActionBtn))
    {
      mainActionBtn.visualStyle = "purchase"
      mainActionBtn.inactiveColor = award.canBuy() ? "no" : "yes"
      setColoredDoubleTextToButton(scene, "btn_main_action", award.getBuyText(false))
    }
  }

  function updateBalance()
  {
    local text = ""
    local tooltip = ""
    if (curWb)
    {
      text = ::loc("warbonds/currentAmount", { warbonds = curWb.getBalanceText() })
      tooltip = ::loc("warbonds/maxAmount", { warbonds = ::g_warbonds.getLimit() })
    }
    local textObj = scene.findObject("balance_text")
    textObj.setValue(text)
    textObj.tooltip = tooltip
  }

  function updateAwardPrices()
  {
    local listObj = getItemsListObj()
    local total = ::min(listObj.childrenCount(), curPageAwards.len())
    for(local i = 0; i < total; i++)
    {
      local childObj = listObj.getChild(i)
      local priceObj = childObj.findObject("price")
      if (!::checkObj(priceObj)) //price obj always exist in item. so it check that childObj valid
        continue

      priceObj.setValue(curPageAwards[i].getCostText())

      local isAllBought = curPageAwards[i].isAllBought()
      local iconObj = childObj.findObject("all_bougt_icon")
      if (::checkObj(iconObj))
      {
        iconObj.show(isAllBought)
        priceObj.show(!isAllBought)
      }

      local btnObj = childObj.findObject("actionBtn")
      if (isAllBought && ::checkObj(btnObj))
        guiScene.destroyElement(btnObj)
    }
  }

  function updateTabsTexts()
  {
    local tabsObj = getTabsListObj()
    foreach(idx, wb in wbList)
    {
      local id = getTabId(idx) + "_text"
      local obj = tabsObj.findObject(id)
      if (!::checkObj(obj))
        continue

      local timeText = ""
      local timeLeft = wb.getChangeStateTimeLeft()
      if (timeLeft > 0)
      {
        timeText = time.hoursToString(time.secondsToHours(timeLeft), false, true)
        timeText = " " + ::loc("ui/parentheses", { text = timeText })
      }
      obj.setValue(timeText)
    }
  }

  function onTimer(obj, dt)
  {
    updateTabsTexts()
  }

  function initItemsProgress()
  {
    local showAnyShopProgress = ::g_warbonds_view.showOrdinaryProgress(curWb)
    local progressPlaceObj = scene.findObject("shop_level_progress_place")
    progressPlaceObj.show(showAnyShopProgress)

    local isShopInactive = !curWb || !curWb.isCurrent()
    if (showAnyShopProgress)
    {
      local oldShopObj = progressPlaceObj.findObject("old_shop_progress_place")
      oldShopObj.show(isShopInactive)

      ::g_warbonds_view.createProgressBox(curWb, progressPlaceObj, this, isShopInactive)
      if (isShopInactive)
      {
        local data = ::g_warbonds_view.getCurrentLevelItemMarkUp(curWb)
        guiScene.replaceContentFromText(oldShopObj.findObject("level_icon"), data, data.len(), this)
      }
    }

    local showAnyMedalProgress = ::g_warbonds_view.showSpecialProgress(curWb)
    local medalsPlaceObj = scene.findObject("special_tasks_progress_block")
    medalsPlaceObj.show(showAnyMedalProgress)
    if (showAnyMedalProgress)
      ::g_warbonds_view.createSpecialMedalsProgress(curWb, medalsPlaceObj, this)
  }

  function onItemAction(buttonObj)
  {
    local fullAwardId = buttonObj?.holderId
    if (!fullAwardId)
      return
    local wbAward = ::g_warbonds.getWarbondAwardByFullId(fullAwardId)
    if (wbAward)
      buyAward(wbAward)
  }

  function onMainAction(obj)
  {
    buyAward()
  }

  function buyAward(wbAward = null)
  {
    if (!wbAward)
      wbAward = getCurAward()
    if (wbAward)
      wbAward.buy()
  }

  function markAwardSeen(award)
  {
    if (award == null || award.isItemLocked())
      return

    seenWarbondsShop.markSeen(award.getSeenId())
  }

  function markCurrentPageSeen()
  {
    if (curPageAwards == null || curWb == null)
      return

    local pageStartIndex = curPage * itemsPerPage
    local pageEndIndex = min((curPage + 1) * itemsPerPage, curPageAwards.len())
    local list = []
    for(local i = pageStartIndex; i < pageEndIndex; ++i)
      if (!curPageAwards[i].isItemLocked())
        list.append(curPageAwards[i].getSeenId())
    seenWarbondsShop.markSeen(list)
  }

  function onShowBattlePass()
  {
    openBattlePassWnd()
  }

  function onShowSpecialTasks(obj)
  {
    ::gui_start_battle_tasks_wnd(null, BattleTasksWndTab.BATTLE_TASKS_HARD)
  }

  function onEventWarbondAwardBought(p)
  {
    guiScene.setUpdatesEnabled(false, false)
    updateBalance()
    updateAwardPrices()
    updateItemInfo()
    guiScene.setUpdatesEnabled(true, true)
  }

  function onEventProfileUpdated(p)
  {
    updateBalance()
  }

  function onEventBattleTasksFinishedUpdate(p)
  {
    updateItemInfo()
  }

  function onEventItemsShopUpdate(p)
  {
    doWhenActiveOnce("fillPage")
  }

  function onDestroy()
  {
    markCurrentPageSeen()
    local activeWb = ::g_warbonds.getCurrentWarbond()
    if (activeWb)
      activeWb.markSeenLastResearchShopLevel()
  }

  function onEventBeforeStartShowroom(params)
  {
    ::handlersManager.requestHandlerRestore(this, ::gui_handlers.MainMenu)
  }

  function onEventBeforeStartTestFlight(params)
  {
    ::handlersManager.requestHandlerRestore(this, ::gui_handlers.MainMenu)
  }

  function getHandlerRestoreData()
  {
    return {
      openData = {
        filterFunc = filterFunc
        curWbIdx   = curWbIdx
      }
      stateData = {
        curAwardId = getCurAward()?.id
      }
    }
  }

  function restoreHandler(stateData)
  {
    local fullList = curWb.getAwardsList()
    foreach (i, v in fullList)
      if (v.id == stateData.curAwardId)
      {
        goToPageIdx(::ceil(i / itemsPerPage).tointeger())
        getItemsListObj().setValue(i % itemsPerPage)
        break
      }
  }

  function onItemsListFocusChange() {
    if (isValid())
      updateButtons()
  }

  function onJumpToDescPanelAccessKey(obj)
  {
    if (!::show_console_buttons)
      return
    local containerObj = scene.findObject("item_info_nest")
    if (::check_obj(containerObj) && containerObj.isHovered())
      ::move_mouse_on_obj(getCurAwardObj())
    else
      ::move_mouse_on_obj(containerObj)
  }

  function onItemHover(obj) {
    if (!::show_console_buttons)
      return
    hoverHoldAction(obj, function(focusObj) {
      local id = focusObj?.holderId
      local value = curPageAwards.findindex(@(a) a.getFullId() == id)
      local listObj = getItemsListObj()
      if (value != null && listObj.getValue() != value)
        listObj.setValue(value)
    }.bindenv(this))
  }

  //dependence by blk
  function onToShopButton(obj) {}
  function onToMarketplaceButton(obj) {}
  function onItemPreview(obj) {}
  function onOpenCraftTree(obj) {}
  function onLinkAction(obj) {}
  function onAltAction(obj) {}
  function onChangeSortOrder(obj) {}
  onChangeSortParam = @(obj) null
}
