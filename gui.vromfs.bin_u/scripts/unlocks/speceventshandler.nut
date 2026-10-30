from "%scripts/purchase/purchaseConfirmationHandler.nut" import purchaseConfirmation
from "%scripts/sqDagui/framework/handlerType.nut" import handlerType
from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler
from "%scripts/mainmenu/mainMenuHandler.nut" import MainMenu
from "%scripts/baseGuiHandlerWT.nut" import BaseGuiHandlerWT
from "%scripts/breadcrumb.nut" import setBreadcrumbGoBackParams
from "%sqStdLibs/helpers/handyman.nut" import handyman
from "%scripts/unlocks/unlocksCache.nut" import getUnlockById, getAllUnlocksWithBlkOrder
from "%scripts/time.nut" import getTimestampFromStringUtc, buildDateStr
from "%scripts/viewUtils/objectTextUpdate.nut" import warningIfGold
from "%scripts/unlocks/unlocksAction.nut" import openUnlockManually, buyUnlock
from "%scripts/unit/unitInfo.nut" import getUnitName
from "%scripts/items/itemsManagerModule.nut" import findItemById
from "%scripts/items/trophyRewardList.nut" import openUnlockPrizesList
from "%scripts/popups/popupFilterWidget.nut" import openPopupFilter, RESET_ID, SELECT_ALL_ID
from "%scripts/unlocks/favoriteUnlocks.nut" import toggleUnlockFavButton, initUnlockFavInContainer
from "%scripts/unlocks/unlocksState.nut" import buildConditionsConfig, getUnlockMainCondDescByCfg, getUnlockNameText, getUnlockCondsDescByCfg, getUnlockMultDescByCfg
from "%scripts/unlocks/unlocksViewModule.nut" import fillUnlockTitle, fillUnlockImage, fillUnlockProgressBar, fillUnlockPurchaseButton, fillUnlockManualOpenButton, canPreviewUnlockPrize, doPreviewUnlockPrize
from "%appGlobals/config/specEventsCfg.nut" import eventsCfg, eventsFilters
from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent
from "%appGlobals/login/loginState.nut" import isProfileReceived
from "dagor.time" import get_local_unixtime
from "dagor.workcycle" import deferOnce
from "math" import ceil
from "%scripts/unlocks/unlocksModule.nut" import getUnlockCost, findUnusableUnitForManualUnlock, canClaimUnlockReward, isUnlockComplete, isUnlockOpened, getUnlockCompletedVal
from "%scripts/dagui_library.nut" import *

let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")

const DEFAULT_CARDS_COUNT = 11

function getEventActive(data) {
  let { beginTs, endTs } = data
  let currTs = get_local_unixtime()
  return beginTs < currTs && endTs > currTs
}


function getEventStatusText(data) {
  let { beginTs, endTs } = data
  let currTs = get_local_unixtime()
  if (currTs > endTs)
    return loc("mainmenu/dataFinishedTimeShort", { time = buildDateStr(endTs) })

  if (currTs < beginTs)
    return loc("mainmenu/dataStartTimeShort", { time = buildDateStr(beginTs) })

  return loc("mainmenu/dataRemaningTimeShort", { time = buildDateStr(endTs) })
}


function getOrderStatusText(data, isCompleted) {
  if (isCompleted)
    return loc("mainmenu/taskCompleted")

  let { beginTs, endTs } = data
  let currTs = get_local_unixtime()
  if (currTs > endTs)
    return loc("mainmenu/taskOverdueTime", { time = buildDateStr(endTs) })

  if (currTs < beginTs)
    return loc("mainmenu/taskStartTime", { time = buildDateStr(beginTs) })

  return loc("mainmenu/taskRemaningTime", { time = buildDateStr(endTs) })
}

