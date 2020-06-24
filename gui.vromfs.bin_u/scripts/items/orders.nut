local time = require("scripts/time.nut")
local subscriptions = require("sqStdlibs/helpers/subscriptions.nut")
local spectatorWatchedHero = require("scripts/replays/spectatorWatchedHero.nut")


/**
 * This method is called from within C++.
 * Triggered only when some player gets a reward.
 */
::on_order_result_received <- function on_order_result_received(player, orderId, param, wp, exp)
{
  // Parameter 'orderId' comes as a string (e.g. "::g_orders.activeOrder.orderId")
  // this is a misleading naming. But 'winnerScoreDataByOrderId' uses actual
  // orderId so here is an assumption that order in 'g_orders' is still active.
  local actualOrderId = ::g_orders.activeOrder.orderId
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
}

//
// Public methods
//

g_orders.openOrdersInventory <- function openOrdersInventory(checkOrdersToActivate)
{
  if (checkOrdersToActivate && !::g_orders.hasOrdersToActivate())
  {
    ::showInfoMsgBox(::loc("items/order/noOrdersAvailable"), "no_orders_available")
    return
  }
  ::gui_start_order_activation_window()
}

g_orders.hasOrdersToActivate <- function hasOrdersToActivate()
{
  local list = ::ItemsManager.getInventoryList(itemType.ORDER, function (item) {
    // This takes in account fact that item was used during current battle.
    // @see ::items_classes.Order::getAmount()
    return item.getAmount() > 0
  })
  return list.len() > 0
}

g_orders.getActivateButtonLabel <- function getActivateButtonLabel()
{
  local label = ::loc("flightmenu/btnActivateOrder")
  if (cooldownTimeleft > 0)
  {
    local timeText = time.secondsToString(::g_orders.cooldownTimeleft)
    label += ::format(" (%s)", timeText)
  }
  return label
}

/**
 * Warning text with explanation why player can't activate item.
 * Returns empty string if player can activate item.
 */
g_orders.getWarningText <- function getWarningText(selectedOrderItem = null)
{
  if (hasActiveOrder)
    return ::loc("items/order/activateOrderWarning/hasActiveOrder")
  local timeleft = getCooldownTimeleft()
  if (timeleft > 0)
  {
    local locParams = {cooldownTimeleftText = time.secondsToString(timeleft)}
    return ::loc("items/order/activateOrderWarning/cooldown", locParams)
  }
  if (!checkCurrentMission(selectedOrderItem))
    return ::g_order_use_result.RESTRICTED_MISSION.createResultMessage(false)
  return ""
}

g_orders.checkCurrentMission <- function checkCurrentMission(selectedOrderItem)
{
  if (selectedOrderItem == null)
    return true

  local missionName = ::SessionLobby.getSessionInfo()?.mission.name
  if (missionName == null)
    return true

  if (selectedOrderItem.iType == itemType.ORDER)
    return selectedOrderItem.checkMission(missionName)
  return true
}

g_orders.enableOrders <- function enableOrders(statusObj)
{
  if (!ordersCanBeUsed() || ::u.isEqual(statusObj, ordersStatusObj))
    return

  ordersEnabled = true

  ordersStatusObj = statusObj

  updateActiveOrder(false)
  updateOrderStatus(true)

  if (listenersEnabled || !::checkObj(statusObj))
    return
  listenersEnabled = true

  ::add_event_listener("LobbyStatusChange", onEventLobbyStatusChange, this)
  ::add_event_listener("ActiveOrderChanged", onEventActiveOrderChanged, this)
  ::add_event_listener("OrderUpdated", onEventOrderUpdated, this)
  ::add_event_listener("WatchedHeroSwitched", onEventWatchedHeroSwitched, this)
  ::add_event_listener("ChangedCursorVisibility", onEventChangedCursorVisibility, this)
}


g_orders.enableOrdersWithoutDagui <- function enableOrdersWithoutDagui()
{
  if (!ordersCanBeUsed())
    return

  ordersEnabled = true

  if (listenersEnabled)
    return
  listenersEnabled = true

  ::add_event_listener("LobbyStatusChange", onEventLobbyStatusChange, this)
  ::add_event_listener("ActiveOrderChanged", onEventActiveOrderChanged, this)
  ::add_event_listener("OrderUpdated", onEventOrderUpdated, this)
  ::add_event_listener("WatchedHeroSwitched", onEventWatchedHeroSwitched, this)
  ::add_event_listener("ChangedCursorVisibility", onEventChangedCursorVisibility, this)
}


