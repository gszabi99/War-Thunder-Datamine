//-file:plus-string
from "%scripts/dagui_library.nut" import *
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let time = require("%scripts/time.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { ceil } = require("math")
let { getObjValidIndex } = require("%sqDagui/daguiUtil.nut")
let bhvUnseen = require("%scripts/seen/bhvUnseen.nut")
let seenWarbondsShop = require("%scripts/seen/seenList.nut").get(SEEN.WARBONDS_SHOP)
let { setColoredDoubleTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let mkHoverHoldAction = require("%sqDagui/timer/mkHoverHoldAction.nut")
let { openBattlePassWnd } = require("%scripts/battlePass/battlePassWnd.nut")
let { canStartPreviewScene } = require("%scripts/customization/contentPreview.nut")

::gui_handlers.WarbondsShop <- class extends ::gui_handlers.BaseGuiHandlerWT {
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

  function initScreen() {
    this.wbList = ::g_warbonds.getList(this.filterFunc)
    if (!this.wbList.len())
      return this.goBack()

    this.updateMouseMode()
    this.updateShowItemButton()
    let infoObj = this.scene.findObject("item_info")
    this.guiScene.replaceContent(infoObj, "%gui/items/itemDesc.blk", this)

    this.curPageAwards = []
    if (!(this.curWbIdx in this.wbList))
      this.curWbIdx = 0
    this.curWb = this.wbList[this.curWbIdx]

    let obj = this.scene.findObject("warbond_shop_progress_block")
    if (checkObj(obj))
      obj.show(true)

    this.initItemsListSize()
    this.fillTabs()
    this.updateBalance()
    ::move_mouse_on_child(this.getItemsListObj(), 0)

    this.scene.findObject("update_timer").setUserData(this)
    this.hoverHoldAction = mkHoverHoldAction(this.scene.findObject("hover_hold_timer"))
  }

  function fillTabs() {
    let view = { tabs = [] }
    foreach (i, wb in this.wbList)
      view.tabs.append({
        id = this.getTabId(i)
        object = wb.haveAnyOrdinaryRequirements() ? ::g_warbonds_view.getCurrentLevelItemMarkUp(wb) : null
        navImagesText = ::get_navigation_images_text(i, this.wbList.len())
        unseenIcon = bhvUnseen.makeConfigStr(SEEN.WARBONDS_SHOP, wb.getSeenId())
      })

    let data = handyman.renderCached("%gui/frameHeaderTabs.tpl", view)
    let tabsObj = this.getTabsListObj()
    this.guiScene.replaceContentFromText(tabsObj, data, data.len(), this)

    tabsObj.setValue(0)
    this.updateTabsTexts()
  }

  function getTabId(idx) {
    return "warbond_tab_" + idx
  }

  function getTabsListObj() {
    return this.scene.findObject("tabs_list")
  }

  function getItemsListObj() {
    return this.scene.findObject("items_list")
  }

  function onTabChange(obj) {
    if (!obj || !this.wbList.len())
      return

    this.markCurrentPageSeen()

    let i = obj.getValue()
    this.curWbIdx = (i in this.wbList) ? i : 0
    this.curWb = this.wbList[this.curWbIdx]
    this.curPage = 0
    this.initItemsProgress()
    this.fillPage()
    this.updateBalance()
    this.updateTabsTexts() //to reccount tabs textarea colors
  }

  function initItemsListSize() {
    this.guiScene.applyPendingChanges(false)

    let itemHeightWithSpace = "1@itemHeight+1@itemSpacing"
    let itemWidthWithSpace = "1@itemWidth+1@itemSpacing"
    let mainBlockHeight = "@rh-2@frameHeaderHeight-1@frameFooterHeight-1@bottomMenuPanelHeight-0.08@scrn_tgt-1@blockInterval"
    let itemsCountX = max(to_pixels("@rw-1@shopInfoMinWidth-3@itemSpacing")
      / max(1, to_pixels(itemWidthWithSpace)), 1)
    let itemsCountY = max(to_pixels(mainBlockHeight)
      / max(1, to_pixels(itemHeightWithSpace)), 1)
    let contentWidth = $"{itemsCountX}*({itemWidthWithSpace})+1@itemSpacing"
    this.scene.findObject("main_block").height = mainBlockHeight
    this.getItemsListObj().width = contentWidth
    this.scene.findObject("empty_items_list").width = contentWidth
    this.scene.findObject("item_info_nest").width = "fw"
    this.scene.findObject("shop_level_progress_place").left = $"0.5({contentWidth})-0.5w"
    this.scene.findObject("special_tasks_progress_block").pos = $"0.5({contentWidth})+0.5pw-0.5w,0.5ph-0.5h"
    this.scene.findObject("paginator_place").left = $"0.5({contentWidth})-0.5w"
    this.itemsPerPage = (itemsCountX * itemsCountY).tointeger()
  }

  function updateCurPageAwardsList() {
    this.curPageAwards.clear()
    if (!this.curWb)
      return

    let fullList = this.curWb.getAwardsList()
    let pageStartIndex = this.curPage * this.itemsPerPage
    let pageEndIndex = min((this.curPage + 1) * this.itemsPerPage, fullList.len())
    for (local i = pageStartIndex; i < pageEndIndex; i++)
      this.curPageAwards.append(fullList[i])
  }

  function fillPage() {
    this.updateCurPageAwardsList()

    let view = {
      items = this.curPageAwards
      enableBackground = true
      hasButton = true
      hasFocusBorder = true
      onHover = "onItemHover"
      tooltipFloat = "left"
    }

    let listObj = this.getItemsListObj()
    let data = handyman.renderCached(("%gui/items/item.tpl"), view)
    listObj.enable(data != "")
    this.guiScene.replaceContentFromText(listObj, data, data.len(), this)

    let value = listObj.getValue()
    let total = this.curPageAwards.len()
    if (total && value >= total)
      listObj.setValue(total - 1)
    if (value < 0)
      listObj.setValue(0)
    ::move_mouse_on_child_by_value(listObj)

    this.updateItemInfo()

    this.updatePaginator()
  }

  function updatePaginator() {
    let totalPages = this.curWb ? ceil(this.curWb.getAwardsList().len().tofloat() / this.itemsPerPage) : 1
    ::generatePaginator(this.scene.findObject("paginator_place"), this,
      this.curPage, totalPages - 1, null, true /*show last page*/ )
  }

  function goToPage(obj) {
    this.markCurrentPageSeen()
    this.goToPageIdx(obj.to_page.tointeger())
  }

  function goToPageIdx(idx) {
    this.curPage = idx
    this.fillPage()
  }

  function getCurAward() {
    let value = this.getItemsListObj().getValue()
    return getTblValue(value, this.curPageAwards)
  }

  function getCurAwardObj() {
    let itemListObj = this.getItemsListObj()
    let value = getObjValidIndex(itemListObj)
    if (value < 0)
      return null

    return itemListObj.getChild(value)
  }

  function fillItemDesc(award) {
    let obj = this.scene.findObject("item_info")
    let hasItemDesc = award != null && award.fillItemDesc(obj, this)
    obj.show(hasItemDesc)
  }

  function fillCommonDesc(award) {
    let obj = this.scene.findObject("common_info")
    let hasCommonDesc = award != null && award.hasCommonDesc()
    obj.show(hasCommonDesc)
    if (!hasCommonDesc)
      return

    obj.findObject("info_name").setValue(award.getNameText())
    obj.findObject("info_desc").setValue(award.getDescText())

    let iconObj = obj.findObject("info_icon")
    iconObj.doubleSize = award.imgNestDoubleSize
    let imageData = award.getDescriptionImage()
    this.guiScene.replaceContentFromText(iconObj, imageData, imageData.len(), this)
  }

  function updateItemInfo() {
    let award = this.getCurAward()
    this.markAwardSeen(award)
    this.fillItemDesc(award)
    this.fillCommonDesc(award)
    this.showSceneBtn("jumpToDescPanel", ::show_console_buttons && award != null)
    this.updateButtons()
  }

  function updateButtonsBar() {
    let obj = this.getItemsListObj()
    let isButtonsVisible =  this.isMouseMode || (checkObj(obj) && obj.isHovered())
    this.showSceneBtn("item_actions_bar", isButtonsVisible)
    return isButtonsVisible
  }

  function updateButtons() {
    if (hasFeature("BattlePass"))
      this.showSceneBtn("btn_battlePass", !::isHandlerInScene(::gui_handlers.BattlePassWnd))

    if (!this.updateButtonsBar()) //buttons below are hidden if item action bar is hidden
      return

    let award = this.getCurAward()
    this.showSceneBtn("btn_specialTasks", award != null
      && award.isRequiredSpecialTasksComplete()
      && !::isHandlerInScene(::gui_handlers.BattleTasksWnd)
    )

    this.showSceneBtn("btn_preview", (award?.canPreview() ?? false) && ::isInMenu())

    let mainActionBtn = this.showSceneBtn("btn_main_action", award != null)
    if (!award)
      return

    if (checkObj(mainActionBtn)) {
      mainActionBtn.visualStyle = "purchase"
      mainActionBtn.inactiveColor = award.canBuy() ? "no" : "yes"
      setColoredDoubleTextToButton(this.scene, "btn_main_action", award.getBuyText(false))
    }
  }

  function updateBalance() {
    local text = ""
    local tooltip = ""
    if (this.curWb) {
      text = loc("warbonds/currentAmount", { warbonds = this.curWb.getBalanceText() })
      tooltip = loc("warbonds/maxAmount", { warbonds = ::g_warbonds.getLimit() })
    }
    let textObj = this.scene.findObject("balance_text")
    textObj.setValue(text)
    textObj.tooltip = tooltip
  }

  function updateAwardPrices() {
    let listObj = this.getItemsListObj()
    let total = min(listObj.childrenCount(), this.curPageAwards.len())
    for (local i = 0; i < total; i++) {
      let childObj = listObj.getChild(i)
      let priceObj = childObj.findObject("price")
      if (!checkObj(priceObj)) //price obj always exist in item. so it check that childObj valid
        continue

      priceObj.setValue(this.curPageAwards[i].getCostText())

      let isAllBought = this.curPageAwards[i].isAllBought()
      let iconObj = childObj.findObject("all_bougt_icon")
      if (checkObj(iconObj)) {
        iconObj.show(isAllBought)
        priceObj.show(!isAllBought)
      }

      let btnObj = childObj.findObject("actionBtn")
      if (isAllBought && checkObj(btnObj))
        this.guiScene.destroyElement(btnObj)
    }
  }

  function updateTabsTexts() {
    let tabsObj = this.getTabsListObj()
    foreach (idx, wb in this.wbList) {
      let id = this.getTabId(idx) + "_text"
      let obj = tabsObj.findObject(id)
      if (!checkObj(obj))
        continue

      local timeText = ""
      let timeLeft = wb.getChangeStateTimeLeft()
      if (timeLeft > 0) {
        timeText = time.hoursToString(time.secondsToHours(timeLeft), false, true)
        timeText = " " + loc("ui/parentheses", { text = timeText })
      }
      obj.setValue(timeText)
    }
  }

  function onTimer(_obj, _dt) {
    this.updateTabsTexts()
  }

  function initItemsProgress() {
    let showAnyShopProgress = ::g_warbonds_view.showOrdinaryProgress(this.curWb)
    let progressPlaceObj = this.scene.findObject("shop_level_progress_place")
    progressPlaceObj.show(showAnyShopProgress)

    let isShopInactive = !this.curWb || !this.curWb.isCurrent()
    if (showAnyShopProgress) {
      let oldShopObj = progressPlaceObj.findObject("old_shop_progress_place")
      oldShopObj.show(isShopInactive)

      ::g_warbonds_view.createProgressBox(this.curWb, progressPlaceObj, this, isShopInactive)
      if (isShopInactive) {
        let data = ::g_warbonds_view.getCurrentLevelItemMarkUp(this.curWb)
        this.guiScene.replaceContentFromText(oldShopObj.findObject("level_icon"), data, data.len(), this)
      }
    }

    let showAnyMedalProgress = ::g_warbonds_view.showSpecialProgress(this.curWb)
    let medalsPlaceObj = this.scene.findObject("special_tasks_progress_block")
    medalsPlaceObj.show(showAnyMedalProgress)
    if (showAnyMedalProgress)
      ::g_warbonds_view.createSpecialMedalsProgress(this.curWb, medalsPlaceObj, this)
  }

  function onItemAction(buttonObj) {
    let fullAwardId = buttonObj?.holderId
    if (!fullAwardId)
      return
    let wbAward = ::g_warbonds.getWarbondAwardByFullId(fullAwardId)
    if (wbAward)
      this.buyAward(wbAward)
  }

  function onMainAction(_obj) {
    this.buyAward()
  }

  function buyAward(wbAward = null) {
    if (!wbAward)
      wbAward = this.getCurAward()
    if (wbAward)
      wbAward.buy()
  }

  function markAwardSeen(award) {
    if (award == null || award.isItemLocked())
      return

    seenWarbondsShop.markSeen(award.getSeenId())
  }

  function markCurrentPageSeen() {
    if (this.curPageAwards == null || this.curWb == null)
      return

    let pageStartIndex = this.curPage * this.itemsPerPage
    let pageEndIndex = min((this.curPage + 1) * this.itemsPerPage, this.curPageAwards.len())
    let list = []
    for (local i = pageStartIndex; i < pageEndIndex; ++i)
      if (!this.curPageAwards[i].isItemLocked())
        list.append(this.curPageAwards[i].getSeenId())
    seenWarbondsShop.markSeen(list)
  }

  function onShowBattlePass() {
    openBattlePassWnd()
  }

  function onShowSpecialTasks(_obj) {
    ::gui_start_battle_tasks_wnd(null, BattleTasksWndTab.BATTLE_TASKS_HARD)
  }

  function onEventWarbondAwardBought(_p) {
    this.guiScene.setUpdatesEnabled(false, false)
    this.updateBalance()
    this.updateAwardPrices()
    this.updateItemInfo()
    this.guiScene.setUpdatesEnabled(true, true)
  }

  function onEventProfileUpdated(_p) {
    this.updateBalance()
  }

  function onEventBattleTasksFinishedUpdate(_p) {
    this.updateItemInfo()
  }

  function onEventItemsShopUpdate(_p) {
    this.doWhenActiveOnce("fillPage")
  }

  function onDestroy() {
    this.markCurrentPageSeen()
    let activeWb = ::g_warbonds.getCurrentWarbond()
    if (activeWb)
      activeWb.markSeenLastResearchShopLevel()
  }

  function onEventBeforeStartShowroom(_params) {
    ::handlersManager.requestHandlerRestore(this, ::gui_handlers.MainMenu)
  }

  function onEventBeforeStartTestFlight(_params) {
    ::handlersManager.requestHandlerRestore(this, ::gui_handlers.MainMenu)
  }

  function getHandlerRestoreData() {
    return {
      openData = {
        filterFunc = this.filterFunc
        curWbIdx   = this.curWbIdx
      }
      stateData = {
        curAwardId = this.getCurAward()?.id
      }
    }
  }

  function restoreHandler(stateData) {
    let fullList = this.curWb.getAwardsList()
    foreach (i, v in fullList)
      if (v.id == stateData.curAwardId) {
        this.goToPageIdx(ceil(i / this.itemsPerPage).tointeger())
        this.getItemsListObj().setValue(i % this.itemsPerPage)
        break
      }
  }

  function onItemsListFocusChange() {
    if (this.isValid())
      this.updateButtons()
  }

  function onJumpToDescPanelAccessKey(_obj) {
    if (!::show_console_buttons)
      return
    let containerObj = this.scene.findObject("item_info_nest")
    if (checkObj(containerObj) && containerObj.isHovered())
      ::move_mouse_on_obj(this.getCurAwardObj())
    else
      ::move_mouse_on_obj(containerObj)
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
    if (obj.holderId == this.getCurAwardObj()?.holderId)
      return
    this.hoverHoldAction(obj, function(focusObj) {
      let id = focusObj?.holderId
      let value = this.curPageAwards.findindex(@(a) a.getFullId() == id)
      let listObj = this.getItemsListObj()
      if (value != null && listObj.getValue() != value)
        listObj.setValue(value)
    }.bindenv(this))
  }

  function onItemPreview(_obj) {
    if (!this.isValid())
      return

    let award = this.getCurAward()
    if (award && canStartPreviewScene(true, true))
      award.doPreview()
  }

  //dependence by blk
  function onToShopButton(_obj) {}
  function onToMarketplaceButton(_obj) {}
  function onOpenCraftTree(_obj) {}
  function onLinkAction(_obj) {}
  function onAltAction(_obj) {}
  function onChangeSortOrder(_obj) {}
  onChangeSortParam = @(_obj) null
  updateMouseMode = @() this.isMouseMode = !::show_console_buttons || ::is_mouse_last_time_used()
  function updateShowItemButton() {
    let listObj = this.getItemsListObj()
    if (listObj?.isValid())
      listObj.showItemButton = this.isMouseMode ? "yes" : "no"
  }
}
