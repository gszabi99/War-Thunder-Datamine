let time = require("%scripts/time.nut")
let bhvUnseen = require("%scripts/seen/bhvUnseen.nut")
let seenWarbondsShop = require("%scripts/seen/seenList.nut").get(SEEN.WARBONDS_SHOP)
let { setColoredDoubleTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let mkHoverHoldAction = require("%sqDagui/timer/mkHoverHoldAction.nut")
let { openBattlePassWnd } = require("%scripts/battlePass/battlePassWnd.nut")
let { canStartPreviewScene } = require("%scripts/customization/contentPreview.nut")

::gui_handlers.WarbondsShop <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/items/itemsShop.blk"

  filterFunc = null

  wbList = null
  curWbIdx = 0
  curWb = null
  curPage = 0
  curPageAwards = null
  itemsPerPage = 1

  slotbarActions = [ "preview", "testflight", "sec_weapons", "weapons", "info" ]

  hoverHoldAction = null
  isMouseMode = true

  function initScreen()
  {
    wbList = ::g_warbonds.getList(filterFunc)
    if (!wbList.len())
      return goBack()

    updateMouseMode()
    updateShowItemButton()
    let infoObj = scene.findObject("item_info")
    guiScene.replaceContent(infoObj, "%gui/items/itemDesc.blk", this)

    curPageAwards = []
    if (!(curWbIdx in wbList))
      curWbIdx = 0
    curWb = wbList[curWbIdx]

    let obj = scene.findObject("warbond_shop_progress_block")
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
    let view = { tabs = [] }
    foreach(i, wb in wbList)
      view.tabs.append({
        id = getTabId(i)
        object = wb.haveAnyOrdinaryRequirements()? ::g_warbonds_view.getCurrentLevelItemMarkUp(wb) : null
        navImagesText = ::get_navigation_images_text(i, wbList.len())
        unseenIcon = bhvUnseen.makeConfigStr(SEEN.WARBONDS_SHOP, wb.getSeenId())
      })

    let data = ::handyman.renderCached("%gui/frameHeaderTabs", view)
    let tabsObj = getTabsListObj()
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

    let i = obj.getValue()
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

    let itemHeightWithSpace = "1@itemHeight+1@itemSpacing"
    let itemWidthWithSpace = "1@itemWidth+1@itemSpacing"
    let mainBlockHeight = "@rh-2@frameHeaderHeight-1@frameFooterHeight-1@bottomMenuPanelHeight-0.08@scrn_tgt-1@blockInterval"
    let itemsCountX = ::max(::to_pixels("@rw-1@shopInfoMinWidth-3@itemSpacing")
      / ::max(1, ::to_pixels(itemWidthWithSpace)), 1)
    let itemsCountY = ::max(::to_pixels(mainBlockHeight)
      / ::max(1, ::to_pixels(itemHeightWithSpace)), 1)
    let contentWidth = $"{itemsCountX}*({itemWidthWithSpace})+1@itemSpacing"
    scene.findObject("main_block").height = mainBlockHeight
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

    let fullList = curWb.getAwardsList()
    let pageStartIndex = curPage * itemsPerPage
    let pageEndIndex = min((curPage + 1) * itemsPerPage, fullList.len())
    for(local i=pageStartIndex; i < pageEndIndex; i++)
      curPageAwards.append(fullList[i])
  }

  function fillPage()
  {
    updateCurPageAwardsList()

    let view = {
      items = curPageAwards
      enableBackground = true
      hasButton = true
      hasFocusBorder = true
      onHover = "onItemHover"
      tooltipFloat = "left"
    }

    let listObj = getItemsListObj()
    let data = ::handyman.renderCached(("%gui/items/item"), view)
    listObj.enable(data != "")
    guiScene.replaceContentFromText(listObj, data, data.len(), this)

    let value = listObj.getValue()
    let total = curPageAwards.len()
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
    let totalPages = curWb ? ::ceil(curWb.getAwardsList().len().tofloat() / itemsPerPage) : 1
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
    let value = getItemsListObj().getValue()
    return ::getTblValue(value, curPageAwards)
  }

  function getCurAwardObj()
  {
    let itemListObj = getItemsListObj()
    let value = ::get_obj_valid_index(itemListObj)
    if (value < 0)
      return null

    return itemListObj.getChild(value)
  }

  function fillItemDesc(award)
  {
    let obj = scene.findObject("item_info")
    let hasItemDesc = award != null && award.fillItemDesc(obj, this)
    obj.show(hasItemDesc)
  }

  function fillCommonDesc(award)
  {
    let obj = scene.findObject("common_info")
    let hasCommonDesc = award != null && award.hasCommonDesc()
    obj.show(hasCommonDesc)
    if (!hasCommonDesc)
      return

    obj.findObject("info_name").setValue(award.getNameText())
    obj.findObject("info_desc").setValue(award.getDescText())

    let iconObj = obj.findObject("info_icon")
    iconObj.doubleSize = award.imgNestDoubleSize
    let imageData = award.getDescriptionImage()
    guiScene.replaceContentFromText(iconObj, imageData, imageData.len(), this)
  }

  function updateItemInfo()
  {
    let award = getCurAward()
    markAwardSeen(award)
    fillItemDesc(award)
    fillCommonDesc(award)
    showSceneBtn("jumpToDescPanel", ::show_console_buttons && award != null)
    updateButtons()
  }

  function updateButtonsBar() {
    let obj = getItemsListObj()
    let isButtonsVisible =  isMouseMode || (::check_obj(obj) && obj.isHovered())
    showSceneBtn("item_actions_bar", isButtonsVisible)
    return isButtonsVisible
  }

  function updateButtons()
  {
    if (::has_feature("BattlePass"))
      showSceneBtn("btn_battlePass", !::isHandlerInScene(::gui_handlers.BattlePassWnd))

    if (!updateButtonsBar()) //buttons below are hidden if item action bar is hidden
      return

    let award = getCurAward()
    showSceneBtn("btn_specialTasks", award != null
      && award.isRequiredSpecialTasksComplete()
      && !::isHandlerInScene(::gui_handlers.BattleTasksWnd)
    )

    showSceneBtn("btn_preview", (award?.canPreview() ?? false) && ::isInMenu())

    let mainActionBtn = showSceneBtn("btn_main_action", award != null)
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
    let textObj = scene.findObject("balance_text")
    textObj.setValue(text)
    textObj.tooltip = tooltip
  }

  function updateAwardPrices()
  {
    let listObj = getItemsListObj()
    let total = ::min(listObj.childrenCount(), curPageAwards.len())
    for(local i = 0; i < total; i++)
    {
      let childObj = listObj.getChild(i)
      let priceObj = childObj.findObject("price")
      if (!::checkObj(priceObj)) //price obj always exist in item. so it check that childObj valid
        continue

      priceObj.setValue(curPageAwards[i].getCostText())

      let isAllBought = curPageAwards[i].isAllBought()
      let iconObj = childObj.findObject("all_bougt_icon")
      if (::checkObj(iconObj))
      {
        iconObj.show(isAllBought)
        priceObj.show(!isAllBought)
      }

      let btnObj = childObj.findObject("actionBtn")
      if (isAllBought && ::checkObj(btnObj))
        guiScene.destroyElement(btnObj)
    }
  }

  function updateTabsTexts()
  {
    let tabsObj = getTabsListObj()
    foreach(idx, wb in wbList)
    {
      let id = getTabId(idx) + "_text"
      let obj = tabsObj.findObject(id)
      if (!::checkObj(obj))
        continue

      local timeText = ""
      let timeLeft = wb.getChangeStateTimeLeft()
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
    let showAnyShopProgress = ::g_warbonds_view.showOrdinaryProgress(curWb)
    let progressPlaceObj = scene.findObject("shop_level_progress_place")
    progressPlaceObj.show(showAnyShopProgress)

    let isShopInactive = !curWb || !curWb.isCurrent()
    if (showAnyShopProgress)
    {
      let oldShopObj = progressPlaceObj.findObject("old_shop_progress_place")
      oldShopObj.show(isShopInactive)

      ::g_warbonds_view.createProgressBox(curWb, progressPlaceObj, this, isShopInactive)
      if (isShopInactive)
      {
        let data = ::g_warbonds_view.getCurrentLevelItemMarkUp(curWb)
        guiScene.replaceContentFromText(oldShopObj.findObject("level_icon"), data, data.len(), this)
      }
    }

    let showAnyMedalProgress = ::g_warbonds_view.showSpecialProgress(curWb)
    let medalsPlaceObj = scene.findObject("special_tasks_progress_block")
    medalsPlaceObj.show(showAnyMedalProgress)
    if (showAnyMedalProgress)
      ::g_warbonds_view.createSpecialMedalsProgress(curWb, medalsPlaceObj, this)
  }

  function onItemAction(buttonObj)
  {
    let fullAwardId = buttonObj?.holderId
    if (!fullAwardId)
      return
    let wbAward = ::g_warbonds.getWarbondAwardByFullId(fullAwardId)
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

    let pageStartIndex = curPage * itemsPerPage
    let pageEndIndex = min((curPage + 1) * itemsPerPage, curPageAwards.len())
    let list = []
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
    let activeWb = ::g_warbonds.getCurrentWarbond()
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
    let fullList = curWb.getAwardsList()
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
    let containerObj = scene.findObject("item_info_nest")
    if (::check_obj(containerObj) && containerObj.isHovered())
      ::move_mouse_on_obj(getCurAwardObj())
    else
      ::move_mouse_on_obj(containerObj)
  }

  function onItemHover(obj) {
    if (!::show_console_buttons)
      return
    let wasMouseMode = isMouseMode
    updateMouseMode()
    if (wasMouseMode != isMouseMode)
      updateShowItemButton()
    if (isMouseMode)
      return
    if (obj.holderId == getCurAwardObj()?.holderId)
      return
    hoverHoldAction(obj, function(focusObj) {
      let id = focusObj?.holderId
      let value = curPageAwards.findindex(@(a) a.getFullId() == id)
      let listObj = getItemsListObj()
      if (value != null && listObj.getValue() != value)
        listObj.setValue(value)
    }.bindenv(this))
  }

  function onItemPreview(obj) {
    if (!isValid())
      return

    let award = getCurAward()
    if (award && canStartPreviewScene(true, true))
      award.doPreview()
  }

  //dependence by blk
  function onToShopButton(obj) {}
  function onToMarketplaceButton(obj) {}
  function onOpenCraftTree(obj) {}
  function onLinkAction(obj) {}
  function onAltAction(obj) {}
  function onChangeSortOrder(obj) {}
  onChangeSortParam = @(obj) null
  updateMouseMode = @() isMouseMode = !::show_console_buttons || ::is_mouse_last_time_used()
  function updateShowItemButton() {
    let listObj = getItemsListObj()
    if (listObj?.isValid())
      listObj.showItemButton = isMouseMode ? "yes" : "no"
  }
}
