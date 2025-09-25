from "%scripts/dagui_natives.nut" import set_order_accepted_cb, use_order_request, is_cursor_visible_in_gui
from "%scripts/dagui_library.nut" import *
from "%scripts/teamsConsts.nut" import Team
from "%scripts/items/itemsConsts.nut" import itemType, itemsTab

let { g_hud_event_manager } = require("%scripts/hud/hudEventManager.nut")
let { orderUseResult, getOrderUseResultByCode } = require("%scripts/items/orderUseResult.nut")
let { INVALID_SQUAD_ID } = require("matching.errors")
let { HUD_MSG_OBJECTIVE } = require("hudMessages")
let { get_mplayer_by_id, get_game_type, get_local_mplayer, get_mp_local_team } = require("mission")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { debug_dump_stack } = require("dagor.debug")
let { format } = require("string")
let time = require("%scripts/time.nut")
let { broadcastEvent, removeAllListenersByEnv, subscribe_handler
} = require("%sqStdLibs/helpers/subscriptions.nut")
let { DEFAULT_HANDLER } = require("%scripts/g_listener_priority.nut")
let spectatorWatchedHero = require("%scripts/replays/spectatorWatchedHero.nut")
let { is_replay_playing } = require("replays")
let { get_time_msec } = require("dagor.time")
let { eventbus_send, eventbus_subscribe } = require("eventbus")
let { get_mp_tbl_teams, get_objectives_list, OBJECTIVE_TYPE_ORDER } = require("guiMission")
let { isInFlight } = require("gameplayBinding")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { isInSessionRoom, getSessionInfo } = require("%scripts/matchingRooms/sessionLobbyState.nut")
let { userIdStr } = require("%scripts/user/profileStates.nut")
let { findItemById, getInventoryList } = require("%scripts/items/itemsManager.nut")
let { orderTypes } = require("%scripts/items/orderType.nut")
let { objectiveStatus, getObjectiveStatusByCode
} = require("%scripts/misObjectives/objectiveStatus.nut")
let { isEqualSquadId } = require("%scripts/squads/squadState.nut")
let { buildMplayerName } = require("%scripts/statistics/mplayersList.nut")
let { isPlayerDedicatedSpectator } = require("%scripts/matchingRooms/sessionLobbyMembersInfo.nut")

const AUTO_ACTIVATE_TIME = 60
const MAX_ROWS_IN_SCORE_TABLE = 3

let hasActiveOrder = persist("asActiveOrder", @() { value = false })
let activeLocalOrderIds = persist("activeLocalOrderIds", @() [])
let timesUsedByOrderItemId = persist("timesUsedByOrderItemId", @() {})
let activeOrder = persist("activeOrder", @() {
  orderId = -1
  orderObjective = null
  orderType = orderTypes.UNKNOWN
  orderStatus = objectiveStatus.UNKNOWN
  orderItem = null
  starterPlayer = null
  targetPlayer = null
  timeToSwitchTarget = -1

  
  
  
  
  
  statusTextView = {}
})


let prevActiveOrder = persist("prevActiveOrder", @() { value = null })
let cooldownTimeleft = persist("cooldownTimeleft", @() { value = 0 })




let winnerScoreDataByOrderId = persist("winnerScoreDataByOrderId", @() {})
let orderStatusPosition = persist("orderStatusPosition", @() { value = [] })

let emptyPlayerData = {
  name = ""
  clanTag = ""
  aircraftName = ""
  id = -1
  team = -1
  isLocal = false
  isInHeroSquad = false
  squadId = INVALID_SQUAD_ID
  userId = null
}



let playerDataById = {}

let statusColorScheme = {
  typeDescriptionColor = "unlockActiveColor"
  parameterValueColor = "unlockActiveColor"
  parameterLabelColor = "userlogColoredText"
  objectiveDescriptionColor = "unlockActiveColor"
}

let emptyColorScheme = {
  typeDescriptionColor = ""
  parameterValueColor = ""
  parameterLabelColor = ""
  objectiveDescriptionColor = ""
}

let eventToHandlerMap = {}