g_orders.disableOrders <- function disableOrders()
{
  if (!ordersEnabled)
  {
    debugPrint("g_orders::disableOrders:Skipped. Already disabled.")
    ::callstack()
    return
  }
  ordersEnabled = false
  subscriptions.removeAllListenersByEnv(this)
  ordersStatusObj = null
  listenersEnabled = false
  updateActiveOrder()
  timesUsedByOrderItemId.clear()
  playerDataById.clear()
  activeLocalOrderIds.clear()
  winnerScoreDataByOrderId.clear()
  activatingLocalOrderId = null
  activatingLocalOrderCallback = null
  ::set_order_accepted_cb(::g_orders, null)
  orderStatusPosition = null
  orderStatusSize = null
  localPlayerData = null
}

g_orders.updateOrderStatus <- function updateOrderStatus(fullUpdate)
{
  saveOrderStatusPositionAndSize()
  updateOrderStatusObject(ordersStatusObj, fullUpdate)
}

g_orders.updateActiveOrder <- function updateActiveOrder(dispatchEvents = true, isForced = false)
{
  local activeOrderChanged = false
  local orderStatusChanged = false

  // See what's changed.
  local orderObjective = getActiveOrderObjective()

  // This means that there's active order but it
  // is not fully loaded yet. Better bail out and
  // update on next updateActiveOrder() call.
  local starterId = ::getTblValue("starterId", orderObjective, -1)
  if (starterId == -1 && orderObjective != null && !isForced)
    return

  if (activeOrder.orderId != getOrderId(orderObjective))
    activeOrderChanged = true
  else if (activeOrder.orderStatus != getOrderStatus(orderObjective))
    orderStatusChanged = true

  // Update active order model.
  local oldActiveOrder = clone activeOrder
  activeOrder.orderId = getOrderId(orderObjective)
  activeOrder.orderObjective = orderObjective
  activeOrder.orderType = getOrderType(orderObjective)
  activeOrder.orderStatus = getOrderStatus(orderObjective)
  activeOrder.orderItem = getOrderItem(orderObjective)
  activeOrder.timeToSwitchTarget = ::getTblValue("timeToSwitchTarget", orderObjective, -1)

  local objectiveStarterId = ::getTblValue("starterId", orderObjective, -1)
  local orderStartId = ::getTblValue("id", activeOrder.starterPlayer, -1)
  // Updating starterPlayer table only if it's really required as it's expensive.
  if (orderStartId != objectiveStarterId || activeOrder.starterPlayer == null)
    activeOrder.starterPlayer = getPlayerDataById(objectiveStarterId)

  local objectiveTargetId = ::getTblValue("targetId", orderObjective, -1)
  local orderTargetId = ::getTblValue("id", activeOrder.targetPlayer, -1)
  // Same idea as started player.
  if (orderTargetId != objectiveTargetId || activeOrder.targetPlayer == null)
    activeOrder.targetPlayer = getPlayerDataById(objectiveTargetId)

  hasActiveOrder = orderObjective != null

  // Handle this player's active orders.
  updateActiveLocalOrders()

  // Update previous active order.
  if (activeOrder.orderObjective == null
    && oldActiveOrder.orderStatus == ::g_objective_status.RUNNING
    && activeOrder.orderStatus != ::g_objective_status.RUNNING
    && oldActiveOrder.orderId != -1)
  {
    prevActiveOrder = oldActiveOrder
  }
  else if (activeOrderChanged
    && activeOrder.orderStatus == ::g_objective_status.RUNNING)
  {
   prevActiveOrder = null
  }

  // Cooldown starts after order becomes
  // active and goes down to zero.
  if (!hasActiveOrder)
    updateCooldownTimeleft()

  updateHideOrderBlock()

  // Preparing handyman-view both for current active
  // order and previous order when it's on cooldown.
  if ((activeOrderChanged || orderStatusChanged) && hasActiveOrder)
    updateStatusTextView(activeOrder, true)
  if (cooldownTimeleft > 0 && prevActiveOrder != null)
    updateStatusTextView(prevActiveOrder, true)

  if (dispatchEvents)
  {
    if (activeOrderChanged)
      ::broadcastEvent("ActiveOrderChanged", { oldActiveOrder = oldActiveOrder })
    else if (orderStatusChanged)
      ::broadcastEvent("OrderStatusChanged", { oldActiveOrder = oldActiveOrder })
    ::broadcastEvent("OrderUpdated", { oldActiveOrder = oldActiveOrder })
  }

  local visibleScoreTableTexts = getScoreTableTexts()
  visibleScoreTableTexts = visibleScoreTableTexts.len() > maxRowsInScoreTable
    ? visibleScoreTableTexts.resize(maxRowsInScoreTable, null)
    : visibleScoreTableTexts
  ::call_darg("orderStateUpdate", {
    statusText = getStatusText()
    statusTextBottom = getStatusTextBottom()
    showOrder = hasActiveOrder || (cooldownTimeleft > 0 && prevActiveOrder != null)
    scoresTable = visibleScoreTableTexts
  })
}

