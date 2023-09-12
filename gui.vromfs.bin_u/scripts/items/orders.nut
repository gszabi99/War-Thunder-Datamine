//-file:plus-string
from "%scripts/dagui_library.nut" import *
let { INVALID_SQUAD_ID } = require("matching.errors")
let u = require("%sqStdLibs/helpers/u.nut")
let { HUD_MSG_OBJECTIVE } = require("hudMessages")
let { get_mplayer_by_id, get_game_type, get_local_mplayer } = require("mission")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { debug_dump_stack } = require("dagor.debug")
let { registerPersistentDataFromRoot, PERSISTENT_DATA_PARAMS } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")
let { format } = require("string")
let time = require("%scripts/time.nut")
let subscriptions = require("%sqStdLibs/helpers/subscriptions.nut")
let { add_event_listener, broadcastEvent } = subscriptions
let spectatorWatchedHero = require("%scripts/replays/spectatorWatchedHero.nut")
let { is_replay_playing } = require("replays")
let { get_time_msec } = require("dagor.time")
let { send } = require("eventbus")
let { get_mp_tbl_teams } = require("guiMission")

const AUTO_ACTIVATE_TIME = 60
/**
 * This method is called from within C++.
 * Triggered only when some player gets a reward.
 */
::on_order_result_received <- function on_order_result_received(player, _orderId, param, _wp, _exp) {
  // Parameter 'orderId' comes as a string (e.g. "::g_orders.activeOrder.orderId")
  // this is a misleading naming. But 'winnerScoreDataByOrderId' uses actual
  // orderId so here is an assumption that order in 'g_orders' is still active.
  let actualOrderId = ::g_orders.activeOrder.orderId
  ::g_orders.winnerScoreDataByOrderId[actualOrderId] <- {
    playerId = player
    score = param
  }
}

::g_orders <- {
  [PERSISTENT_DATA_PARAMS] = ["hasActiveOrder", "activeOrder", "activeLocalOrderIds", "timesUsedByOrderItemId",
                              "prevActiveOrder", "cooldownTimeleft", "winnerScoreDataByOrderId",
                              "orderStatusPosition", "orderStatusSize"
                             ]

  autoActivateHint = loc("guiHints/order_auto_activate",
    { time = $"{AUTO_ACTIVATE_TIME} {loc("mainmenu/seconds")}" })
  hasActiveOrder = false
  activeOrder = {
    orderId = -1
    orderObjective = null
    orderType = ::g_order_type.UNKNOWN
    orderStatus = ::g_objective_status.UNKNOWN
    orderItem = null
    starterPlayer = null
    targetPlayer = null
    timeToSwitchTarget = -1

    // Handyman status text view-object.
    // Used both for active and finished
    // orders but with different templates.
    // For sake of simplicity it is used in
    // status text bottom as well.
    statusTextView = {}
  }
  activatingLocalOrderId = null
  activatingLocalOrderCallback = null
  activeLocalOrderIds = []
  timesUsedByOrderItemId = {}

  // Order which was active before current.
  // Used to show info about order result.
  prevActiveOrder = null

  cooldownTimeleft = 0

  // This is a cache object.
  // Use 'getPlayerDataById' to access.
  playerDataById = {}

  maxRowsInScoreTable = 3

  statusColorScheme = {
    typeDescriptionColor = "unlockActiveColor"
    parameterValueColor = "unlockActiveColor"
    parameterLabelColor = "userlogColoredText"
    objectiveDescriptionColor = "unlockActiveColor"
  }

  emptyColorScheme = {
    typeDescriptionColor = ""
    parameterValueColor = ""
    parameterLabelColor = ""
    objectiveDescriptionColor = ""
  }

  listenersEnabled = false
  ordersStatusObj = null

  // Null-object.
  emptyPlayerData = {
    name = ""
    clanTag = ""
    aircraftName = ""
    id = -1
    team = -1
    isLocal = false
    isInHeroSquad = false
    squadId = INVALID_SQUAD_ID
    userId = ""
  }

  enableDebugPrint = true

  /**
   * Holds data received from 'on_order_result_received' callback.
   * This is a forced workaround for order objective not holding
   * winner's latest score when order finishes.
   */
  winnerScoreDataByOrderId = {}

  orderStatusPosition = null
  orderStatusSize = null

  ordersEnabled = false

  debugPlayers = []
  // debugPlayers = [
  //   {
  //     scoreData = {
  //       playerId = -1
  //       score = 1024
  //       playerData = {
  //         userId = "test_player_id_1"
  //         name = "test_player_1"
  //         team = 1
  //       }
  //     }
  //   }, {
  //     scoreData = {
  //       playerId = -1
  //       score = 512
  //       playerData = {
  //         userId = "test_player_id_2"
  //         name = "test_player_2"
  //         team = 2
  //       }
  //     }
  //   }, {
  //     scoreData = {
  //       playerId = -1
  //       score = 256
  //       playerData = {
  //         userId = "test_player_id_3"
  //         name = "test_player_3"
  //         team = 2
  //       }
  //     }
  //   }
  // ]

  localPlayerData = null
  isOrdersContainerVisible = false
  isOrdersHidden = false
  ordersToActivate = null
  isActivationProgress = false
}

