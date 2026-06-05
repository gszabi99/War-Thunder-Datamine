from "%scripts/dagui_library.nut" import *

let { purchaseConfirmation } = require("%scripts/purchase/purchaseConfirmationHandler.nut")
let { eventsCfg } = require("%appGlobals/config/specEventsCfg.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { setBreadcrumbGoBackParams } = require("%scripts/breadcrumb.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { getUnlockById, getAllUnlocksWithBlkOrder } = require("%scripts/unlocks/unlocksCache.nut")
let { getTimestampFromStringUtc, buildDateStr } = require("%scripts/time.nut")
let { get_local_unixtime } = require("dagor.time")
let { warningIfGold } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { openUnlockManually, buyUnlock } = require("%scripts/unlocks/unlocksAction.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { getUnitName } = require("%scripts/unit/unitInfo.nut")
let { deferOnce } = require("dagor.workcycle")
let { toggleUnlockFavButton, initUnlockFavInContainer
} = require("%scripts/unlocks/favoriteUnlocks.nut")
let {
  buildConditionsConfig, getUnlockMainCondDescByCfg, getUnlockNameText,
  getUnlockCondsDescByCfg, getUnlockMultDescByCfg
} = require("%scripts/unlocks/unlocksState.nut")
let {
  fillUnlockImage, fillUnlockProgressBar, fillUnlockPurchaseButton,
  fillUnlockManualOpenButton, canPreviewUnlockPrize, doPreviewUnlockPrize
} = require("%scripts/unlocks/unlocksViewModule.nut")
let {
  getUnlockCost, findUnusableUnitForManualUnlock, canClaimUnlockReward,
  isUnlockComplete, isUnlockOpened
} = require("%scripts/unlocks/unlocksModule.nut")


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
    return loc("mainmenu/dataStartTimeShort", { time = buildDateStr(endTs) })

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
    return loc("mainmenu/taskStartTime", { time = buildDateStr(endTs) })

  return loc("mainmenu/taskRemaningTime", { time = buildDateStr(endTs) })
}

local SpecEvents = class (gui_handlers.BaseGuiHandlerWT) {
  wndType         = handlerType.BASE
  sceneBlkName    = "%gui/unlocks/specEventsModal.blk"
  emptyOrderBlk   = "%gui/unlocks/specEventsOrders.blk"
  emptyRewardBlk  = "%gui/unlocks/specEventsRewards.blk"

  chaptersCache = null
  eventsCache = null
  selectedEventKey = null
  selectedOrderValue = null
  eventOffsetIdx = 0
  maxViewEvents = 0

  function initScreen() {
    this.selectedOrderValue = null
    this.prepareEventsUnlocks()
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
      foreach (groupId in eventCfg.groups)
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
  }

  function updateNavBar() {
    if (this.selectedEventKey == null)
      setBreadcrumbGoBackParams(this)
    else
      this.scene.findObject("back_scene_name").setValue(loc("mainmenu/btnBack"))
  }

  function updateEventsScreen() {
    if (this.selectedEventKey == null)
      this.updateEventsList()
    else
      this.updateOrdersList()
  }

  function updateEventsPaginator() {
    let hasNextBtn = this.eventOffsetIdx + this.eventsCache.len() >= this.maxViewEvents
    this.scene.findObject("prevEventBtn").enable(this.eventOffsetIdx <= 0)
    this.scene.findObject("nextEventBtn").enable(hasNextBtn)
  }

  function updateEventsList() {
    let currTs = get_local_unixtime()
    let eventsList = this.eventsCache.values().sort(@(a, b) a.endTs <=> b.endTs)

    this.maxViewEvents = min(to_pixels("@rw") / to_pixels("@eventSlotWidth") - 1, eventsList.len())
    this.scene.findObject("eventsBlock").width = $"{this.maxViewEvents}@eventSlotWidth"
    this.updateEventsPaginator()

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
          isLocked = currTs > beginTs
          progBar = array(completed, { bgcolor = "@cardProgressFGColor" })
            .extend(array(total - completed, { bgcolor = "@cardProgressBGColor" }))
        }
      })
    }
    let objIdxToScroll = eventsList.findindex(@(v)
      (v.beginTs == -1 || v.beginTs >= currTs) && (v.endTs == -1 || v.endTs < currTs)
    ) ?? eventsList.len() - 1

    showObjById("ordersContainer", false, this.scene)
    showObjById("rewardsContainer", false, this.scene)
    showObjById("eventsButtons", true, this.scene)
    let eventsContainerObj = showObjById("eventsContainer", true, this.scene)
    let markup = handyman.renderCached("%gui/unlocks/specEvents.tpl", view)
    this.guiScene.replaceContentFromText(eventsContainerObj, markup, markup.len(), this)

    let objToScroll = eventsContainerObj.findObject($"event_{objIdxToScroll}")
    objToScroll.scrollToView(true)
  }

  function fillReward(unlockBlk, containerObj, completed) {
    let unlockCfg = buildConditionsConfig(unlockBlk)
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
      { completed, total = num })
    containerObj.findObject("achivment_ico_nest").tooltip = colorize("unlockHeaderColor",
      loc("mainmenu/awardTrophy"))

    let previewPrizeBtnObj = containerObj.findObject("preview_prize_btn")
    previewPrizeBtnObj.show(canPreviewUnlockPrize(unlockCfg))
    previewPrizeBtnObj.unlockId = unlockCfg.id
  }

  function updateOrdersList() {
    showObjById("eventsContainer", false, this.scene)
    showObjById("eventsButtons", false, this.scene)

    let rewardsList = this.chaptersCache?[this.selectedEventKey.split("/")?[0]] ?? []
    let rewardsCount = rewardsList.len()
    let rewardsContainerObj = showObjById("rewardsContainer", true, this.scene)
    let addRewardsCount = rewardsCount - rewardsContainerObj.childrenCount()
    if (addRewardsCount > 0)
      this.guiScene.createMultiElementsByObject(rewardsContainerObj, this.emptyRewardBlk,
        "tdiv", addRewardsCount, this)

    let ordersList = this.eventsCache?[this.selectedEventKey].orders ?? []
    let completed = ordersList.filter(function(order) {
      let { unlockCfg } = order
      let { id } = unlockCfg
      return isUnlockComplete(unlockCfg) || isUnlockOpened(id)
    }).len()

    for (local i = 0; i < rewardsContainerObj.childrenCount(); i++) {
      let child = rewardsContainerObj.getChild(i)
      child.show(rewardsCount > i)
      if (rewardsCount <= i)
        continue

      let isLast = i == rewardsList.len() - 1
      child.findObject("reward_container").width = isLast ? "2@rewardSlotWidth" : "@rewardSlotWidth"
      showObjById("bg_image", isLast, child)
      showObjById("last_vertical_line", isLast, child)

      this.fillReward(rewardsList[i], child, completed)
    }

    let ordersCount = ordersList.len()
    let ordersContainerObj = showObjById("ordersContainer", true, this.scene)
    let addOrdersCount = ordersCount - ordersContainerObj.childrenCount()
    if (addOrdersCount > 0)
      this.guiScene.createMultiElementsByObject(ordersContainerObj, this.emptyOrderBlk,
        "expandable", addOrdersCount, this)

    for (local i = 0; i < ordersContainerObj.childrenCount(); i++) {
      let child = ordersContainerObj.getChild(i)
      child.show(ordersCount > i)
      if (ordersCount <= i)
        continue

      let order = ordersList[i]
      let { unlockCfg } = order
      let { id } = unlockCfg
      let isCompleted = isUnlockComplete(unlockCfg) || isUnlockOpened(id)

      fillUnlockImage(unlockCfg, child)
      fillUnlockProgressBar(unlockCfg, child)
      fillUnlockPurchaseButton(unlockCfg, child)
      initUnlockFavInContainer(unlockCfg.id, child)

      child.findObject("status_text").setValue(getOrderStatusText(order, isCompleted))
      child.findObject("main_cond_text").setValue(getUnlockMainCondDescByCfg(unlockCfg))

      child.tooltip = "{0}\n{1}".subst(
        getUnlockCondsDescByCfg(unlockCfg, ["timeRange"]), getUnlockMultDescByCfg(unlockCfg)
      )
    }
  }

  function onEventClick(obj) {
    this.selectedEventKey = obj.eventKey
    this.updateNavBar()
    this.updateEventsScreen()
  }

  function applyEventOffset() {
    this.scene.findObject("eventsContainer").left = $"{this.eventOffsetIdx}@eventSlotWidth"
    this.updateEventsPaginator()
  }

  function onMovePrevEvent() {
    if (this.eventOffsetIdx > 0)
      return

    this.eventOffsetIdx++
    this.applyEventOffset()
  }

  function onMoveNextEvent() {
    if (this.eventOffsetIdx + this.eventsCache.len() < this.maxViewEvents)
      return

    this.eventOffsetIdx--
    this.applyEventOffset()
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

  function goBack() {
    if (this.selectedEventKey == null)
      base.goBack()
    else {
      this.selectedEventKey = null
      this.updateNavBar()
      this.updateEventsScreen()
    }
  }
}

gui_handlers.SpecEvents <- SpecEvents

let openSpecEventsWnd = @() handlersManager.loadHandler(SpecEvents)

return {
  openSpecEventsWnd
}