g_orders.updateOrderVisibility <- function updateOrderVisibility()
{
  if (!::checkObj(ordersStatusObj))
    return

  local ordersBlockObj = ordersStatusObj.findObject("orders_block")
  if (::check_obj(ordersBlockObj))
    ordersBlockObj.show(!isOrdersHidden)
}

g_orders.updateHideOrderBlock <- function updateHideOrderBlock()
{
  if (!::checkObj(ordersStatusObj))
    return

  local isHideOrderBtnVisible = isOrderInfoVisible() && ::is_cursor_visible_in_gui()

  local hideOrderBlockObj = ordersStatusObj.findObject("hide_order_block")
  if (!::check_obj(hideOrderBlockObj))
    return

  hideOrderBlockObj.collapsed = isOrdersHidden ? "yes" : "no"

  local hideOrderBtnObj = hideOrderBlockObj.findObject("hide_order_btn")
  if (::check_obj(hideOrderBtnObj))
    hideOrderBtnObj.isHidden = isHideOrderBtnVisible ? "no" : "yes"

  local hideOrderTextIconObj = hideOrderBlockObj.findObject("hide_order_text")
  if (::check_obj(hideOrderTextIconObj))
    hideOrderTextIconObj.show(isHideOrderBtnVisible && isOrdersHidden)
}


/** Returns true if player can activate some order now. */
g_orders.orderCanBeActivated <- function orderCanBeActivated()
{
  if (!ordersCanBeUsed() || !hasOrdersToActivate())
    return false
  updateActiveOrder()
  return !hasActiveOrder
}

/** Returns true if orders can be used as a feature. */
g_orders.ordersCanBeUsed <- function ordersCanBeUsed()
{
  local checkGameType = (::get_game_type() & ::GT_USE_ORDERS) != 0
  return checkGameType && ::is_in_flight() && ::has_feature("Orders")
}

g_orders.getActivateInfoText <- function getActivateInfoText()
{
  if (!::is_in_flight())
    return ::loc("order/usableOnlyInBattle")
  if ((::get_game_type() & ::GT_USE_ORDERS) == 0)
    return ::loc("order/notUsableInCurrentBattle")
  if (hasActiveOrder)
    return ::loc("order/onlyOneOrderCanBeActive")
  return ""
}

g_orders.isInSpectatorMode <- function isInSpectatorMode()
{
  return ::isPlayerDedicatedSpectator() || ::is_replay_playing()
}

g_orders.showActivateOrderButton <- function showActivateOrderButton()
{
  return !isInSpectatorMode() && ordersCanBeUsed()
}

g_orders.activateOrder <- function activateOrder(orderItem, onComplete = null)
{
  if (activatingLocalOrderId != null)
  {
    if (onComplete != null)
    {
      onComplete({
        success = false
        orderId = orderItem.id
      })
    }
    debugPrint("g_orders::activateOrder: Activation didn't start. "
      + "Already activating order with ID: " + activatingLocalOrderId)
    return
  }
  activatingLocalOrderId = orderItem.id
  activatingLocalOrderCallback = onComplete
  debugPrint("g_orders::activateOrder: Activation started. "
    + "Order ID: " + activatingLocalOrderId + " Order UID: " + orderItem.uids[0])
  if (checkCurrentMission(orderItem))
  {
    ::set_order_accepted_cb(::g_orders, onOrderAccepted)
    ::use_order_request(orderItem.uids[0])
  }
  else
    onOrderAccepted(::g_order_use_result.RESTRICTED_MISSION.code)
}

/**
 * Returns amount of times item was used by this player during
 * current session. This data is reset when battle ends.
 */