//
// Public methods
//

::g_orders.openOrdersInventory <- function openOrdersInventory() {
  if (!::g_orders.orderCanBeActivated())
    return showInfoMsgBox(::g_orders.getWarningText(), "orders_cant_be_activated")

  ::gui_start_order_activation_window()
}

// This takes in account fact that item was used during current battle.
// @see ::items_classes.Order::getAmount()
::g_orders.collectOrdersToActivate <- @() this.ordersToActivate = ::ItemsManager.getInventoryList(
  itemType.ORDER, @(item) item.getAmount() > 0).sort(@(a, b) a.expiredTimeSec <=> b.expiredTimeSec)

::g_orders.hasOrdersToActivate <- @() (this.ordersToActivate?.len() ?? 0) > 0

::g_orders.getActivateButtonLabel <- function getActivateButtonLabel() {
  local label = loc("flightmenu/btnActivateOrder")
  if (this.cooldownTimeleft > 0) {
    let timeText = time.secondsToString(::g_orders.cooldownTimeleft)
    label += format(" (%s)", timeText)
  }
  return label
}

/**
 * Warning text with explanation why player can't activate item.
 * Returns empty string if player can activate item.
 */
::g_orders.getWarningText <- function getWarningText(selectedOrderItem = null) {
  if (this.hasActiveOrder)
    return loc("items/order/activateOrderWarning/hasActiveOrder")
  if (!::g_orders.hasOrdersToActivate())
    return loc("items/order/noOrdersAvailable")
  let timeleft = this.getCooldownTimeleft()
  if (timeleft > 0) {
    let locParams = { cooldownTimeleftText = time.secondsToString(timeleft) }
    return loc("items/order/activateOrderWarning/cooldown", locParams)
  }
  if (!this.checkCurrentMission(selectedOrderItem))
    return ::g_order_use_result.RESTRICTED_MISSION.createResultMessage(false)
  return ""
}

::g_orders.checkCurrentMission <- function checkCurrentMission(selectedOrderItem) {
  if (selectedOrderItem == null)
    return true

  let missionName = ::SessionLobby.getSessionInfo()?.mission.name
  if (missionName == null)
    return true

  if (selectedOrderItem.iType == itemType.ORDER)
    return selectedOrderItem.checkMission(missionName)
  return true
}

::g_orders.enableOrders <- function enableOrders(statusObj) {
  if (!this.ordersCanBeUsed() || u.isEqual(statusObj, this.ordersStatusObj))
    return

  this.ordersEnabled = true

  this.ordersStatusObj = statusObj

  this.updateActiveOrder(false)
  this.updateOrderStatus(true)

  if (this.listenersEnabled || !checkObj(statusObj))
    return
  this.listenersEnabled = true

  add_event_listener("LobbyStatusChange", this.onEventLobbyStatusChange, this)
  add_event_listener("ActiveOrderChanged", this.onEventActiveOrderChanged, this)
  add_event_listener("OrderUpdated", this.onEventOrderUpdated, this)
  add_event_listener("WatchedHeroSwitched", this.onEventWatchedHeroSwitched, this)
  add_event_listener("ChangedCursorVisibility", this.onEventChangedCursorVisibility, this)
}


::g_orders.enableOrdersWithoutDagui <- function enableOrdersWithoutDagui() {
  if (!this.ordersCanBeUsed())
    return

  this.ordersEnabled = true

  if (this.listenersEnabled)
    return
  this.listenersEnabled = true

  add_event_listener("LobbyStatusChange", this.onEventLobbyStatusChange, this)
  add_event_listener("ActiveOrderChanged", this.onEventActiveOrderChanged, this)
  add_event_listener("OrderUpdated", this.onEventOrderUpdated, this)
  add_event_listener("WatchedHeroSwitched", this.onEventWatchedHeroSwitched, this)
  add_event_listener("ChangedCursorVisibility", this.onEventChangedCursorVisibility, this)
}


::g_orders.disableOrders <- function disableOrders() {
  if (!this.ordersEnabled) {
    this.debugPrint("g_orders::disableOrders:Skipped. Already disabled.")
    debug_dump_stack()
    return
  }
  this.ordersEnabled = false
  subscriptions.removeAllListenersByEnv(this)
  this.ordersStatusObj = null
  this.listenersEnabled = false
  this.updateActiveOrder()
  this.timesUsedByOrderItemId.clear()
  this.playerDataById.clear()
  this.activeLocalOrderIds.clear()
  this.winnerScoreDataByOrderId.clear()
  this.activatingLocalOrderId = null
  this.activatingLocalOrderCallback = null
  ::set_order_accepted_cb(::g_orders, null)
  this.orderStatusPosition = null
  this.orderStatusSize = null
  this.localPlayerData = null
}

::g_orders.updateOrderStatus <- function updateOrderStatus(fullUpdate) {
  this.saveOrderStatusPositionAndSize()
  this.updateOrderStatusObject(this.ordersStatusObj, fullUpdate)
}

