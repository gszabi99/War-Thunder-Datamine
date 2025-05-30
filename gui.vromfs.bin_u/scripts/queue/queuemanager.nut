from "%scripts/dagui_natives.nut" import set_presence_to_player
from "%scripts/dagui_library.nut" import *
from "%scripts/queue/queueConsts.nut" import queueStates
from "%scripts/queue/queueType.nut" import g_queue_type

let { getGlobalModule } = require("%scripts/global_modules.nut")
let events = getGlobalModule("events")
let g_listener_priority = require("%scripts/g_listener_priority.nut")
let { isTable } = require("%sqStdLibs/helpers/u.nut")
let { SERVER_ERROR_REQUEST_REJECTED } = require("matching.errors")
let { addListenersWithoutEnv, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let clustersModule = require("%scripts/clusterSelect.nut")
let lobbyStates = require("%scripts/matchingRooms/lobbyStates.nut")
let { getSelSlotsData } = require("%scripts/slotbar/slotbarState.nut")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { get_time_msec } = require("dagor.time")
let { rnd } = require("dagor.random")
let { checkMatchingError, matchingErrorString, matchingRpcSubscribe } = require("%scripts/matching/api.nut")
let { sendBqEvent } = require("%scripts/bqQueue/bqQueue.nut")
let { isInSessionRoom, isWaitForQueueRoom, sessionLobbyStatus } = require("%scripts/matchingRooms/sessionLobbyState.nut")
let QueueStats = require("%scripts/queue/queueStats.nut")
let { addDelayedAction } = require("%scripts/utils/delayedActions.nut")
let { setWaitForQueueRoom } = require("%scripts/matchingRooms/sessionLobbyManager.nut")
let { myClanInfo } = require("%scripts/clans/clanState.nut")
let { updateGamercards } = require("%scripts/gamercard/gamercard.nut")

let { isQueueActive, findQueue, findQueueByName, isAnyQueuesActive, getActiveQueueTypes,
  addQueueToList, getQueuesList, removeQueueFromList, clearAllQueues, applyQueueInfo,
  pushQueueInfoUpdatedEvent, findAllQueues
} = require("%scripts/queue/queueState.nut")
let { getQueueEvent, isClanQueue, getQueueMode, getQueueCountry, getMyRankInQueue
} = require("%scripts/queue/queueInfo.nut")
let { canJoinFlightMsgBox } = require("%scripts/squads/squadUtils.nut")

let lastQueueId = mkWatched(persist, "lastQueueId", -1)
local lastQueueReqParams = null
local progressBox        = null
local isLeaveDelayed     = false

let hiddenMatchingError = {
  SERVER_ERROR_NOT_IN_QUEUE = true
}

function changeState(queue, queueState) {
  if (queue.state == queueState)
    return

  let wasAnyActive = isAnyQueuesActive()

  queue.state = queueState
  queue.activateTime = isQueueActive(queue) ? get_time_msec() : -1
  broadcastEvent("QueueChangeState", { queue = queue })

  if (wasAnyActive != isAnyQueuesActive)
    updateGamercards()
}

function removeQueue(queue) {
  changeState(queue, queueStates.NOT_IN_QUEUE)
  return removeQueueFromList(queue)
}

function afterLeaveQueue(queue, msg = null) {
  removeQueue(queue)
  if (msg && !checkObj(get_gui_scene()["leave_queue_msgbox"]))
    showInfoMsgBox(msg, "leave_queue_msgbox")
}


function notifyQueueLeave(params) {
  let list = findAllQueues(params)
  foreach (q in list)
    if (q.removeQueueByParams(params)) {
      if (!q.isActive())
        removeQueue(q)
      else
        broadcastEvent("QueueChanged", q)
    }
}

function showProgressBox(show, text = "charServer/purchase0") {
  if (checkObj(progressBox)) {
    progressBox.getScene().destroyElement(progressBox)
    broadcastEvent("ModalWndDestroy")
    progressBox = null
  }
  if (show)
    progressBox = scene_msg_box("queue_action", null, loc(text),
      [["cancel", function() {}]], "cancel",
      { waitAnim = true,
        delayedButtons = 30
      })
}

function createQueue(params, needModifyParamsByType = false) {
  let queueType = g_queue_type.getQueueTypeByParams(params)

  if (needModifyParamsByType)
    params = queueType.prepareQueueParams(params)

  local queue = findQueue(params)
  if (queue) {
    queue.addQueueByParams(params)
    return queue
  }

  let lastId = lastQueueId.get() + 1
  lastQueueId.set(lastId)
  queue = queueType.createQueue(lastId, params)
  addQueueToList(queue)
  return queue
}

function afterJoinQueue(queue) {
  changeState(queue, queueStates.IN_QUEUE)
  set_presence_to_player("queue")
}

function getOnLeaveQueueErrorCallback(queue) {
  return function(response) {
    showProgressBox(false)
    if (response.error == SERVER_ERROR_REQUEST_REJECTED) {
      
      setWaitForQueueRoom(true)
      return
    }

    if ((response?.error_id ?? matchingErrorString(response.error)) not in hiddenMatchingError)
      checkMatchingError(response)
    removeQueue(queue)
  }
}

function getOnLeaveQueueSuccessCallback(_queue) {
  return @(_response) showProgressBox(false)
}

function getOnLeaveAllQueuesErrorCallback(postAction, postCancelAction, silent) {
  return function(response) {
    showProgressBox(false)
    if (response.error == SERVER_ERROR_REQUEST_REJECTED) {
      
      if (postCancelAction)
        postCancelAction()
      setWaitForQueueRoom(true)
    }
    else {
      if ((response?.error_id ?? matchingErrorString(response.error)) not in hiddenMatchingError)
        checkMatchingError(response, !silent)
      notifyQueueLeave({})

      
      
      
      if (!isWaitForQueueRoom.get() && !isInSessionRoom.get()) {
        if (postAction)
          postAction()
      }
      else {
        if (postCancelAction)
          postCancelAction()
      }
    }
  }
}

function leaveQueue(queue, params = {}) {
  if (queue.state == queueStates.LEAVING_QUEUE)
    return
  if (queue.state == queueStates.NOT_IN_QUEUE || queue.state == queueStates.ACTUALIZE)
    return removeQueue(queue)
  if (queue.state == queueStates.JOINING_QUEUE) {
    isLeaveDelayed = true
    showProgressBox(true, "wait/queueLeave")
    return
  }

  lastQueueReqParams = null
  showProgressBox(true, "wait/queueLeave")

  sendBqEvent("CLIENT_GAMEPLAY_1", "exit_waiting_for_battle_screen", {
    waitingTime = queue.getActiveTime()
    queueType = queue.queueType.typeName
    eventId = getQueueMode(queue)
    country = getQueueCountry(queue)
    rank = getMyRankInQueue(queue)
    isCanceledByPlayer = params?.isCanceledByPlayer ?? false
  })

  queue.leave(
    getOnLeaveQueueSuccessCallback(queue),
    getOnLeaveQueueErrorCallback(queue)
  )

  changeState(queue, queueStates.LEAVING_QUEUE)
}

function leaveAllQueues(params = null, postAction = null, postCancelAction = null, silent = false) { 
  if (params) {
    let list = findAllQueues(params)
    foreach (q in list)
      leaveQueue(q)
    return
  }

  if (!isAnyQueuesActive())
    return postAction && postAction()

  showProgressBox(true, "wait/queueLeave")

  let callback = getOnLeaveAllQueuesErrorCallback(postAction, postCancelAction, silent)
  foreach (queueType in getActiveQueueTypes())
    queueType.leaveAllQueues(callback, callback, false)

  foreach (q in getQueuesList())
    if (q.state != queueStates.NOT_IN_QUEUE)
      changeState(q, queueStates.LEAVING_QUEUE)
}

function leaveAllQueuesSilent() {
  return leaveAllQueues(null, null, null, true)
}

function leaveAllQueuesAndDo(action, cancelAction = null) {
  leaveAllQueues(null, action, cancelAction)
}

function leaveQueueByType(typeBit = -1) {
  if (typeBit < 0)
    return leaveAllQueues()

  foreach (queue in getQueuesList())
    if ((typeBit & queue.typeBit) && isQueueActive(queue))
      leaveQueue(queue)
}

function joinQueueImpl(queue) {
  queue.join(
    function(_response) {
      afterJoinQueue(queue)
      if (isLeaveDelayed || (findQueueByName(queue.name) == null))
        leaveQueue(queue)
    },
    function(_response) {
      removeQueue(queue)
      if (isLeaveDelayed)
        showProgressBox(false)
    }
  )
  changeState(queue, queueStates.JOINING_QUEUE)
}

function joinQueue(params) {
  if (params == null)
    return log("Error: cancel join queue because params = null.")
  if (findQueue(params))
    return log("Error: cancel join queue because already exist.")

  isLeaveDelayed = false
  lastQueueReqParams = clone params
  broadcastEvent("BeforeJoinQueue")
  let queue = createQueue(params, true)
  if (queue.hasActualQueueData()) {
    joinQueueImpl(queue)
    return
  }

  changeState(queue, queueStates.ACTUALIZE)
  queue.actualizeData()
}

function joinFriendsQueue(inGameEx, eventId) {
  joinQueue({
    mode = eventId
    country = profileCountrySq.value
    slots = getSelSlotsData().slots
    clusters = clustersModule.getCurrentClusters()
    queueSelfActivated = true
    team = inGameEx.team.tointeger()
    roomId = inGameEx.roomId.tointeger()
    gameQueueId = inGameEx.gameQueueId
  })
}

function isCanGoForward(...) {
  return true
}

function isCanNewflight(...) {
  return !isAnyQueuesActive()
}

function isCanModifyCrew(...) {
  return !isAnyQueuesActive()
}

function isCanAirChange(...) {
  if (!isCanGoForward())
    return false

  foreach (q in getQueuesList())
    if (isQueueActive(q)) {
      let event = getQueueEvent(q)
      if (event && !events.isEventMultiSlotEnabled(event))
        return false
    }
  return true
}

function isCanModifyQueueParams(typeMask) {
  return findQueue({}, typeMask) == null
}

function isCanChangeCluster(...) {
  return !isAnyQueuesActive()
}

function isCanUseOnlineShop(...) {
  return !isAnyQueuesActive()
}

let checkAndStartFunctions = {
  isCanGoForward
  isCanNewflight
  isCanModifyCrew
  isCanAirChange
  isCanModifyQueueParams
  isCanChangeCluster
  isCanUseOnlineShop
}

function checkQueueAndStart(onSuccess, onCancel, checkName, checkParams = null) {
  if (!(checkName in checkAndStartFunctions) || checkAndStartFunctions[checkName](checkParams)) {
    if (onSuccess)
      onSuccess()
    return
  }

  if (!canJoinFlightMsgBox({
        isLeaderCanJoin = true,
        msgId = "squad/only_leader_can_cancel"
      }, onSuccess, onCancel))
    return

  if (checkParams?.isSilentLeaveQueue) {
    leaveAllQueuesAndDo(onSuccess, onCancel)
    return
  }

  scene_msg_box("requeue_question", null, loc("msg/cancel_queue_question"),
    [["ok", @() leaveAllQueuesAndDo(onSuccess, onCancel)], ["no", onCancel]],
    "ok",
    { cancel_fn = onCancel ?? @()null, checkDuplicateId = true })
}

function onQueueJoin(params) {
  let queue = createQueue(params)
  afterJoinQueue(queue)
}

addListenersWithoutEnv({
  MatchingDisconnect = @(_) notifyQueueLeave({})
  MatchingConnect = @(_) notifyQueueLeave({})

  function LobbyStatusChange(_p) {
    if (sessionLobbyStatus.get() == lobbyStates.IN_SESSION)
      lastQueueReqParams = null
  }

  function ClanInfoUpdate(_params) {
    if (!myClanInfo.get())
      foreach (queue in getQueuesList())
        if (isClanQueue(queue))
          leaveQueue(queue)
  }

  function QueueInfoRecived(params) {
    let queueInfo = params?.queue_info
    if (!isTable(queueInfo))
      return

    if (applyQueueInfo(queueInfo, QueueStats))
      pushQueueInfoUpdatedEvent()
  }
}, g_listener_priority.DEFAULT_HANDLER)

matchingRpcSubscribe("match.notify_queue_join", onQueueJoin)
matchingRpcSubscribe("match.notify_queue_leave", notifyQueueLeave)
matchingRpcSubscribe("mkeeper.notify_service_started", function(params) {
  if (params?.service != "match" || lastQueueReqParams == null)
    return

  lastQueueId.set(-1)
  clearAllQueues()
  addDelayedAction(@() joinQueue(lastQueueReqParams), 5000 + rnd() % 5000)
})

return {
  afterLeaveQueue
  notifyQueueLeave
  createQueue
  afterJoinQueue
  leaveQueue
  leaveAllQueues
  leaveAllQueuesSilent
  leaveQueueByType
  joinQueueImpl
  joinQueue
  joinFriendsQueue
  checkQueueAndStart
  isCanModifyCrew
}