g_orders.getTimesUsedOrderItem <- function getTimesUsedOrderItem(orderItem)
{
  return ::getTblValue(orderItem.id, timesUsedByOrderItemId, 0)
}

/**
 * Manually managing activated order items as there's no way
 * to retrieve this kind of info from server.
 */
g_orders.isOrderItemActive <- function isOrderItemActive(orderItem)
{
  return ::isInArray(orderItem.id, activeLocalOrderIds)
}

/**
 * @param fullUpdate Setting to 'true' forces
 * to rebuild whole status object content.
 * Used to avoid multiple 'replaceContent' calls.
 */
g_orders.updateOrderStatusObject <- function updateOrderStatusObject(statusObj, fullUpdate)
{
  if (!::checkObj(statusObj))
    return

  local orderObject = hasActiveOrder
    ? activeOrder
    : prevActiveOrder

  if (fullUpdate)
  {
    local statusContent = getStatusContent(orderObject, (statusObj?.isHalignRight ?? "no") == "yes")
    local guiScene = statusObj.getScene()
    guiScene.replaceContentFromText(statusObj, statusContent, statusContent.len(), this)

    // (Re)enable timer.
    local orderTimerObj = statusObj.findObject("order_timer")
    if (::checkObj(orderTimerObj))
      orderTimerObj.setUserData(this)
  }

  local waitingForCooldown = cooldownTimeleft > 0 && prevActiveOrder != null

  local showStatus = hasActiveOrder || waitingForCooldown
  setStatusObjVisibility(statusObj, showStatus)
  if (!showStatus)
    return

  // Updating order status text.
  local statusTextObj = statusObj.findObject("status_text")
  if (::checkObj(statusTextObj))
    statusTextObj.setValue(getStatusText())

  // Updating order bottom status text.
  local statusTextBottomObj = statusObj.findObject("status_text_bottom")
  if (::checkObj(statusTextBottomObj))
    statusTextBottomObj.setValue(getStatusTextBottom())

  // Updating order score table.
  local tableTexts = getScoreTableTexts()
  local showTable = tableTexts != null && tableTexts.len()
  local statusTableObj = statusObj.findObject("status_table")
  local numScores = ::min(tableTexts ? tableTexts.len() : 0, maxRowsInScoreTable)
  if (::checkObj(statusTableObj))
    statusTableObj.show(showTable)
  if (showTable)
  {
    for (local i = 0; i < numScores; ++i)
    {
      local rowObj = getRowObjByIndex(i, statusObj)
      ::dagor.assertf(rowObj != null, "Error updating order status: Row object not found.")
      setRowObjTexts(rowObj, tableTexts[i].player, tableTexts[i].score, true)
    }
  }

  // Hiding rows without data.
  for (local i = numScores; i < maxRowsInScoreTable; ++i)
  {
    local rowObj = getRowObjByIndex(i, statusObj)
    ::dagor.assertf(rowObj != null, "Error updating order status: Row object not found.")
    setRowObjTexts(rowObj, "", "", false)
  }
}

g_orders.setStatusObjVisibility <- function setStatusObjVisibility(statusObj, visible)
{
  if (!::checkObj(statusObj))
    return

  local ordersBlockObj = statusObj.findObject("orders_block")
  if (::check_obj(ordersBlockObj))
    ordersBlockObj.show(visible && !isOrdersHidden)
}

g_orders.getRowObjByIndex <- function getRowObjByIndex(rowIndex, statusObj)
{
  local rowObj = statusObj.findObject("order_score_row_" + rowIndex)
  return ::checkObj(rowObj) ? rowObj : null
}

g_orders.setRowObjTexts <- function setRowObjTexts(rowObj, nameText, scoreText, pilotIconVisible)
{
  if (!::checkObj(rowObj))
    return
  local playerNameTextObj = rowObj.findObject("order_score_player_name_text")
  if (::checkObj(playerNameTextObj))
    playerNameTextObj.setValue(nameText)
  local playerScoreTextObj = rowObj.findObject("order_score_value_text")
  if (::checkObj(playerScoreTextObj))
    playerScoreTextObj.setValue(scoreText)
  local pilotIconObj = rowObj.findObject("order_score_pilot_icon")
  if (::checkObj(pilotIconObj))
    pilotIconObj.show(pilotIconVisible)
}