::g_orders.updateActiveOrder <- function updateActiveOrder(dispatchEvents = true, isForced = false) {
  local activeOrderChanged = false
  local orderStatusChanged = false

  // See what's changed.
  let orderObjective = this.getActiveOrderObjective()

  // This means that there's active order but it
  // is not fully loaded yet. Better bail out and
  // update on next updateActiveOrder() call.
  let starterId = getTblValue("starterId", orderObjective, -1)
  if (starterId == -1 && orderObjective != null && !isForced)
    return

  if (this.activeOrder.orderId != this.getOrderId(orderObjective))
    activeOrderChanged = true
  else if (this.activeOrder.orderStatus != this.getOrderStatus(orderObjective))
    orderStatusChanged = true

  // Update active order model.
  let oldActiveOrder = clone this.activeOrder
  this.activeOrder.orderId = this.getOrderId(orderObjective)
  this.activeOrder.orderObjective = orderObjective
  this.activeOrder.orderType = this.getOrderType(orderObjective)
  this.activeOrder.orderStatus = this.getOrderStatus(orderObjective)
  this.activeOrder.orderItem = this.getOrderItem(orderObjective)
  this.activeOrder.timeToSwitchTarget = getTblValue("timeToSwitchTarget", orderObjective, -1)

  let objectiveStarterId = getTblValue("starterId", orderObjective, -1)
  let orderStartId = getTblValue("id", this.activeOrder.starterPlayer, -1)
  // Updating starterPlayer table only if it's really required as it's expensive.
  if (orderStartId != objectiveStarterId || this.activeOrder.starterPlayer == null)
    this.activeOrder.starterPlayer = this.getPlayerDataById(objectiveStarterId)

  let objectiveTargetId = getTblValue("targetId", orderObjective, -1)
  let orderTargetId = getTblValue("id", this.activeOrder.targetPlayer, -1)
  // Same idea as started player.
  if (orderTargetId != objectiveTargetId || this.activeOrder.targetPlayer == null)
    this.activeOrder.targetPlayer = this.getPlayerDataById(objectiveTargetId)

  this.hasActiveOrder = orderObjective != null

  // Handle this player's active orders.
  this.updateActiveLocalOrders()

  // Update previous active order.
  if (this.activeOrder.orderObjective == null
    && oldActiveOrder.orderStatus == ::g_objective_status.RUNNING
    && this.activeOrder.orderStatus != ::g_objective_status.RUNNING
    && oldActiveOrder.orderId != -1) {
    this.prevActiveOrder = oldActiveOrder
  }
  else if (activeOrderChanged
    && this.activeOrder.orderStatus == ::g_objective_status.RUNNING) {
   this.prevActiveOrder = null
  }

  // Cooldown starts after order becomes
  // active and goes down to zero.
  if (!this.hasActiveOrder)
    this.updateCooldownTimeleft()

  this.updateHideOrderBlock()

  // Preparing handyman-view both for current active
  // order and previous order when it's on cooldown.
  if ((activeOrderChanged || orderStatusChanged) && this.hasActiveOrder)
    this.updateStatusTextView(this.activeOrder, true)
  if (this.cooldownTimeleft > 0 && this.prevActiveOrder != null)
    this.updateStatusTextView(this.prevActiveOrder, true)

  if (dispatchEvents) {
    if (activeOrderChanged)
      broadcastEvent("ActiveOrderChanged", { oldActiveOrder = oldActiveOrder })
    else if (orderStatusChanged)
      broadcastEvent("OrderStatusChanged", { oldActiveOrder = oldActiveOrder })
    broadcastEvent("OrderUpdated", { oldActiveOrder = oldActiveOrder })
  }

  local visibleScoreTableTexts = this.getScoreTableTexts()
  visibleScoreTableTexts = visibleScoreTableTexts.len() > this.maxRowsInScoreTable
    ? visibleScoreTableTexts.resize(this.maxRowsInScoreTable, null)
    : visibleScoreTableTexts
  send("orderStateUpdate", {
    statusText = this.getStatusText()
    statusTextBottom = this.getStatusTextBottom()
    showOrder = this.hasActiveOrder || (this.cooldownTimeleft > 0 && this.prevActiveOrder != null)
    scoresTable = visibleScoreTableTexts
  })
}

::g_orders.updateOrderVisibility <- function updateOrderVisibility() {
  if (!checkObj(this.ordersStatusObj))
    return

  let ordersBlockObj = this.ordersStatusObj.findObject("orders_block")
  if (checkObj(ordersBlockObj))
    ordersBlockObj.show(!this.isOrdersHidden)
}

::g_orders.updateHideOrderBlock <- function updateHideOrderBlock() {
  if (!checkObj(this.ordersStatusObj))
    return

  let isHideOrderBtnVisible = this.isOrderInfoVisible() && ::is_cursor_visible_in_gui()

  let hideOrderBlockObj = this.ordersStatusObj.findObject("hide_order_block")
  if (!checkObj(hideOrderBlockObj))
    return

  hideOrderBlockObj.collapsed = this.isOrdersHidden ? "yes" : "no"

  let hideOrderBtnObj = hideOrderBlockObj.findObject("hide_order_btn")
  if (checkObj(hideOrderBtnObj))
    hideOrderBtnObj.isHidden = isHideOrderBtnVisible ? "no" : "yes"

  let hideOrderTextIconObj = hideOrderBlockObj.findObject("hide_order_text")
  if (checkObj(hideOrderTextIconObj))
    hideOrderTextIconObj.show(isHideOrderBtnVisible && this.isOrdersHidden)
}