local activatingLocalOrderId = null
local activatingLocalOrderCallback = null
local listenersEnabled = false
local ordersStatusObj = null
local enableDebugPrint = true
local ordersEnabled = false
local localPlayerData = null
local isOrdersContainerVisible = false
local isOrdersHidden = false
local ordersToActivate = null
local isActivationProgress = false

let debugPlayers = []


































let getOrderAutoActivateHint = @() loc("guiHints/order_auto_activate",
  { time = $"{AUTO_ACTIVATE_TIME} {loc("mainmenu/seconds")}" })



let collectOrdersToActivate = @() ordersToActivate = getInventoryList(
  itemType.ORDER, @(item) item.getAmount() > 0).sort(@(a, b) a.expiredTimeSec <=> b.expiredTimeSec)

let hasOrdersToActivate = @() (ordersToActivate?.len() ?? 0) > 0

function getActivateButtonLabel() {
  local label = loc("flightmenu/btnActivateOrder")
  if (cooldownTimeleft.value > 0) {
    let timeText = time.secondsToString(cooldownTimeleft.value)
    label = "".concat(label, format(" (%s)", timeText))
  }
  return label
}

function checkCurrentMission(selectedOrderItem) {
  if (selectedOrderItem == null)
    return true

  let missionName = getSessionInfo()?.mission.name
  if (missionName == null)
    return true

  if (selectedOrderItem.iType == itemType.ORDER)
    return selectedOrderItem.checkMission(missionName)

  return true
}

let showOrdersContainer = @(isShown) isOrdersContainerVisible = isShown

function updateOrderVisibility() {
  if (!checkObj(ordersStatusObj))
    return

  let ordersBlockObj = ordersStatusObj.findObject("orders_block")
  if (checkObj(ordersBlockObj))
    ordersBlockObj.show(!isOrdersHidden)
}

function setStatusObjVisibility(statusObj, visible) {
  if (!checkObj(statusObj))
    return

  let ordersBlockObj = statusObj.findObject("orders_block")
  if (checkObj(ordersBlockObj))
    ordersBlockObj.show(visible && !isOrdersHidden)
}

function getRowObjByIndex(rowIndex, statusObj) {
  let rowObj = statusObj.findObject($"order_score_row_{rowIndex}")
  return checkObj(rowObj) ? rowObj : null
}