g_orders.getScoreTableTexts <- function getScoreTableTexts()
{
  local showOrder = isOrderInfoVisible()
  if ( !showOrder )
    return []
  local orderObject = hasActiveOrder ? activeOrder : prevActiveOrder
  local scoreData = getOrderScores(orderObject)
  if (!scoreData)
    return []
  prepareStatusScores(scoreData, orderObject)
  return scoreData.map(function (item) {
    local playerData = ::g_orders.getPlayerDataByScoreData(item)
    return {
      score = orderObject.orderType.formatScore(item.score)
      player = (::getTblValue("playerIndex", item, 0) + 1).tostring() + ". " + ::build_mplayer_name(playerData)
    }
  })
}


g_orders.isOrderInfoVisible <- function isOrderInfoVisible()
{
  return hasActiveOrder || (cooldownTimeleft > 0 && prevActiveOrder != null)
}


g_orders.getStatusText <- function getStatusText()
{
  local orderObject = hasActiveOrder ? activeOrder : prevActiveOrder
  if (orderObject == null)
    return ""
  updateStatusTextView(orderObject, false)
  local view = orderObject.statusTextView
  local result = ""
  if (!hasActiveOrder)
  {
    result += ::colorize(statusColorScheme.parameterLabelColor, view.orderFinishedLabel)
    result += ::colorize(statusColorScheme.parameterValueColor, view.orderName)
    return result
  }
  result += ::colorize(statusColorScheme.parameterLabelColor, view.orderActiveLabel) + " "
  result += ::colorize(statusColorScheme.parameterValueColor, view.orderName) + "\n"
  result += view.orderDescription + "\n"
  if (orderObject.starterPlayer != null && checkOrderActivationTime(5))
  {
    result += ::colorize(statusColorScheme.parameterLabelColor, view.orderStarterLabel)
    result += ::colorize(statusColorScheme.parameterValueColor, view.orderStarter) + "\n"
  }
  if (orderObject.targetPlayer != emptyPlayerData)
  {
    result += ::colorize(statusColorScheme.parameterLabelColor, view.orderTargetLabel)
    result += ::colorize(statusColorScheme.parameterValueColor, view.orderTarget) + "\n"
    if (orderObject.timeToSwitchTarget != -1)
    {
      result += ::colorize(statusColorScheme.parameterLabelColor, view.timeToSwitchTargetLabel)
      result += ::colorize(statusColorScheme.parameterValueColor, view.timeToSwitchTarget) + "\n"
    }
  }
  result += ::colorize(statusColorScheme.parameterLabelColor, view.orderTimeleftLabel) + " "
  result += ::colorize(statusColorScheme.parameterValueColor, view.orderTimeleft)
  return result
}

/**
 * Returns true if order was activated less
 * than specified amount of time ago.
 */
g_orders.checkOrderActivationTime <- function checkOrderActivationTime(timeSeconds)
{
  if (activeOrder.orderItem == null)
    return false
  return getOrderTimeleft(activeOrder) >= activeOrder.orderItem.timeTotal - timeSeconds
}

g_orders.getStatusTextBottom <- function getStatusTextBottom()
{
  if (hasActiveOrder || prevActiveOrder == null)
    return ""
  local view = prevActiveOrder.statusTextView
  local result = ""
  result += ::colorize(statusColorScheme.parameterLabelColor, view.cooldownTimeleftLabel)
  result += ::colorize(statusColorScheme.parameterValueColor, view.cooldownTimeleft)
  return result
}

g_orders.showOrdersContainer <- function showOrdersContainer(isShown)
{
  isOrdersContainerVisible = isShown
}

g_orders.getStatusContent <- function getStatusContent(orderObject, isHalignRight = false)
{
  local orderType = orderObject == null ? g_order_type.UNKNOWN : orderObject.orderType
  local view = {
    rows = []
    playersHeaderText = ::loc("items/order/scoreTable/playersHeader")
    scoreHeaderText = orderType.getScoreHeaderText()
    needPlaceInHiddenContainer = isInSpectatorMode()
    isHiddenContainerVisible = isOrdersContainerVisible
    isHalignRight = isHalignRight
  }
  for (local i = 0; i < maxRowsInScoreTable; ++i)
    view.rows.append({ rowIndex = i })
  return ::handyman.renderCached("gui/items/orderStatus", view)
}

/**
 * Implementation of this method will change after
 * switching to multiple active orders by same player.
 */