// Activates order, which soon expire.
::g_orders.activateSoonExpiredOrder <- function activateSoonExpiredOrder() {
  if (!hasFeature("OrderAutoActivate") || this.isActivationProgress)
    return

  // If some orders expired during other one active
  this.ordersToActivate = this.ordersToActivate.filter(@(inst) !inst.isExpired())

  for (local i = 0; i < this.ordersToActivate.len(); i++) {
    let order = this.ordersToActivate[i]
    if (order.isActivateBeforeExpired && order.hasExpireTimer()
      && order.expiredTimeSec - get_time_msec() * 0.001 <= AUTO_ACTIVATE_TIME) {
        this.activateOrder(order,
          function(p) {
            if (p.useResult == ::g_order_use_result.OK)
              this.ordersToActivate.remove(i)
            }, true)
          break
    }
  }
}

/** Returns true if player can activate some order now. */
::g_orders.orderCanBeActivated <- function orderCanBeActivated() {
  if (!this.ordersCanBeUsed() || !this.hasOrdersToActivate())
    return false
  this.updateActiveOrder()
  return !this.hasActiveOrder
}

/** Returns true if orders can be used as a feature. */
::g_orders.ordersCanBeUsed <- function ordersCanBeUsed() {
  let checkGameType = (get_game_type() & GT_USE_ORDERS) != 0
  return checkGameType && ::is_in_flight() && hasFeature("Orders")
}

::g_orders.getActivateInfoText <- function getActivateInfoText() {
  if (!::is_in_flight())
    return loc("order/usableOnlyInBattle")
  if ((get_game_type() & GT_USE_ORDERS) == 0)
    return loc("order/notUsableInCurrentBattle")
  if (this.hasActiveOrder)
    return loc("order/onlyOneOrderCanBeActive")
  return ""
}

::g_orders.isInSpectatorMode <- function isInSpectatorMode() {
  return ::isPlayerDedicatedSpectator() || is_replay_playing()
}

::g_orders.showActivateOrderButton <- function showActivateOrderButton() {
  return !this.isInSpectatorMode() && this.ordersCanBeUsed()
}

::g_orders.activateOrder <- function activateOrder(orderItem, onComplete = null, isSilent = false) {
  this.isActivationProgress = true
  if (this.activatingLocalOrderId != null) {
    if (onComplete != null) {
      onComplete({
        success = false
        orderId = orderItem.id
      })
    }
    this.debugPrint("g_orders::activateOrder: Activation didn't start. "
      + "Already activating order with ID: " + this.activatingLocalOrderId)
    return
  }
  this.activatingLocalOrderId = orderItem.id
  this.activatingLocalOrderCallback = onComplete
  this.debugPrint("g_orders::activateOrder: Activation started. "
    + "Order ID: " + this.activatingLocalOrderId + " Order UID: " + orderItem.uids[0])
  if (this.checkCurrentMission(orderItem)) {
    ::set_order_accepted_cb(::g_orders, @(res) this.onOrderAccepted(res, isSilent))
    ::use_order_request(orderItem.uids[0])
  }
  else
    this.onOrderAccepted(::g_order_use_result.RESTRICTED_MISSION.code, isSilent)
}

/**
 * Returns amount of times item was used by this player during
 * current session. This data is reset when battle ends.
 */
::g_orders.getTimesUsedOrderItem <- function getTimesUsedOrderItem(orderItem) {
  return getTblValue(orderItem.id, this.timesUsedByOrderItemId, 0)
}

/**
 * Manually managing activated order items as there's no way
 * to retrieve this kind of info from server.
 */
::g_orders.isOrderItemActive <- function isOrderItemActive(orderItem) {
  return isInArray(orderItem.id, this.activeLocalOrderIds)
}

/**
 * @param fullUpdate Setting to 'true' forces
 * to rebuild whole status object content.
 * Used to avoid multiple 'replaceContent' calls.
 */