let SpecEvents = class (BaseGuiHandlerWT) {
  wndType         = handlerType.BASE
  sceneBlkName    = "%gui/unlocks/specEventsModal.blk"
  emptyOrderBlk   = "%gui/unlocks/specEventsOrders.blk"
  emptyRewardBlk  = "%gui/unlocks/specEventsRewards.blk"

  chaptersCache = null
  eventsCache = null
  eventsCacheFiltered = null
  selectedEventKey = null
  selectedOrderValue = null
  maxViewEvents = 0
  filtersWidget = null
  selectedFilters = null

  function initScreen() {
    this.selectedOrderValue = null
    this.prepareEventsUnlocks()
    this.applyEventsFilter()
    this.updateNavBar()
    this.updateEventsScreen()
  }

  function prepareEventsUnlocks() {
    if (this.eventsCache != null)
      return

    this.chaptersCache = {}
    this.eventsCache = {}

    let ordersGroups = {}
    foreach (eventKey, eventCfg in eventsCfg) {
      let [ chapter ] = eventKey.split("/")
      this.chaptersCache[chapter] <- []
      foreach (groupId in (eventCfg?.groups ?? []))
        ordersGroups[groupId] <- eventKey
    }

    foreach (unlockBlk in getAllUnlocksWithBlkOrder()) {
      let { chapter = "", group = ""} = unlockBlk
      let eventId = $"{chapter}/{group}"
      if (chapter in this.chaptersCache && group == "")
        this.chaptersCache[chapter].append(unlockBlk)
      else if (eventId in ordersGroups) {
        let eventKey = ordersGroups[eventId]
        if (eventKey not in this.eventsCache)
          this.eventsCache[eventKey] <- {
            eventKey
            beginTs = -1
            endTs = -1
            orders = []
          }

        let { id, locId = null, mode = null } = unlockBlk
        let { beginDate = null, endDate = null } = mode == null ? null
          : (mode % "condition").findvalue(@(v) v?.type == "timeRange")
              ?? (mode % "hostCondition").findvalue(@(v) v?.type == "timeRange")

        let beginTs = beginDate == null ? -1 : getTimestampFromStringUtc(beginDate)
        let endTs = endDate == null ? -1 : getTimestampFromStringUtc(endDate)

        if (this.eventsCache[eventKey].beginTs == -1 || this.eventsCache[eventKey].beginTs > beginTs)
          this.eventsCache[eventKey].beginTs = beginTs
        if (this.eventsCache[eventKey].endTs == -1 || this.eventsCache[eventKey].endTs < endTs)
          this.eventsCache[eventKey].endTs = endTs

        let unlockCfg = buildConditionsConfig(unlockBlk)
        this.eventsCache[eventKey].orders.append({
          id, locId, beginTs, endTs, unlockCfg
        })
      }
    }

    foreach (eventKey, eventCfg in eventsCfg)
      if (eventKey not in this.eventsCache) {
        let { beginTs = 0, endTs = 0 } = eventCfg
        this.eventsCache[eventKey] <- {
          eventKey
          beginTs
          endTs = max(beginTs, endTs)
          orders = []
          isFake = true
        }
      }
  }

  function applyEventsFilter() {
    let filters = this.selectedFilters ?? {}
    this.eventsCacheFiltered = this.eventsCache
      .filter(function(_event, id) {
        let { unitType = null } = eventsCfg[id]
        return unitType == null
          || filters.len() == 0
          || (filters?[$"unitType_{unitType}"] ?? false)
      })
  }

  function updateNavBar() {
    if (this.selectedEventKey == null)
      setBreadcrumbGoBackParams(this)
    else
      this.scene.findObject("back_scene_name").setValue(loc("mainmenu/btnBack"))
  }

  function updateEventsScreen(fromGoBack = false) {
    if (this.selectedEventKey == null) {
      this.updateEventsFilter()
      this.updateEventsList(!fromGoBack)
    }
    else
      this.updateOrdersList()
  }

  function updateEventsPaginator(listBox) {
    let scrollX = listBox.getScrollX()
    let slotWidth = to_pixels("1@eventSlotWidth + 1@eSItemMargin")
    let needShowLeft = scrollX > (slotWidth / 2)
    let needShowRight= scrollX < ((listBox.childrenCount() - this.maxViewEvents) * slotWidth - slotWidth/2)

    this.scene.findObject("prevEventBtn").enable(needShowLeft)
    this.scene.findObject("nextEventBtn").enable(needShowRight)
    showObjById("prevEventBg", needShowLeft, this.scene)
    showObjById("nextEventBg", needShowRight, this.scene)
  }

  function updateEventsList(autoScrollToEvent = true) {
    let currTs = get_local_unixtime()
    let eventsList = this.eventsCacheFiltered.values().sortby(@(a) a.endTs)

    let navBtn = this.scene.findObject("prevEventBtn")
    let btnSize = navBtn.getSize()

    let slotWidth = to_pixels("1@eventSlotWidth + 1@eSItemMargin")
    let maxVisibleSlots = ((to_pixels("@rw") - btnSize[0]*2)/ slotWidth)
    this.maxViewEvents = min(maxVisibleSlots, eventsList.len())

    let listWidth = $"{this.maxViewEvents}*{slotWidth} + 1"
    this.scene.findObject("eventsNest").width = listWidth
    let eventsListObj = showObjById("eventsContainer", true, this.scene)
    eventsListObj.width = listWidth

    let rewardsList = this.chaptersCache
    let view = {
      events = eventsList.map(function(event, idx) {
        let { eventKey, beginTs } = event
        let rewards = rewardsList?[eventKey.split("/")?[0]] ?? []
        let total = rewards.len()
        let completed = rewards.filter(@(unlockBlk)
          isUnlockComplete(buildConditionsConfig(unlockBlk))).len()

        return {
          eventKey, total, completed
          eventId = $"event_{idx}"
          isActive = getEventActive(event)
          bgImage = eventsCfg?[eventKey].bgImage
          nameText = loc(eventsCfg?[eventKey].eventLocId ?? "")
          statusText = getEventStatusText(event)
          isLocked = currTs < beginTs
          progBar = array(completed, { bgcolor = "@cardProgressFGColor" })
            .extend(array(total - completed, { bgcolor = "@cardProgressBGColor" }))
        }
      })
    }

    showObjById("rewardsAndOrdersContainer", false, this.scene)
    showObjById("filter_nest", true, this.scene)
    let markup = handyman.renderCached("%gui/unlocks/specEvents.tpl", view)
    this.guiScene.replaceContentFromText(eventsListObj, markup, markup.len(), this)

    if (autoScrollToEvent) {
      let objIdxToScroll = eventsList.findindex(@(v)
        (v.beginTs == -1 || v.beginTs <= currTs) && (v.endTs == -1 || v.endTs > currTs)
        ) ?? eventsList.len() - 1

      eventsListObj.scrollToX(slotWidth * objIdxToScroll)
    }

    let reqPaginator = this.eventsCacheFiltered.len() > this.maxViewEvents
    if (reqPaginator)
      this.updateEventsPaginator(eventsListObj)

    showObjById("eventsButtons", reqPaginator, this.scene)
  }

  function updateEventsFilter() {
    let obj = this.scene.findObject("filter_nest")
    let popupFilterHandler = openPopupFilter({
      scene = obj
      btnTitle = loc("tournaments/filters")
      btnName = "RB"
      popupAlign = "bottom"
      onChangeFn = this.applyFilter.bindenv(this)
      filterTypesFn = this.getFilterList.bindenv(this)
    })
    this.filtersWidget = popupFilterHandler.weakref()
  }

  function applyFilter(objId, _objName, value) {
    if (this.selectedFilters == null)
      this.selectedFilters = {}

    if (objId == RESET_ID)
      this.selectedFilters = {}
    else if (objId == SELECT_ALL_ID) {
      foreach (filterData in eventsFilters)
        this.selectedFilters[filterData.id] <- true
    }
    else if (value)
      this.selectedFilters[objId] <- value
    else
      this.selectedFilters.$rawdelete(objId)

    this.applyEventsFilter()
    this.updateEventsList()
  }

  function getFilterList() {
    let res = []
    foreach (filterData in eventsFilters) {
      res.append({
        text = loc(filterData.locId)
        id = filterData.id
        value = this.selectedFilters?[filterData.id] ?? false
      })
    }
    return [{ checkbox = res }]
  }

  function findRewardCard(obj) {
    local card = obj
    while (card?.isValid() && (card?.isSpecEventOrder ?? "") != "yes")
      card = card.getParent()
    return card
  }

  function isRewardBtnsNestHovered(cardObj, btnsNestObj) {
    return cardObj.isMouseOver() || btnsNestObj.isMouseOver()
  }

  function setRewardCardActive(cardObj, isActive) {
    if (!cardObj?.isValid())
      return
    let state = isActive ? "yes" : "no"
    cardObj.hoverActive = state
    let nest = cardObj.findObject("rewardBtnsNest")
    if (nest?.isValid())
      nest.showHidden = state
  }

  function showRewardBtnsNestExclusive(cardObj) {
    let container = cardObj.getParent()
    if (!container?.isValid())
      return
    for (local i = 0; i < container.childrenCount(); i++) {
      let card = container.getChild(i)
      this.setRewardCardActive(card, card.isEqual(cardObj))
    }
  }

  function onOrderRewardHover(obj) {
    if (!obj?.isValid())
      return
    this.showRewardBtnsNestExclusive(obj)
  }

  function onOrderRewardUnhover(obj) {
    if (!obj?.isValid())
      return
    let btnsNest = obj.findObject("rewardBtnsNest")
    if (!btnsNest?.isValid())
      return
    this.setRewardCardActive(obj, this.isRewardBtnsNestHovered(obj, btnsNest))
  }

  function onOrderRewardBtnsUnhover(obj) {
    if (!obj?.isValid())
      return
    let cardObj = this.findRewardCard(obj)
    if (!cardObj?.isValid())
      return
    let nest = cardObj.findObject("rewardBtnsNest")
    if (!nest?.isValid())
      return
    this.setRewardCardActive(cardObj, this.isRewardBtnsNestHovered(cardObj, nest))
  }

  function fillReward(unlockBlk, unlockCfg, containerObj) {
    let hasCompleted = isUnlockComplete(unlockCfg)
    let hasFinished = hasCompleted && !canClaimUnlockReward(unlockCfg.id)
    let { num = "" } = unlockBlk?.mode

    fillUnlockImage(unlockCfg, containerObj)
    fillUnlockManualOpenButton(unlockCfg, containerObj)

    showObjById("locked_sign", !hasFinished && !hasCompleted, containerObj)
    showObjById("complete_img", hasFinished, containerObj)
    containerObj.findObject("progress_bar").setValue(hasCompleted ? 1000 : 0)
    containerObj.findObject("progress_icon")["background-image"] = hasCompleted
      ? "#ui/gameuiskin#default_unlocked.avif"
      : "#ui/gameuiskin#default_locked.avif"

    let progValueTxtObj = containerObj.findObject("progress_value")
    progValueTxtObj.overlayTextColor = hasCompleted ? "premium" : "premiumNotEarned"
    progValueTxtObj.setValue(num.tostring())

    containerObj.findObject("progress_nest").tooltip = loc("mainmenu/taskMarksReceived",
      { completed = getUnlockCompletedVal(unlockCfg), total = num })
    containerObj.findObject("achivment_ico_nest").tooltip = colorize("unlockHeaderColor",
      loc("mainmenu/awardTrophy"))

    let previewPrizeBtnObj = containerObj.findObject("preview_prize_btn")
    previewPrizeBtnObj.show(canPreviewUnlockPrize(unlockCfg))
    previewPrizeBtnObj.unlockId = unlockCfg.id

    let showPrizesBtnObj = containerObj.findObject("show_prizes_btn")
    showPrizesBtnObj.show(unlockCfg?.trophyId != null)
    showPrizesBtnObj.trophyId = unlockCfg?.trophyId ?? ""
  }

  function updateOrdersList() {
    showObjById("eventsContainer", false, this.scene)
    showObjById("eventsButtons", false, this.scene)
    showObjById("filter_nest", false, this.scene)

    let currTs = get_local_unixtime()
    let rewardsList = this.chaptersCache?[this.selectedEventKey.split("/")?[0]] ?? []
    let rewardsCount = rewardsList.len()

    let rewardsAndOrdersContainer = showObjById("rewardsAndOrdersContainer", true, this.scene)
    let rewardsContainerObj = rewardsAndOrdersContainer.findObject("rewardsContainer")
    let addRewardsCount = rewardsCount - rewardsContainerObj.childrenCount()
    if (addRewardsCount > 0)
      this.guiScene.createMultiElementsByObject(rewardsContainerObj, this.emptyRewardBlk,
        "specEventsReward", addRewardsCount, this)

    let ordersList = this.eventsCacheFiltered?[this.selectedEventKey].orders ?? []

    local bigRewardIdx = rewardsList.findindex(@(r) r?.isMainReward ?? false) ?? -1
    let defaultRewardSlotWidth = to_pixels("156@sf/@pf")
    let totalWidth = DEFAULT_CARDS_COUNT * defaultRewardSlotWidth

    for (local i = 0; i < rewardsContainerObj.childrenCount(); i++) {
      let child = rewardsContainerObj.getChild(i)
      child.show(rewardsCount > i)
      if (rewardsCount <= i)
        continue

      let unlockBlk = rewardsList[i]
      let { userLogId = "", isMainReward = false } = unlockBlk
      let unlockCfg = buildConditionsConfig(unlockBlk)
      let trophy = findItemById(userLogId)
      let content = trophy?.getContent() ?? []

      local isBigReward = isMainReward
      if (bigRewardIdx < 0) {
        if (i == rewardsList.len() - 1 || content.findindex(@(c) (c?.unit ?? "") != "") != null) {
          bigRewardIdx = i
          isBigReward = true
        }
      }

      showObjById("bg_image", isBigReward, child)
      showObjById("last_vertical_line", isBigReward, child)
      this.fillReward(unlockBlk, unlockCfg, child)
    }

    let bigSlotsWidth = defaultRewardSlotWidth * 2
    let smallSlotsCount = max(rewardsCount - 1, 1)
    let rewardSlotWidth = (totalWidth - bigSlotsWidth) / smallSlotsCount

    for (local i = 0; i < rewardsCount; i++) {
      let child = rewardsContainerObj.getChild(i)
      let isBigReward = i == bigRewardIdx
      child.findObject("reward_container").width = isBigReward
        ? bigSlotsWidth
        : rewardSlotWidth

      child.findObject("achivment_ico_nest")["max-width"] = isBigReward ? bigSlotsWidth : defaultRewardSlotWidth
    }

    let containersWidth = $"{totalWidth} + {rewardsCount + 1}*@dp"
    rewardsAndOrdersContainer.width = containersWidth

    let ordersCount = ordersList.len()
    let ordersContainerObj = rewardsAndOrdersContainer.findObject("ordersContainer")
    let addOrdersCount = ordersCount - ordersContainerObj.childrenCount()
    if (addOrdersCount > 0)
      this.guiScene.createMultiElementsByObject(ordersContainerObj, this.emptyOrderBlk,
        "expandable", addOrdersCount, this)

    let ordersPerRow = 2
    let lastRowStartIdx = (ceil(ordersCount.tofloat() / ordersPerRow) - 1) * ordersPerRow
    for (local i = 0; i < ordersContainerObj.childrenCount(); i++) {
      let child = ordersContainerObj.getChild(i)
      child.show(ordersCount > i)
      if (ordersCount <= i)
        continue

      child["isLastRow"] = i >= lastRowStartIdx ? "yes" : "no"

      let order = ordersList[i]
      let { unlockCfg, beginTs, endTs } = order
      let { id } = unlockCfg
      let isActive = (beginTs == -1 || beginTs <= currTs) && (endTs == -1 || endTs > currTs)
      let isCompleted = isUnlockComplete(unlockCfg) || isUnlockOpened(id)

      fillUnlockImage(unlockCfg, child)
      fillUnlockProgressBar(unlockCfg, child)
      fillUnlockPurchaseButton(unlockCfg, child)
      showObjById("checkbox_favorites", isActive && !isCompleted, child)
      if (isActive && !isCompleted)
        initUnlockFavInContainer(unlockCfg.id, child)

      fillUnlockTitle(unlockCfg, child)
      child.findObject("status_text").setValue(getOrderStatusText(order, isCompleted))
      child.findObject("main_cond_text").setValue(getUnlockMainCondDescByCfg(unlockCfg))

      child.tooltip = "{0}\n{1}".subst(
        getUnlockCondsDescByCfg(unlockCfg, ["timeRange"]), getUnlockMultDescByCfg(unlockCfg)
      )
    }
  }

  function onEventClick(listObj) {
    let selectedId = listObj.getValue()
    if (selectedId < 0 || (selectedId > listObj.childrenCount() - 1))
      return
    let obj = listObj.getChild(selectedId)

    let { eventKey } = obj
    if (this.eventsCache[eventKey]?.isFake ?? false)
      return

    this.selectedEventKey = eventKey
    this.updateNavBar()
    this.updateEventsScreen()
  }

  function scrollByEventCount(scrollCount) {
    let eventsListObj = this.scene.findObject("eventsContainer")
    let slotWidth = to_pixels("1@eventSlotWidth + 1@eSItemMargin")
    let scrollX = eventsListObj.getScrollX()
    let curEventIdx = ceil(scrollX.tofloat() / slotWidth)
    eventsListObj.scrollToX((curEventIdx + scrollCount) * slotWidth)
  }

  function onMovePrevEvent() {
    this.scrollByEventCount(-1)
  }

  function onMoveNextEvent() {
    this.scrollByEventCount(1)
  }

  function onBuyUnlock(obj) {
    let unlockId = obj?.unlockId
    if (unlockId == null)
      return

    let cost = getUnlockCost(unlockId)
    let text = warningIfGold(loc("onlineShop/needMoneyQuestion", {
      purchase = colorize("unlockHeaderColor", getUnlockNameText(-1, unlockId))
      cost = cost.getTextAccordingToBalance()
    }), cost)

    let onSuccessCb = Callback(@() this.updateOrdersList(), this)
    let callbackYes = @() buyUnlock(unlockId, function() {
      broadcastEvent("UpdateGamercard")
      onSuccessCb()
    })
    purchaseConfirmation({ id = "question_buy_unlock", text, callbackYes }, cost)
  }

  function getButtonObj(btnName) {
    if (this.selectedOrderValue == null)
      return null

    let rewardsContainerObj = this.scene.findObject("ordersContainer")
    let child = rewardsContainerObj.getChild(this.selectedOrderValue)
    if (!(child?.isValid() ?? false))
      return null

    return child.findObject(btnName)
  }

  function onTryBuyUnlock(_obj) {
    let btnObj = this.getButtonObj("purchase_button")
    if ((btnObj?.isValid() ?? false) && btnObj.isVisible())
      this.onBuyUnlock(btnObj)
  }

  function onOrderSelect(obj) {
    this.selectedOrderValue = obj.getValue()
  }

  function unlockToFavorites(obj) {
    toggleUnlockFavButton(obj)
  }

  function onTryMarkAsFavorites(_obj) {
    let btnObj = this.getButtonObj("checkbox_favorites")
    if ((btnObj?.isValid() ?? false) && btnObj.isVisible())
      toggleUnlockFavButton(btnObj)
  }

  function onManualOpenUnlock(obj) {
    let unlockId = obj?.unlockId ?? ""
    if (unlockId == "")
      return

    let unit = findUnusableUnitForManualUnlock(unlockId)
    if (unit) {
      this.msgBox("cantClaimReward", loc("msgbox/cantClaimManualUnlockPrize",
        { unitname = getUnitName(unit) }), [["ok"]], "ok")
      return
    }

    let onSuccessCb = Callback(@() this.updateOrdersList(), this)
    openUnlockManually(unlockId, function() {
      broadcastEvent("UpdateGamercard")
      onSuccessCb()
    })
  }

  function onPrizePreview(obj) {
    let unlockCfg = buildConditionsConfig(getUnlockById(obj.unlockId))
    deferOnce(@() doPreviewUnlockPrize(unlockCfg))
  }

  function showUnlockPrizes(obj) {
    openUnlockPrizesList(obj.trophyId)
  }

  function goBack() {
    if (this.selectedEventKey == null)
      base.goBack()
    else {
      this.selectedEventKey = null
      this.updateNavBar()
      this.updateEventsScreen(true)
    }
  }

  function getHandlerRestoreData() {
    return {
      openData = {
        selectedEventKey = this.selectedEventKey
      }
    }
  }

  function onEventBeforeStartShowroom(_p) {
    handlersManager.requestHandlerRestore(this, MainMenu)
  }

  function onEventUnlocksCacheInvalidate(_p) {
    if (isProfileReceived.get()) {
      this.eventsCache = null
      this.initScreen()
    }
  }

  function onEventRegionalUnlocksChanged(_p) {
    this.eventsCache = null
    this.initScreen()
  }

  function onEventUnlockMarkersCacheInvalidate(_p) {
    if (isProfileReceived.get()) {
      this.eventsCache = null
      this.initScreen()
    }
  }

  function onEventInventoryUpdate(_p) {
    if (this.selectedEventKey != null)
      this.updateOrdersList()
  }
}

register_gui_handler("SpecEvents", SpecEvents)

let openSpecEventsWnd = @() handlersManager.loadHandler(SpecEvents)

return freeze({
  openSpecEventsWnd
})