g_orders.updateActiveLocalOrders <- function updateActiveLocalOrders()
{
  local starterUid = ::getTblValue("userId", activeOrder.starterPlayer, null)
  local itemId = ::getTblValue("id", activeOrder.orderItem, null)
  for (local i = activeLocalOrderIds.len() - 1; i >= 0; --i)
  {
    local id = activeLocalOrderIds[i]

    // How? We don't know yet.
    // Added assertions for further investigation.
    if (id == null)
    {
      ::debugTableData(::g_orders)
      ::dagor.assertf(false,
        "Active order ids array contains null. Report this issue immediately.")
      activeLocalOrderIds.remove(i)
      continue
    }

    if (id != itemId || starterUid != ::my_user_id_str)
    {
      activeLocalOrderIds.remove(i)
      timesUsedByOrderItemId[id] <- ::getTblValue(id, timesUsedByOrderItemId, 0) + 1
    }
  }
}

g_orders.getActiveOrderObjective <- function getActiveOrderObjective()
{
  local objectives = get_objectives_list()
  foreach (objective in objectives)
  {
    if (::getTblValue("status", objective, 0) == 0)
      continue

    local objectiveType = ::getTblValue("type", objective, -1)
    if (objectiveType == ::OBJECTIVE_TYPE_ORDER)
      return objective
  }
  return null
}

g_orders.onOrderAccepted <- function onOrderAccepted(useResultCode)
{
  local useResult = ::g_order_use_result.getOrderUseResultByCode(useResultCode)
  debugPrint("g_orders::onOrderAccepted: Activation complete. Result: "
    + ::toString(useResult))
  ::scene_msg_box("order_use_result", null, useResult.createResultMessage(true),
    [["ok", function() {
      ::broadcastEvent("OrderUseResultMsgBoxClosed")
    } ]], "ok")
  if (useResult == ::g_order_use_result.OK)
  {
    if (activatingLocalOrderId == null)
    {
      ::debugTableData(::g_orders)
      ::dagor.assertf(false,
        "Activating local order is null. Report this issue immediately.")
    }
    activeLocalOrderIds.append(activatingLocalOrderId)
    ::broadcastEvent("OrderActivated")
  }
  if (activatingLocalOrderCallback != null)
  {
    activatingLocalOrderCallback({
      success = true
      useResult = useResult
      orderId = activatingLocalOrderId
    })
    activatingLocalOrderCallback = null
  }
  activatingLocalOrderId = null
  ::set_order_accepted_cb(::g_orders, null)
}

/** This is order counter local in scope of one battle. */
g_orders.getOrderId <- function getOrderId(orderObjective)
{
  return ::getTblValue("id", orderObjective, -1)
}

/**
 * Order status is: running, failed, succeed.
 * @see ::g_objective_status
 */
g_orders.getOrderStatus <- function getOrderStatus(orderObjective)
{
  local statusCode = ::getTblValue("status", orderObjective, -1)
  return ::g_objective_status.getObjectiveStatusByCode(statusCode)
}

g_orders.getOrderType <- function getOrderType(orderObjective)
{
  local orderItem = getOrderItem(orderObjective)
  if (orderItem == null)
    return ::g_order_type.UNKNOWN
  return orderItem.orderType
}

g_orders.getOrderItem <- function getOrderItem(orderObjective)
{
  local objectiveId = ::getTblValue("objectiveId", orderObjective, null)
  return ::ItemsManager.findItemById(objectiveId, itemType.ORDER)
}

/** Called only when no active order. */
g_orders.updateCooldownTimeleft <- function updateCooldownTimeleft()
{
  cooldownTimeleft = ::max(getCooldownTimeleft(), 0)
}

g_orders.getCooldownTimeleft <- function getCooldownTimeleft()
{
  // Returns 1 or 2 as team indices.
  local playerTeam = ::get_mp_local_team()
  if (playerTeam == Team.Any)
    return -1
  local tblTeams = ::get_mp_tbl_teams()
  local localTeamTbl = ::getTblValue(playerTeam - 1, tblTeams)
  return ::getTblValue("orderCooldownLeft", localTeamTbl, 0)
}

/**
 * @param orderObject 'activeOrder' or 'prevActiveOrder'
 * @param fullUpdate Setting to 'true' will update parameters
 * that are not changing for same order.
 */