::g_orders.updateOrderStatusObject <- function updateOrderStatusObject(statusObj, fullUpdate) {
  if (!checkObj(statusObj))
    return

  let orderObject = this.hasActiveOrder
    ? this.activeOrder
    : this.prevActiveOrder

  if (fullUpdate) {
    let statusContent = this.getStatusContent(orderObject, (statusObj?.isHalignRight ?? "no") == "yes")
    let guiScene = statusObj.getScene()
    guiScene.replaceContentFromText(statusObj, statusContent, statusContent.len(), this)

    // (Re)enable timer.
    let orderTimerObj = statusObj.findObject("order_timer")
    if (checkObj(orderTimerObj))
      orderTimerObj.setUserData(this)
  }

  let waitingForCooldown = this.cooldownTimeleft > 0 && this.prevActiveOrder != null

  let showStatus = this.hasActiveOrder || waitingForCooldown
  this.setStatusObjVisibility(statusObj, showStatus)
  if (!showStatus)
    return

  // Updating order status text.
  let statusTextObj = statusObj.findObject("status_text")
  if (checkObj(statusTextObj))
    statusTextObj.setValue(this.getStatusText())

  // Updating order bottom status text.
  let statusTextBottomObj = statusObj.findObject("status_text_bottom")
  if (checkObj(statusTextBottomObj))
    statusTextBottomObj.setValue(this.getStatusTextBottom())

  // Updating order score table.
  let tableTexts = this.getScoreTableTexts()
  let showTable = tableTexts != null && tableTexts.len()
  let statusTableObj = statusObj.findObject("status_table")
  let numScores = min(tableTexts ? tableTexts.len() : 0, this.maxRowsInScoreTable)
  if (checkObj(statusTableObj))
    statusTableObj.show(showTable)
  if (showTable) {
    for (local i = 0; i < numScores; ++i) {
      let rowObj = this.getRowObjByIndex(i, statusObj)
      assert(rowObj != null, "Error updating order status: Row object not found.")
      this.setRowObjTexts(rowObj, tableTexts[i].player, tableTexts[i].score, true)
    }
  }

  // Hiding rows without data.
  for (local i = numScores; i < this.maxRowsInScoreTable; ++i) {
    let rowObj = this.getRowObjByIndex(i, statusObj)
    assert(rowObj != null, "Error updating order status: Row object not found.")
    this.setRowObjTexts(rowObj, "", "", false)
  }
}

::g_orders.setStatusObjVisibility <- function setStatusObjVisibility(statusObj, visible) {
  if (!checkObj(statusObj))
    return

  let ordersBlockObj = statusObj.findObject("orders_block")
  if (checkObj(ordersBlockObj))
    ordersBlockObj.show(visible && !this.isOrdersHidden)
}

::g_orders.getRowObjByIndex <- function getRowObjByIndex(rowIndex, statusObj) {
  let rowObj = statusObj.findObject("order_score_row_" + rowIndex)
  return checkObj(rowObj) ? rowObj : null
}

::g_orders.setRowObjTexts <- function setRowObjTexts(rowObj, nameText, scoreText, pilotIconVisible) {
  if (!checkObj(rowObj))
    return
  let playerNameTextObj = rowObj.findObject("order_score_player_name_text")
  if (checkObj(playerNameTextObj))
    playerNameTextObj.setValue(nameText)
  let playerScoreTextObj = rowObj.findObject("order_score_value_text")
  if (checkObj(playerScoreTextObj))
    playerScoreTextObj.setValue(scoreText)
  let pilotIconObj = rowObj.findObject("order_score_pilot_icon")
  if (checkObj(pilotIconObj))
    pilotIconObj.show(pilotIconVisible)
}


::g_orders.getScoreTableTexts <- function getScoreTableTexts() {
  let showOrder = this.isOrderInfoVisible()
  if (!showOrder)
    return []
  let orderObject = this.hasActiveOrder ? this.activeOrder : this.prevActiveOrder
  let scoreData = this.getOrderScores(orderObject)
  if (!scoreData)
    return []
  this.prepareStatusScores(scoreData, orderObject)
  return scoreData.map(function (item) {
    let playerData = ::g_orders.getPlayerDataByScoreData(item)
    return {
      score = orderObject.orderType.formatScore(item.score)
      player = (getTblValue("playerIndex", item, 0) + 1).tostring() + ". " + ::build_mplayer_name(playerData)
    }
  })
}


::g_orders.isOrderInfoVisible <- function isOrderInfoVisible() {
  return this.hasActiveOrder || (this.cooldownTimeleft > 0 && this.prevActiveOrder != null)
}


::g_orders.getStatusText <- function getStatusText() {
  let orderObject = this.hasActiveOrder ? this.activeOrder : this.prevActiveOrder
  if (orderObject == null)
    return ""
  this.updateStatusTextView(orderObject, false)
  let view = orderObject.statusTextView
  local result = ""
  if (!this.hasActiveOrder) {
    result += colorize(this.statusColorScheme.parameterLabelColor, view.orderFinishedLabel)
    result += colorize(this.statusColorScheme.parameterValueColor, view.orderName)
    return result
  }
  result += colorize(this.statusColorScheme.parameterLabelColor, view.orderActiveLabel) + " "
  result += colorize(this.statusColorScheme.parameterValueColor, view.orderName) + "\n"
  result += view.orderDescription + "\n"
  if (orderObject.starterPlayer != null && this.checkOrderActivationTime(5)) {
    result += colorize(this.statusColorScheme.parameterLabelColor, view.orderStarterLabel)
    result += colorize(this.statusColorScheme.parameterValueColor, view.orderStarter) + "\n"
  }
  if (orderObject.targetPlayer != this.emptyPlayerData) {
    result += colorize(this.statusColorScheme.parameterLabelColor, view.orderTargetLabel)
    result += colorize(this.statusColorScheme.parameterValueColor, view.orderTarget) + "\n"
    if (orderObject.timeToSwitchTarget != -1) {
      result += colorize(this.statusColorScheme.parameterLabelColor, view.timeToSwitchTargetLabel)
      result += colorize(this.statusColorScheme.parameterValueColor, view.timeToSwitchTarget) + "\n"
    }
  }
  result += colorize(this.statusColorScheme.parameterLabelColor, view.orderTimeleftLabel) + " "
  result += colorize(this.statusColorScheme.parameterValueColor, view.orderTimeleft)
  return result
}