function setRowObjTexts(rowObj, nameText, scoreText, pilotIconVisible) {
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

function ordersCanBeUsed() {
  let checkGameType = (get_game_type() & GT_USE_ORDERS) != 0
  return checkGameType && isInFlight() && hasFeature("Orders")
}

function getOrderActivateInfoText() {
  if (!isInFlight())
    return loc("order/usableOnlyInBattle")
  if ((get_game_type() & GT_USE_ORDERS) == 0)
    return loc("order/notUsableInCurrentBattle")
  if (hasActiveOrder.value)
    return loc("order/onlyOneOrderCanBeActive")
  return ""
}

let isInSpectatorMode = @() isPlayerDedicatedSpectator() || is_replay_playing()
let showActivateOrderButton = @() !isInSpectatorMode() && ordersCanBeUsed()



let getTimesUsedOrderItem = @(orderItem) getTblValue(orderItem.id, timesUsedByOrderItemId, 0)



let isOrderItemActive = @(orderItem) isInArray(orderItem.id, activeLocalOrderIds)

let isOrderInfoVisible = @() hasActiveOrder.value
  || (cooldownTimeleft.value > 0 && prevActiveOrder.value != null)

function updateHideOrderBlock() {
  if (!checkObj(ordersStatusObj))
    return

  let isHideOrderBtnVisible = isOrderInfoVisible() && is_cursor_visible_in_gui()

  let hideOrderBlockObj = ordersStatusObj.findObject("hide_order_block")
  if (!checkObj(hideOrderBlockObj))
    return

  hideOrderBlockObj.collapsed = isOrdersHidden ? "yes" : "no"

  let hideOrderBtnObj = hideOrderBlockObj.findObject("hide_order_btn")
  if (checkObj(hideOrderBtnObj))
    hideOrderBtnObj.isHidden = isHideOrderBtnVisible ? "no" : "yes"

  let hideOrderTextIconObj = hideOrderBlockObj.findObject("hide_order_text")
  if (checkObj(hideOrderTextIconObj))
    hideOrderTextIconObj.show(isHideOrderBtnVisible && isOrdersHidden)
}

let getOrderTimeleft = @(orderObject) orderObject?.orderObjective.timeLeft ?? 0

function debugPrint(message) {
  if (enableDebugPrint)
    log($"orders: debugPrint:\n{message}")
}



function checkOrderActivationTime(timeSeconds) {
  if (activeOrder.orderItem == null)
    return false
  return getOrderTimeleft(activeOrder) >= activeOrder.orderItem.timeTotal - timeSeconds
}




function updateStatusTextView(orderObject, fullUpdate) {
  
  if (orderObject == null)
    return

  let view = orderObject.statusTextView

  if (fullUpdate) {
    
    view.orderActiveLabel <- loc("icon/orderSymbol")
    view.orderName <- orderObject.orderItem.getStatusOrderName()

    view.orderTimeleftLabel <- loc("icon/timer")

    
    view.orderStarterLabel <- "".concat(loc("items/order/status/starter"), loc("ui/colon"))
    view.orderStarter <- buildMplayerName(orderObject.starterPlayer)

    
    view.orderTargetLabel <- "".concat(loc("items/order/status/target"), loc("ui/colon"))

    view.cooldownTimeleftLabel <- "".concat(loc("items/order/status/cooldown"), loc("ui/colon"))
    view.orderFinishedLabel <- "".concat(loc("items/order/status/finished"), loc("ui/colon"))
    view.timeToSwitchTargetLabel <- "".concat(loc("items/order/status/timeToSwitchTarget"), loc("ui/colon"))
  }

  
  let orderTypeParams = orderObject?.orderItem.typeParams
  view.orderDescription <- orderTypeParams != null
    ? orderObject.orderType.getObjectiveDescription(orderTypeParams, statusColorScheme,
        activeOrder.targetPlayer, emptyColorScheme)
    : null

  view.orderTimeleft <- time.secondsToString(getOrderTimeleft(orderObject))
  view.cooldownTimeleft <- time.secondsToString(cooldownTimeleft.value)
  if (orderObject.targetPlayer != emptyPlayerData)
    view.orderTarget <- buildMplayerName(orderObject.targetPlayer)
  if (orderObject.timeToSwitchTarget != -1)
    view.timeToSwitchTarget <- time.secondsToString(orderObject.timeToSwitchTarget)
}


function getStatusText() {
  let orderObject = hasActiveOrder.value ? activeOrder : prevActiveOrder.value
  if (orderObject == null)
    return ""

  updateStatusTextView(orderObject, false)
  let view = orderObject.statusTextView
  if (!hasActiveOrder.value) {
    return "".concat(colorize(statusColorScheme.parameterLabelColor, view.orderFinishedLabel),
      colorize(statusColorScheme.parameterValueColor, view.orderName))
  }
  local result = "".concat(colorize(statusColorScheme.parameterLabelColor, view.orderActiveLabel), " ",
    colorize(statusColorScheme.parameterValueColor, view.orderName), "\n",
    view.orderDescription, "\n")
  if (orderObject.starterPlayer != null && checkOrderActivationTime(5)) {
    result = "".concat(result, colorize(statusColorScheme.parameterLabelColor, view.orderStarterLabel),
      colorize(statusColorScheme.parameterValueColor, view.orderStarter), "\n")
  }
  if (orderObject.targetPlayer != emptyPlayerData) {
    result = "".concat(result, colorize(statusColorScheme.parameterLabelColor, view.orderTargetLabel),
      colorize(statusColorScheme.parameterValueColor, view.orderTarget), "\n")
    if (orderObject.timeToSwitchTarget != -1) {
      result = "".concat(result, colorize(statusColorScheme.parameterLabelColor, view.timeToSwitchTargetLabel),
        colorize(statusColorScheme.parameterValueColor, view.timeToSwitchTarget), "\n")
    }
  }
  result = "".concat(result, colorize(statusColorScheme.parameterLabelColor, view.orderTimeleftLabel), " ",
    colorize(statusColorScheme.parameterValueColor, view.orderTimeleft))
  return result
}

function getCooldownTimeleft() {
  
  let playerTeam = get_mp_local_team()
  if (playerTeam == Team.Any)
    return -1
  let tblTeams = get_mp_tbl_teams()
  let localTeamTbl = getTblValue(playerTeam - 1, tblTeams)
  return getTblValue("orderCooldownLeft", localTeamTbl, 0)
}


let updateCooldownTimeleft = @() cooldownTimeleft.value = max(getCooldownTimeleft(), 0)

function getStatusTextBottom() {
  if (hasActiveOrder.value || prevActiveOrder.value == null)
    return ""
  let view = prevActiveOrder.value.statusTextView
  return "".concat(colorize(statusColorScheme.parameterLabelColor, view.cooldownTimeleftLabel),
    colorize(statusColorScheme.parameterValueColor, view.cooldownTimeleft))
}

function getStatusContent(orderObject, isHalignRight = false) {
  let orderType = orderObject == null ? orderTypes.UNKNOWN : orderObject.orderType
  let view = {
    rows = []
    playersHeaderText = loc("items/order/scoreTable/playersHeader")
    scoreHeaderText = orderType.getScoreHeaderText()
    needPlaceInHiddenContainer = isInSpectatorMode()
    isHiddenContainerVisible = isOrdersContainerVisible
    isHalignRight = isHalignRight
  }

  for (local i = 0; i < MAX_ROWS_IN_SCORE_TABLE; ++i)
    view.rows.append({ rowIndex = i })

  return handyman.renderCached("%gui/items/orderStatus.tpl", view)
}



function updateActiveLocalOrders() {
  let starterUid = getTblValue("userId", activeOrder.starterPlayer, null)
  let itemId = getTblValue("id", activeOrder.orderItem, null)
  for (local i = activeLocalOrderIds.len() - 1; i >= 0; --i) {
    let id = activeLocalOrderIds[i]

    
    
    if (id == null) {
      debugTableData(activeLocalOrderIds)
      assert(false,
        "Active order ids array contains null. Report this issue immediately.")
      activeLocalOrderIds.remove(i)
      continue
    }

    if (id != itemId || starterUid != userIdStr.get()) {
      activeLocalOrderIds.remove(i)
      timesUsedByOrderItemId[id] <- getTblValue(id, timesUsedByOrderItemId, 0) + 1
    }
  }
}

function getActiveOrderObjective() {
  let objectives = get_objectives_list()
  foreach (objective in objectives) {
    if (getTblValue("status", objective, 0) == 0)
      continue

    let objectiveType = getTblValue("type", objective, -1)
    if (objectiveType == OBJECTIVE_TYPE_ORDER)
      return objective
  }
  return null
}

function onOrderAccepted(useResultCode, isSilent = false) {
  let useResult = getOrderUseResultByCode(useResultCode)
  debugPrint($"orders: onOrderAccepted: Activation complete. Result: {useResult}")

  if (!isSilent)
    scene_msg_box("order_use_result", null, useResult.createResultMessage(true),
      [["ok", @() broadcastEvent("OrderUseResultMsgBoxClosed")]], "ok")

  if (useResult == orderUseResult.OK) {
    if (activatingLocalOrderId == null) {
      assert(false,
        "Activating local order is null. Report this issue immediately.")
    }
    activeLocalOrderIds.append(activatingLocalOrderId)
    broadcastEvent("OrderActivated")
  }

  if (activatingLocalOrderCallback != null) {
    activatingLocalOrderCallback({
      success = true
      useResult = useResult
      orderId = activatingLocalOrderId
    })
    activatingLocalOrderCallback = null
  }
  activatingLocalOrderId = null
  set_order_accepted_cb(null, null)
  isActivationProgress = false
}


let getOrderId = @(orderObjective) getTblValue("id", orderObjective, -1)

function activateOrder(orderItem, onComplete = null, isSilent = false) {
  isActivationProgress = true
  if (activatingLocalOrderId != null) {
    if (onComplete != null) {
      onComplete({
        success = false
        orderId = orderItem.id
      })
    }
    debugPrint("".concat("orders: activateOrder: Activation didn't start. ",
      "Already activating order with ID: ", activatingLocalOrderId))
    return
  }
  activatingLocalOrderId = orderItem.id
  activatingLocalOrderCallback = onComplete
  debugPrint("".concat("orders: activateOrder: Activation started. ",
    "Order ID: ", activatingLocalOrderId, " Order UID: ", orderItem.uids[0]))
  if (checkCurrentMission(orderItem)) {
    set_order_accepted_cb(null, @(res) onOrderAccepted(res, isSilent))
    use_order_request(orderItem.uids[0])
  }
  else
    onOrderAccepted(orderUseResult.RESTRICTED_MISSION.code, isSilent)
}


function activateSoonExpiredOrder() {
  if (!hasFeature("OrderAutoActivate") || isActivationProgress)
    return

  
  ordersToActivate = ordersToActivate.filter(@(inst) !inst.isExpired())

  for (local i = 0; i < ordersToActivate.len(); i++) {
    let order = ordersToActivate[i]
    if (order.isActivateBeforeExpired && order.hasExpireTimer()
        && (order.expiredTimeSec - get_time_msec() * 0.001) <= AUTO_ACTIVATE_TIME) {
      activateOrder(order,
        function(p) {
          if (p.useResult == orderUseResult.OK)
            ordersToActivate.remove(i)
        }, true)
      break
    }
  }
}



function getOrderStatus(orderObjective) {
  let statusCode = getTblValue("status", orderObjective, -1)
  return getObjectiveStatusByCode(statusCode)
}

function getOrderItem(orderObjective) {
  let objectiveId = getTblValue("objectiveId", orderObjective, null)
  return findItemById(objectiveId)
}

function getOrderType(orderObjective) {
  let orderItem = getOrderItem(orderObjective)
  if (orderItem == null)
    return orderTypes.UNKNOWN
  return orderItem.orderType
}


function getPlayerDataById(playerId) {
  if (!ordersEnabled) {
    debugPrint("orders: getPlayerDataById: Calling when orders are disabled.")
    debug_dump_stack()
  }
  let playerData = playerDataById?[playerId] ?? get_mplayer_by_id(playerId) ?? emptyPlayerData
  if (is_replay_playing()) {
    playerData.isLocal = spectatorWatchedHero.id == playerData.id
    playerData.isInHeroSquad = isEqualSquadId(spectatorWatchedHero.squadId, playerData?.squadId)
  }
  if (!(playerId in playerDataById))
    playerDataById[playerId] <- playerData
  return playerData
}

function getPlayerDataByScoreData(scoreData) {
  if (scoreData.playerId != -1)
    return getPlayerDataById(scoreData.playerId)
  return getTblValue("playerData", scoreData, emptyPlayerData)
}

function getLocalPlayerData() {
  if (is_replay_playing())
    localPlayerData = getPlayerDataById(spectatorWatchedHero.id)
  if (localPlayerData == null)
    localPlayerData = get_local_mplayer()
  return localPlayerData
}



function addLocalPlayerScoreData(scores) {
  let checkFunc = is_replay_playing()
    ? @(p) p.id == spectatorWatchedHero.id
    : @(p) p.userId == userIdStr.get()

  local foundThisPlayer = false
  foreach (scoreData in scores)
    if (checkFunc(getPlayerDataByScoreData(scoreData))) {
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

function prepareStatusScores(statusScores, orderObject) {
  statusScores.sort(orderObject.orderType.sortPlayerScores)

  
  for (local i = statusScores.len() - 1; i >= 0; --i) {
    let playerData = getPlayerDataByScoreData(statusScores[i])
    if (playerData == null)
      statusScores.remove(i)
  }

  
  local localPlayerIndex = -1
  foreach (idx, score in statusScores) {
    score.playerIndex <- idx
    if (localPlayerIndex >= 0)
      continue

    let playerData = getPlayerDataByScoreData(score)
    if (getTblValue("userId", playerData) == userIdStr.get())
      localPlayerIndex = idx
  }

  if (localPlayerIndex == -1)
    return

  
  
  while (localPlayerIndex >= MAX_ROWS_IN_SCORE_TABLE) {
    statusScores.remove(MAX_ROWS_IN_SCORE_TABLE - 1)
    --localPlayerIndex
  }
}



function getOrderScores(orderObject) {
  local scores = orderObject?.orderObjective.score
  if (scores != null) {
    scores = clone scores
    foreach (player in debugPlayers)
      scores.append(player.scoreData)
    addLocalPlayerScoreData(scores)
  }

  let winnerScoreData = getTblValue(orderObject.orderId, winnerScoreDataByOrderId, null)
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

function getScoreTableTexts() {
  let showOrder = isOrderInfoVisible()
  if (!showOrder)
    return []

  let orderObject = hasActiveOrder.value ? activeOrder : prevActiveOrder.value
  let scoreData = getOrderScores(orderObject)
  if (!scoreData)
    return []

  prepareStatusScores(scoreData, orderObject)
  return scoreData.map(function(item) {
    let playerData = getPlayerDataByScoreData(item)
    return {
      score = orderObject.orderType.formatScore(item.score)
      player =  ". ".concat((getTblValue("playerIndex", item, 0) + 1), buildMplayerName(playerData))
    }
  })
}



function getWarningText(selectedOrderItem = null) {
  if (hasActiveOrder.value)
    return loc("items/order/activateOrderWarning/hasActiveOrder")
  if (!hasOrdersToActivate())
    return loc("items/order/noOrdersAvailable")

  let timeleft = getCooldownTimeleft()
  if (timeleft > 0) {
    let locParams = { cooldownTimeleftText = time.secondsToString(timeleft) }
    return loc("items/order/activateOrderWarning/cooldown", locParams)
  }

  if (!checkCurrentMission(selectedOrderItem))
    return orderUseResult.RESTRICTED_MISSION.createResultMessage(false)

  return ""
}

function updateActiveOrder(dispatchEvents = true, isForced = false) {
  local activeOrderChanged = false
  local orderStatusChanged = false

  
  let orderObjective = getActiveOrderObjective()

  
  
  
  let starterId = getTblValue("starterId", orderObjective, -1)
  if (starterId == -1 && orderObjective != null && !isForced)
    return

  if (activeOrder.orderId != getOrderId(orderObjective))
    activeOrderChanged = true
  else if (activeOrder.orderStatus != getOrderStatus(orderObjective))
    orderStatusChanged = true

  
  let oldActiveOrder = clone activeOrder
  activeOrder.orderId = getOrderId(orderObjective)
  activeOrder.orderObjective = orderObjective
  activeOrder.orderType = getOrderType(orderObjective)
  activeOrder.orderStatus = getOrderStatus(orderObjective)
  activeOrder.orderItem = getOrderItem(orderObjective)
  activeOrder.timeToSwitchTarget = getTblValue("timeToSwitchTarget", orderObjective, -1)

  let objectiveStarterId = getTblValue("starterId", orderObjective, -1)
  let orderStartId = getTblValue("id", activeOrder.starterPlayer, -1)
  
  if (orderStartId != objectiveStarterId || activeOrder.starterPlayer == null)
    activeOrder.starterPlayer = getPlayerDataById(objectiveStarterId)

  let objectiveTargetId = getTblValue("targetId", orderObjective, -1)
  let orderTargetId = getTblValue("id", activeOrder.targetPlayer, -1)
  
  if (orderTargetId != objectiveTargetId || activeOrder.targetPlayer == null)
    activeOrder.targetPlayer = getPlayerDataById(objectiveTargetId)

  hasActiveOrder.value = orderObjective != null

  
  updateActiveLocalOrders()

  
  if (activeOrder.orderObjective == null
      && oldActiveOrder.orderStatus == objectiveStatus.RUNNING
      && activeOrder.orderStatus != objectiveStatus.RUNNING
      && oldActiveOrder.orderId != -1) {
    prevActiveOrder.value = oldActiveOrder
  }
  else if (activeOrderChanged && activeOrder.orderStatus == objectiveStatus.RUNNING)
    prevActiveOrder.value = null

  
  
  if (!hasActiveOrder.value)
    updateCooldownTimeleft()

  updateHideOrderBlock()

  
  
  if ((activeOrderChanged || orderStatusChanged) && hasActiveOrder.value)
    updateStatusTextView(activeOrder, true)
  if (cooldownTimeleft.value > 0 && prevActiveOrder.value != null)
    updateStatusTextView(prevActiveOrder.value, true)

  if (dispatchEvents) {
    if (activeOrderChanged)
      broadcastEvent("ActiveOrderChanged", { oldActiveOrder = oldActiveOrder })
    else if (orderStatusChanged)
      broadcastEvent("OrderStatusChanged", { oldActiveOrder = oldActiveOrder })
    broadcastEvent("OrderUpdated", { oldActiveOrder = oldActiveOrder })
  }

  local visibleScoreTableTexts = getScoreTableTexts()
  visibleScoreTableTexts = visibleScoreTableTexts.len() > MAX_ROWS_IN_SCORE_TABLE
    ? visibleScoreTableTexts.resize(MAX_ROWS_IN_SCORE_TABLE, null)
    : visibleScoreTableTexts

  eventbus_send("orderStateUpdate", {
    statusText = getStatusText()
    statusTextBottom = getStatusTextBottom()
    showOrder = hasActiveOrder.value || (cooldownTimeleft.value > 0 && prevActiveOrder.value != null)
    scoresTable = visibleScoreTableTexts
  })
}

let onOrderTimerUpdate = @(_obj, _dt) updateActiveOrder()

function onChangeOrderVisibility(_obj, _dt) {
  isOrdersHidden = !isOrdersHidden
  updateHideOrderBlock()
  updateOrderVisibility()
}




function updateOrderStatusObject(statusObj, fullUpdate) {
  if (!checkObj(statusObj))
    return

  let orderObject = hasActiveOrder.value
    ? activeOrder
    : prevActiveOrder.value

  if (fullUpdate) {
    let statusContent = getStatusContent(orderObject, (statusObj?.isHalignRight ?? "no") == "yes")
    let guiScene = statusObj.getScene()
    guiScene.replaceContentFromText(statusObj, statusContent, statusContent.len(), { onChangeOrderVisibility })

    
    let orderTimerObj = statusObj.findObject("order_timer")
    if (checkObj(orderTimerObj))
      orderTimerObj.setUserData({ onOrderTimerUpdate })
  }

  let waitingForCooldown = cooldownTimeleft.value > 0 && prevActiveOrder.value != null
  let showStatus = hasActiveOrder.value || waitingForCooldown
  setStatusObjVisibility(statusObj, showStatus)
  if (!showStatus)
    return

  
  let statusTextObj = statusObj.findObject("status_text")
  if (checkObj(statusTextObj))
    statusTextObj.setValue(getStatusText())

  
  let statusTextBottomObj = statusObj.findObject("status_text_bottom")
  if (checkObj(statusTextBottomObj))
    statusTextBottomObj.setValue(getStatusTextBottom())

  
  let tableTexts = getScoreTableTexts()
  let showTable = tableTexts != null && tableTexts.len()
  let statusTableObj = statusObj.findObject("status_table")
  let numScores = min(tableTexts ? tableTexts.len() : 0, MAX_ROWS_IN_SCORE_TABLE)
  if (checkObj(statusTableObj))
    statusTableObj.show(showTable)
  if (showTable) {
    for (local i = 0; i < numScores; ++i) {
      let rowObj = getRowObjByIndex(i, statusObj)
      assert(rowObj != null, "Error updating order status: Row object not found.")
      setRowObjTexts(rowObj, tableTexts[i].player, tableTexts[i].score, true)
    }
  }

  
  for (local i = numScores; i < MAX_ROWS_IN_SCORE_TABLE; ++i) {
    let rowObj = getRowObjByIndex(i, statusObj)
    assert(rowObj != null, "Error updating order status: Row object not found.")
    setRowObjTexts(rowObj, "", "", false)
  }
}


function orderCanBeActivated() {
  if (!ordersCanBeUsed() || !hasOrdersToActivate())
    return false
  updateActiveOrder()
  return !hasActiveOrder.value
}

function openOrdersInventory() {
  if (!orderCanBeActivated())
    return showInfoMsgBox(getWarningText(), "orders_cant_be_activated")

  loadHandler(gui_handlers.OrderActivationWindow, { curTab = itemsTab.INVENTORY })
}

function saveOrderStatusPositionAndSize() {
  if (!checkObj(ordersStatusObj))
    return

  let frameObj = ordersStatusObj.findObject("order_status_frame")
  if (!checkObj(frameObj)) 
    return

  let frameSize = frameObj.getSize()

  
  
  if (frameSize[0] == -1)
    return

  orderStatusPosition.value = frameObj.getPosRC()
  let statusObjPosition = ordersStatusObj.getPosRC()

  
  orderStatusPosition.value[0] -= statusObjPosition[0]
  orderStatusPosition.value[1] -= statusObjPosition[1]
}

function updateOrderStatus(fullUpdate) {
  saveOrderStatusPositionAndSize()
  updateOrderStatusObject(ordersStatusObj, fullUpdate)
}

function disableOrders() {
  if (!ordersEnabled) {
    debugPrint("orders: disableOrders:Skipped. Already disabled.")
    debug_dump_stack()
    return
  }
  ordersEnabled = false
  removeAllListenersByEnv(eventToHandlerMap)
  ordersStatusObj = null
  listenersEnabled = false
  updateActiveOrder()
  timesUsedByOrderItemId.clear()
  playerDataById.clear()
  activeLocalOrderIds.clear()
  winnerScoreDataByOrderId.clear()
  activatingLocalOrderId = null
  activatingLocalOrderCallback = null
  set_order_accepted_cb(null, null)
  orderStatusPosition.value = null
  localPlayerData = null
}

function onEventLobbyStatusChange(_params) {
  if (!isInSessionRoom.get())
    disableOrders()
}

function onEventOrderUpdated(_params) {
  updateOrderStatus(false)
  updateHideOrderBlock()
}

let onEventWatchedHeroSwitched = @(_params) updateActiveOrder(true, true)
let onEventChangedCursorVisibility = @(_params) updateHideOrderBlock()

function onEventActiveOrderChanged(params) {
  collectOrdersToActivate()
  updateOrderStatus(true)

  local text = ""
  if (hasActiveOrder.value) {
    text = loc("items/order/hudMessage/activate", {
      playerName = buildMplayerName(activeOrder.starterPlayer)
      orderName = activeOrder.orderItem.getName(false)
    })
    isOrdersHidden = false
  }
  else {
    text = loc("items/order/hudMessage/finished", {
      orderName = params.oldActiveOrder.orderItem.getName(false)
    })
  }

  g_hud_event_manager.onHudEvent("HudMessage", {
    id = -1
    type = HUD_MSG_OBJECTIVE
    text
  })
}

eventToHandlerMap.__update({
  onEventLobbyStatusChange
  onEventOrderUpdated
  onEventOrderVisibility = onChangeOrderVisibility
  onEventWatchedHeroSwitched
  onEventChangedCursorVisibility
  onEventActiveOrderChanged
})

function enableOrders(statusObj) {
  if (!ordersCanBeUsed())
    return

  ordersEnabled = true
  ordersStatusObj = statusObj

  updateActiveOrder(false)
  updateOrderStatus(true)

  if (listenersEnabled || !checkObj(statusObj))
    return
  listenersEnabled = true

  subscribe_handler(eventToHandlerMap, DEFAULT_HANDLER)
}

function enableOrdersWithoutDagui() {
  if (!ordersCanBeUsed())
    return

  ordersEnabled = true

  if (listenersEnabled)
    return
  listenersEnabled = true

  subscribe_handler(eventToHandlerMap, DEFAULT_HANDLER)
}

::cross_call_api.active_order_request_update <- @() updateActiveOrder()
::cross_call_api.active_order_enable <- @() enableOrdersWithoutDagui()



function on_order_result_received(data) {
  let { player, param } = data
  
  
  
  let actualOrderId = activeOrder.orderId
  winnerScoreDataByOrderId[actualOrderId] <- {
    playerId = player
    score = param
  }
}

eventbus_subscribe("on_order_result_received", @(p) on_order_result_received(p))

return {
  collectOrdersToActivate
  getActivateButtonLabel
  getWarningText
  checkCurrentMission
  showOrdersContainer
  activateSoonExpiredOrder
  showActivateOrderButton
  orderCanBeActivated
  openOrdersInventory
  updateActiveOrder
  enableOrders
  disableOrders
  getOrderAutoActivateHint
  getOrderActivateInfoText
  getTimesUsedOrderItem
  isOrderItemActive
  activateOrder
}