g_orders.updateStatusTextView <- function updateStatusTextView(orderObject, fullUpdate)
{
  // Possible when another player activates an order.
  if (orderObject == null)
    return

  local view = orderObject.statusTextView

  if (fullUpdate)
  {
    // Order name
    view.orderActiveLabel <- ::loc("icon/orderSymbol")
    view.orderName <- orderObject.orderItem.getStatusOrderName()

    view.orderTimeleftLabel <- ::loc("icon/timer")

    // Order starter
    view.orderStarterLabel <- ::loc("items/order/status/starter") + ::loc("ui/colon")
    view.orderStarter <- ::build_mplayer_name(orderObject.starterPlayer)

    // Order target
    view.orderTargetLabel <- ::loc("items/order/status/target") + ::loc("ui/colon")

    view.cooldownTimeleftLabel <- ::loc("items/order/status/cooldown") + ::loc("ui/colon")
    view.orderFinishedLabel <- ::loc("items/order/status/finished") + ::loc("ui/colon")
    view.timeToSwitchTargetLabel <- ::loc("items/order/status/timeToSwitchTarget") + ::loc("ui/colon")
  }

  // Order description
  local orderTypeParams = orderObject?.orderItem.typeParams
  view.orderDescription <- orderTypeParams != null
    ? orderObject.orderType.getObjectiveDescription(orderTypeParams, statusColorScheme)
    : null

  view.orderTimeleft <- time.secondsToString(getOrderTimeleft(orderObject))
  view.cooldownTimeleft <- time.secondsToString(cooldownTimeleft)
  if (orderObject.targetPlayer != emptyPlayerData)
    view.orderTarget <- ::build_mplayer_name(orderObject.targetPlayer)
  if (orderObject.timeToSwitchTarget != -1)
    view.timeToSwitchTarget <- time.secondsToString(orderObject.timeToSwitchTarget)
}

g_orders.getOrderTimeleft <- function getOrderTimeleft(orderObject)
{
  return orderObject?.orderObjective.timeLeft ?? 0
}

/** Returns null-object player data if nothing found. */
g_orders.getPlayerDataById <- function getPlayerDataById(playerId)
{
  if (!ordersEnabled)
  {
    debugPrint("g_orders::getPlayerDataById: Calling when orders are disabled.")
    ::callstack()
  }
  local playerData = playerDataById?[playerId] ?? ::get_mplayer_by_id(playerId) ?? emptyPlayerData
  if (::is_replay_playing())
  {
    playerData.isLocal = spectatorWatchedHero.id == playerData.id
    playerData.isInHeroSquad = ::SessionLobby.isEqualSquadId(spectatorWatchedHero.squadId, playerData?.squadId)
  }
  if (!(playerId in playerDataById))
    playerDataById[playerId] <- playerData
  return playerData
}

g_orders.getPlayerDataByScoreData <- function getPlayerDataByScoreData(scoreData)
{
  if (scoreData.playerId != -1)
    return getPlayerDataById(scoreData.playerId)
  return ::getTblValue("playerData", scoreData, emptyPlayerData)
}


//
// Handlers
//
g_orders.onChangeOrderVisibility <- function onChangeOrderVisibility(obj, dt)
{
  isOrdersHidden = !isOrdersHidden
  updateHideOrderBlock()
  updateOrderVisibility()
}

g_orders.onOrderTimerUpdate <- function onOrderTimerUpdate(obj, dt)
{
  ::g_orders.updateActiveOrder()
}

g_orders.onEventLobbyStatusChange <- function onEventLobbyStatusChange(params)
{
  if (!::SessionLobby.isInRoom())
    disableOrders()
}

g_orders.onEventActiveOrderChanged <- function onEventActiveOrderChanged(params)
{
  updateOrderStatus(true)
  local text
  if (::g_orders.hasActiveOrder)
  {
    text = ::loc("items/order/hudMessage/activate", {
      playerName = ::build_mplayer_name(::g_orders.activeOrder.starterPlayer)
      orderName = ::g_orders.activeOrder.orderItem.getName(false)
    })
    isOrdersHidden = false
  }
  else
  {
    text = ::loc("items/order/hudMessage/finished", {
      orderName = params.oldActiveOrder.orderItem.getName(false)
    })
  }
  ::g_hud_event_manager.onHudEvent("HudMessage", {
    id = -1
    type = ::HUD_MSG_OBJECTIVE
    text = text
  })
}

g_orders.onEventOrderUpdated <- function onEventOrderUpdated(params)
{
  updateOrderStatus(false)
  updateHideOrderBlock()
}