/**
 * Returns true if order was activated less
 * than specified amount of time ago.
 */
::g_orders.checkOrderActivationTime <- function checkOrderActivationTime(timeSeconds) {
  if (this.activeOrder.orderItem == null)
    return false
  return this.getOrderTimeleft(this.activeOrder) >= this.activeOrder.orderItem.timeTotal - timeSeconds
}

::g_orders.getStatusTextBottom <- function getStatusTextBottom() {
  if (this.hasActiveOrder || this.prevActiveOrder == null)
    return ""
  let view = this.prevActiveOrder.statusTextView
  local result = ""
  result += colorize(this.statusColorScheme.parameterLabelColor, view.cooldownTimeleftLabel)
  result += colorize(this.statusColorScheme.parameterValueColor, view.cooldownTimeleft)
  return result
}

::g_orders.showOrdersContainer <- function showOrdersContainer(isShown) {
  this.isOrdersContainerVisible = isShown
}

::g_orders.getStatusContent <- function getStatusContent(orderObject, isHalignRight = false) {
  let orderType = orderObject == null ? ::g_order_type.UNKNOWN : orderObject.orderType
  let view = {
    rows = []
    playersHeaderText = loc("items/order/scoreTable/playersHeader")
    scoreHeaderText = orderType.getScoreHeaderText()
    needPlaceInHiddenContainer = this.isInSpectatorMode()
    isHiddenContainerVisible = this.isOrdersContainerVisible
    isHalignRight = isHalignRight
  }
  for (local i = 0; i < this.maxRowsInScoreTable; ++i)
    view.rows.append({ rowIndex = i })
  return handyman.renderCached("%gui/items/orderStatus.tpl", view)
}

/**
 * Implementation of this method will change after
 * switching to multiple active orders by same player.
 */
::g_orders.updateActiveLocalOrders <- function updateActiveLocalOrders() {
  let starterUid = getTblValue("userId", this.activeOrder.starterPlayer, null)
  let itemId = getTblValue("id", this.activeOrder.orderItem, null)
  for (local i = this.activeLocalOrderIds.len() - 1; i >= 0; --i) {
    let id = this.activeLocalOrderIds[i]

    // How? We don't know yet.
    // Added assertions for further investigation.
    if (id == null) {
      debugTableData(::g_orders)
      assert(false,
        "Active order ids array contains null. Report this issue immediately.")
      this.activeLocalOrderIds.remove(i)
      continue
    }

    if (id != itemId || starterUid != ::my_user_id_str) {
      this.activeLocalOrderIds.remove(i)
      this.timesUsedByOrderItemId[id] <- getTblValue(id, this.timesUsedByOrderItemId, 0) + 1
    }
  }
}

::g_orders.getActiveOrderObjective <- function getActiveOrderObjective() {
  let objectives = ::get_objectives_list()
  foreach (objective in objectives) {
    if (getTblValue("status", objective, 0) == 0)
      continue

    let objectiveType = getTblValue("type", objective, -1)
    if (objectiveType == OBJECTIVE_TYPE_ORDER)
      return objective
  }
  return null
}

::g_orders.onOrderAccepted <- function onOrderAccepted(useResultCode, isSilent = false) {
  let useResult = ::g_order_use_result.getOrderUseResultByCode(useResultCode)
  this.debugPrint("g_orders::onOrderAccepted: Activation complete. Result: "
    + toString(useResult))
  if (!isSilent)
    scene_msg_box("order_use_result", null, useResult.createResultMessage(true),
      [["ok", function() {
        broadcastEvent("OrderUseResultMsgBoxClosed")
      } ]], "ok")
  if (useResult == ::g_order_use_result.OK) {
    if (this.activatingLocalOrderId == null) {
      debugTableData(::g_orders)
      assert(false,
        "Activating local order is null. Report this issue immediately.")
    }
    this.activeLocalOrderIds.append(this.activatingLocalOrderId)
    broadcastEvent("OrderActivated")
  }
  if (this.activatingLocalOrderCallback != null) {
    this.activatingLocalOrderCallback({
      success = true
      useResult = useResult
      orderId = this.activatingLocalOrderId
    })
    this.activatingLocalOrderCallback = null
  }
  this.activatingLocalOrderId = null
  ::set_order_accepted_cb(::g_orders, null)
  this.isActivationProgress = false
}

/** This is order counter local in scope of one battle. */
::g_orders.getOrderId <- function getOrderId(orderObjective) {
  return getTblValue("id", orderObjective, -1)
}

/**
 * Order status is: running, failed, succeed.
 * @see ::g_objective_status
 */
::g_orders.getOrderStatus <- function getOrderStatus(orderObjective) {
  let statusCode = getTblValue("status", orderObjective, -1)
  return ::g_objective_status.getObjectiveStatusByCode(statusCode)
}

::g_orders.getOrderType <- function getOrderType(orderObjective) {
  let orderItem = this.getOrderItem(orderObjective)
  if (orderItem == null)
    return ::g_order_type.UNKNOWN
  return orderItem.orderType
}

::g_orders.getOrderItem <- function getOrderItem(orderObjective) {
  let objectiveId = getTblValue("objectiveId", orderObjective, null)
  return ::ItemsManager.findItemById(objectiveId, itemType.ORDER)
}

/** Called only when no active order. */
::g_orders.updateCooldownTimeleft <- function updateCooldownTimeleft() {
  this.cooldownTimeleft = max(this.getCooldownTimeleft(), 0)
}

::g_orders.getCooldownTimeleft <- function getCooldownTimeleft() {
  // Returns 1 or 2 as team indices.
  let playerTeam = ::get_mp_local_team()
  if (playerTeam == Team.Any)
    return -1
  let tblTeams = get_mp_tbl_teams()
  let localTeamTbl = getTblValue(playerTeam - 1, tblTeams)
  return getTblValue("orderCooldownLeft", localTeamTbl, 0)
}

/**
 * @param orderObject 'activeOrder' or 'prevActiveOrder'
 * @param fullUpdate Setting to 'true' will update parameters
 * that are not changing for same order.
 */
::g_orders.updateStatusTextView <- function updateStatusTextView(orderObject, fullUpdate) {
  // Possible when another player activates an order.
  if (orderObject == null)
    return

  let view = orderObject.statusTextView

  if (fullUpdate) {
    // Order name
    view.orderActiveLabel <- loc("icon/orderSymbol")
    view.orderName <- orderObject.orderItem.getStatusOrderName()

    view.orderTimeleftLabel <- loc("icon/timer")

    // Order starter
    view.orderStarterLabel <- loc("items/order/status/starter") + loc("ui/colon")
    view.orderStarter <- ::build_mplayer_name(orderObject.starterPlayer)

    // Order target
    view.orderTargetLabel <- loc("items/order/status/target") + loc("ui/colon")

    view.cooldownTimeleftLabel <- loc("items/order/status/cooldown") + loc("ui/colon")
    view.orderFinishedLabel <- loc("items/order/status/finished") + loc("ui/colon")
    view.timeToSwitchTargetLabel <- loc("items/order/status/timeToSwitchTarget") + loc("ui/colon")
  }

  // Order description
  let orderTypeParams = orderObject?.orderItem.typeParams
  view.orderDescription <- orderTypeParams != null
    ? orderObject.orderType.getObjectiveDescription(orderTypeParams, this.statusColorScheme)
    : null

  view.orderTimeleft <- time.secondsToString(this.getOrderTimeleft(orderObject))
  view.cooldownTimeleft <- time.secondsToString(this.cooldownTimeleft)
  if (orderObject.targetPlayer != this.emptyPlayerData)
    view.orderTarget <- ::build_mplayer_name(orderObject.targetPlayer)
  if (orderObject.timeToSwitchTarget != -1)
    view.timeToSwitchTarget <- time.secondsToString(orderObject.timeToSwitchTarget)
}

::g_orders.getOrderTimeleft <- function getOrderTimeleft(orderObject) {
  return orderObject?.orderObjective.timeLeft ?? 0
}

/** Returns null-object player data if nothing found. */
::g_orders.getPlayerDataById <- function getPlayerDataById(playerId) {
  if (!this.ordersEnabled) {
    this.debugPrint("g_orders::getPlayerDataById: Calling when orders are disabled.")
    debug_dump_stack()
  }
  let playerData = this.playerDataById?[playerId] ?? get_mplayer_by_id(playerId) ?? this.emptyPlayerData
  if (is_replay_playing()) {
    playerData.isLocal = spectatorWatchedHero.id == playerData.id
    playerData.isInHeroSquad = ::SessionLobby.isEqualSquadId(spectatorWatchedHero.squadId, playerData?.squadId)
  }
  if (!(playerId in this.playerDataById))
    this.playerDataById[playerId] <- playerData
  return playerData
}

::g_orders.getPlayerDataByScoreData <- function getPlayerDataByScoreData(scoreData) {
  if (scoreData.playerId != -1)
    return this.getPlayerDataById(scoreData.playerId)
  return getTblValue("playerData", scoreData, this.emptyPlayerData)
}


//
// Handlers
//
::g_orders.onChangeOrderVisibility <- function onChangeOrderVisibility(_obj, _dt) {
  this.isOrdersHidden = !this.isOrdersHidden
  this.updateHideOrderBlock()
  this.updateOrderVisibility()
}

::g_orders.onOrderTimerUpdate <- function onOrderTimerUpdate(_obj, _dt) {
  ::g_orders.updateActiveOrder()
}

::g_orders.onEventLobbyStatusChange <- function onEventLobbyStatusChange(_params) {
  if (!::SessionLobby.isInRoom())
    this.disableOrders()
}