g_orders.onEventWatchedHeroSwitched <- function onEventWatchedHeroSwitched(params)
{
  updateActiveOrder(true, true)
}

g_orders.onEventChangedCursorVisibility <- function onEventChangedCursorVisibility(params)
{
  updateHideOrderBlock()
}

g_orders.debugPrint <- function debugPrint(message)
{
  if (enableDebugPrint)
    ::dagor.debug("g_orders::debugPrint:\n" + message)
}

/**
 * Returns valid order scores, taking in account fact that when order
 * finishes it's objective-object does not hold valid score for winner.
 */
g_orders.getOrderScores <- function getOrderScores(orderObject)
{
  local scores = orderObject?.orderObjective.score
  if (scores != null)
  {
    scores = clone scores
    foreach (player in debugPlayers)
      scores.append(player.scoreData)
    addLocalPlayerScoreData(scores)
  }

  local winnerScoreData = ::getTblValue(orderObject.orderId, winnerScoreDataByOrderId, null)
  if (scores == null || winnerScoreData == null)
    return scores

  for (local i = 0; i < scores.len(); ++i)
  {
    local scoreData = scores[i]
    if (scoreData.playerId == winnerScoreData.playerId)
    {
      scores[i] = clone winnerScoreData
      scores[i].playerIndex <- i
      break
    }
  }
  return scores
}

g_orders.prepareStatusScores <- function prepareStatusScores(statusScores, orderObject)
{
  statusScores.sort(orderObject.orderType.sortPlayerScores)

  // Remove score data with not player data.
  for (local i = statusScores.len() - 1; i >= 0; --i)
  {
    local playerData = getPlayerDataByScoreData(statusScores[i])
    if (playerData == null)
      statusScores.remove(i)
  }

  // Update players indexes
  local localPlayerIndex = -1
  foreach(idx, score in statusScores)
  {
    score.playerIndex <- idx
    if (localPlayerIndex >= 0)
      continue

    local playerData = getPlayerDataByScoreData(score)
    if (::getTblValue("userId", playerData) == ::my_user_id_str)
      localPlayerIndex = idx
  }

  if (localPlayerIndex == -1)
    return

  // Removing players preceding local player so that it
  // will be within first 'maxRowsInScoreTable' players.
  while (localPlayerIndex >= maxRowsInScoreTable)
  {
    statusScores.remove(maxRowsInScoreTable - 1)
    --localPlayerIndex
  }
}

/**
 * Adds local player data and score
 * dummy to specified scores array.
 */
g_orders.addLocalPlayerScoreData <- function addLocalPlayerScoreData(scores)
{
  local checkFunc = ::is_replay_playing() ?
    function(p) { return p.id == spectatorWatchedHero.id } :
    function(p) { return p.userId == ::my_user_id_str }

  local foundThisPlayer = false
  foreach (scoreData in scores)
    if (checkFunc(getPlayerDataByScoreData(scoreData)))
    {
      foundThisPlayer = true
      break
    }
  if (foundThisPlayer)
    return
  scores.append({
    playerId = -1
    score = 0
    playerData = getLocalPlayerData()
  })
}

g_orders.saveOrderStatusPositionAndSize <- function saveOrderStatusPositionAndSize()
{
  if (!::checkObj(ordersStatusObj))
    return

  local frameObj = ordersStatusObj.findObject("order_status_frame")
  if (!::checkObj(frameObj)) // Possible if not in spectator mode.
    return

  local frameSize = frameObj.getSize()

  // Frame object has invalid size. This means it
  // was not rendered yet. Bail out then.
  if (frameSize[0] == -1)
    return

  orderStatusSize = frameSize

  orderStatusPosition = frameObj.getPosRC()
  local statusObjPosition = ordersStatusObj.getPosRC()

  // Saving frame object position relative to parent.
  orderStatusPosition[0] -= statusObjPosition[0]
  orderStatusPosition[1] -= statusObjPosition[1]
}

g_orders.getLocalPlayerData <- function getLocalPlayerData()
{
  if (::is_replay_playing())
    localPlayerData = getPlayerDataById(spectatorWatchedHero.id)

  if (localPlayerData == null)
    localPlayerData = ::get_local_mplayer()
  return localPlayerData
}


::cross_call_api.active_order_request_update <- @()::g_orders.updateActiveOrder()
::cross_call_api.active_order_enable <- @()::g_orders.enableOrdersWithoutDagui()

::g_script_reloader.registerPersistentDataFromRoot("g_orders")