::g_orders.onEventActiveOrderChanged <- function onEventActiveOrderChanged(params) {
  this.collectOrdersToActivate()
  this.updateOrderStatus(true)
  local text
  if (::g_orders.hasActiveOrder) {
    text = loc("items/order/hudMessage/activate", {
      playerName = ::build_mplayer_name(::g_orders.activeOrder.starterPlayer)
      orderName = ::g_orders.activeOrder.orderItem.getName(false)
    })
    this.isOrdersHidden = false
  }
  else {
    text = loc("items/order/hudMessage/finished", {
      orderName = params.oldActiveOrder.orderItem.getName(false)
    })
  }
  ::g_hud_event_manager.onHudEvent("HudMessage", {
    id = -1
    type = HUD_MSG_OBJECTIVE
    text = text
  })
}

::g_orders.onEventOrderUpdated <- function onEventOrderUpdated(_params) {
  this.updateOrderStatus(false)
  this.updateHideOrderBlock()
}

::g_orders.onEventWatchedHeroSwitched <- function onEventWatchedHeroSwitched(_params) {
  this.updateActiveOrder(true, true)
}

::g_orders.onEventChangedCursorVisibility <- function onEventChangedCursorVisibility(_params) {
  this.updateHideOrderBlock()
}

::g_orders.debugPrint <- function debugPrint(message) {
  if (this.enableDebugPrint)
    log("g_orders::debugPrint:\n" + message)
}

/**
 * Returns valid order scores, taking in account fact that when order
 * finishes it's objective-object does not hold valid score for winner.
 */
::g_orders.getOrderScores <- function getOrderScores(orderObject) {
  local scores = orderObject?.orderObjective.score
  if (scores != null) {
    scores = clone scores
    foreach (player in this.debugPlayers)
      scores.append(player.scoreData)
    this.addLocalPlayerScoreData(scores)
  }

  let winnerScoreData = getTblValue(orderObject.orderId, this.winnerScoreDataByOrderId, null)
  if (scores == null || winnerScoreData == null)
    return scores

  for (local i = 0; i < scores.len(); ++i) {
    let scoreData = scores[i]
    if (scoreData.playerId == winnerScoreData.playerId) {
      scores[i] = clone winnerScoreData
      scores[i].playerIndex <- i
      break
    }
  }
  return scores
}

::g_orders.prepareStatusScores <- function prepareStatusScores(statusScores, orderObject) {
  statusScores.sort(orderObject.orderType.sortPlayerScores)

  // Remove score data with not player data.
  for (local i = statusScores.len() - 1; i >= 0; --i) {
    let playerData = this.getPlayerDataByScoreData(statusScores[i])
    if (playerData == null)
      statusScores.remove(i)
  }

  // Update players indexes
  local localPlayerIndex = -1
  foreach (idx, score in statusScores) {
    score.playerIndex <- idx
    if (localPlayerIndex >= 0)
      continue

    let playerData = this.getPlayerDataByScoreData(score)
    if (getTblValue("userId", playerData) == ::my_user_id_str)
      localPlayerIndex = idx
  }

  if (localPlayerIndex == -1)
    return

  // Removing players preceding local player so that it
  // will be within first 'maxRowsInScoreTable' players.
  while (localPlayerIndex >= this.maxRowsInScoreTable) {
    statusScores.remove(this.maxRowsInScoreTable - 1)
    --localPlayerIndex
  }
}

/**
 * Adds local player data and score
 * dummy to specified scores array.
 */
::g_orders.addLocalPlayerScoreData <- function addLocalPlayerScoreData(scores) {
  let checkFunc = is_replay_playing() ?
    function(p) { return p.id == spectatorWatchedHero.id } :
    function(p) { return p.userId == ::my_user_id_str }

  local foundThisPlayer = false
  foreach (scoreData in scores)
    if (checkFunc(this.getPlayerDataByScoreData(scoreData))) {
      foundThisPlayer = true
      break
    }
  if (foundThisPlayer)
    return
  scores.append({
    playerId = -1
    score = 0
    playerData = this.getLocalPlayerData()
  })
}

::g_orders.saveOrderStatusPositionAndSize <- function saveOrderStatusPositionAndSize() {
  if (!checkObj(this.ordersStatusObj))
    return

  let frameObj = this.ordersStatusObj.findObject("order_status_frame")
  if (!checkObj(frameObj)) // Possible if not in spectator mode.
    return

  let frameSize = frameObj.getSize()

  // Frame object has invalid size. This means it
  // was not rendered yet. Bail out then.
  if (frameSize[0] == -1)
    return

  this.orderStatusSize = frameSize

  this.orderStatusPosition = frameObj.getPosRC()
  let statusObjPosition = this.ordersStatusObj.getPosRC()

  // Saving frame object position relative to parent.
  this.orderStatusPosition[0] -= statusObjPosition[0]
  this.orderStatusPosition[1] -= statusObjPosition[1]
}

::g_orders.getLocalPlayerData <- function getLocalPlayerData() {
  if (is_replay_playing())
    this.localPlayerData = this.getPlayerDataById(spectatorWatchedHero.id)

  if (this.localPlayerData == null)
    this.localPlayerData = get_local_mplayer()
  return this.localPlayerData
}


::cross_call_api.active_order_request_update <- @()::g_orders.updateActiveOrder()
::cross_call_api.active_order_enable <- @()::g_orders.enableOrdersWithoutDagui()

registerPersistentDataFromRoot("g_orders")
