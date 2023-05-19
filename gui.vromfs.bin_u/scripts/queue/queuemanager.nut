from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")

//checked for explicitness
#no-root-fallback
#explicit-this

let { g_script_reloader } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")
let { subscribe_handler, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let clustersModule = require("%scripts/clusterSelect.nut")
let QUEUE_TYPE_BIT = require("%scripts/queue/queueTypeBit.nut")
let lobbyStates = require("%scripts/matchingRooms/lobbyStates.nut")
let { getSelSlotsData } = require("%scripts/slotbar/slotbarState.nut")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { get_time_msec } = require("dagor.time")
let { rnd } = require("dagor.random")
let { matchingRpcSubscribe } = require("%scripts/matching/api.nut")

global enum queueStates {
  ERROR,
  NOT_IN_QUEUE,
  ACTUALIZE,
  JOINING_QUEUE,
  LEAVING_QUEUE,
  IN_QUEUE
}

let hiddenMatchingError = {
  SERVER_ERROR_NOT_IN_QUEUE = true
}

::queue_classes <- {}

foreach (fn in [
                 "queueType.nut"
                 "queue/queueBase.nut"
                 "queue/queueEvent.nut"
                 "queue/queueWwBattle.nut" //FIX ME: must be in WW folder also with ww queue type
                 "statsSummator.nut"
                 "queueStatsBase.nut"
                 "queueStatsVer1.nut"
                 "queueStatsVer2.nut"
                 "queueInfo/qiHandlerBase.nut"
                 "queueInfo/qiHandlerByTeams.nut"
                 "queueInfo/qiHandlerByCountries.nut"
                 "queueInfo/qiViewUtils.nut"
                 "queueTable.nut"
               ])
  g_script_reloader.loadOnce($"%scripts/queue/{fn}") // no need to includeOnce to correct reload this scripts pack runtime

matchingRpcSubscribe("mkeeper.notify_service_started", function(params) {
  if (params?.service != "match" || ::queues.lastQueueReqParams == null)
    return

  ::queues.init()
  ::g_delayed_actions.add(
    Callback(@()::queues.joinQueue(::queues.lastQueueReqParams), ::queues),
    5000 + rnd() % 5000)
})

::queues <- null //init in second mainmenu

::QueueManager <- class {
  state              = queueStates.NOT_IN_QUEUE

  progressBox        = null
  queuesList         = null
  lastId             = -1
  lastQueueReqParams = null
  isLeaveDelayed     = false

  delayedInfoUpdateEventtTime = -1

  queue_diff_params = ["mode", "team"]

  constructor() {
    this.init()
    g_script_reloader.registerPersistentData("QueueManager", this, ["queuesList", "lastId", "state"])
    subscribe_handler(this, ::g_listener_priority.DEFAULT_HANDLER)
  }

  function init() {
    this.queuesList = []
    this.lastId     = -1
  }

  function createQueue(params, needModifyParamsByType = false) {
    let queueType = ::g_queue_type.getQueueTypeByParams(params)

    if (needModifyParamsByType)
      params = queueType.prepareQueueParams(params)

    local queue = this.findQueue(params)
    if (queue) {
      if (queue.addQueueByParams(params))
        broadcastEvent("QueueClustersChanged", queue)
      return queue
    }

    queue = queueType.createQueue(this.lastId++, params)
    this.queuesList.append(queue)

    return queue
  }

  function removeQueue(queue) {
    this.changeState(queue, queueStates.NOT_IN_QUEUE)
    foreach (idx, q in this.queuesList)
      if (q.id == queue.id)
        return this.queuesList.remove(idx)
  }

  function isEqual(params1, params2, null_is_equal = true) {
    foreach (p in this.queue_diff_params)
      if ((p in params1) != (p in params2)) {
        if (!null_is_equal)
          return false
      }
      else if ((p in params1) && params1[p] != params2[p])
        return false
    return true
  }

  function findQueue(params, typeMask = -1, checkActive = true) {
    foreach (q in this.queuesList)
      if ((typeMask < 0 || (typeMask & q.typeBit)) && (!checkActive || this.isQueueActive(q)))
          if (this.isEqual(params, q.params))
            return q
    return null
  }

  function isQueuesEqual(q1, q2) {
    if (!q1 || !q2)
      return !q1 == !q2
    return q1.id == q2.id
  }

  function findAllQueues(params, typeMask = -1) {
    let res = []
    foreach (q in this.queuesList)
      if (typeMask < 0 || (typeMask & q.typeBit))
        if (this.isEqual(params, q.params))
          res.append(q)
    return res
  }

  function findQueueByName(name, isActive = false) {
    foreach (queue in this.queuesList)
      if (queue.name == name && (!isActive || this.isQueueActive(queue)))
        return queue
    return null
  }

  function findQueueByQueueUid(queueUid) {
    foreach (queue in this.queuesList)
      if (queueUid in queue.queueUidsList)
        return queue
    return null
  }

  function getActiveQueueTypes() {
    let res = []
    foreach (queue in this.queuesList)
      if (this.isQueueActive(queue))
         u.appendOnce(queue.queueType, res)

    return res
  }

  function getActiveQueueWithType(typeBit) {
    foreach (queue in this.queuesList)
      if ((typeBit & queue.typeBit) && this.isQueueActive(queue))
        return queue

    return null
  }

  function hasActiveQueueWithType(typeBit) {
    return this.getActiveQueueWithType(typeBit) != null
  }

  function isQueueActive(queue) {
    return queue != null && (queue.state == queueStates.IN_QUEUE
      || queue.state == queueStates.ACTUALIZE
      || queue.state == queueStates.JOINING_QUEUE)
  }

  function isAnyQueuesActive(typeMask = -1) {
    foreach (q in this.queuesList)
      if (typeMask < 0 || (typeMask & q.typeBit))
        if (this.isQueueActive(q))
          return true
    return false
  }

  function getActiveQueueByName(_id) {
    foreach (q in this.queuesList)
      if (this.isQueueActive(q))
        return true
    return false
  }

  function leaveQueueByType(typeBit = -1) {
    if (typeBit < 0)
      return this.leaveAllQueues()

    foreach (queue in this.queuesList)
      if ((typeBit & queue.typeBit) && this.isQueueActive(queue))
        this.leaveQueue(queue)
  }

  function changeState(queue, queueState) {
    if (queue.state == queueState)
      return

    let wasAnyActive = this.isAnyQueuesActive()

    queue.state = queueState
    queue.activateTime = this.isQueueActive(queue) ? get_time_msec() : -1
    broadcastEvent("QueueChangeState", { queue = queue })

    if (wasAnyActive != this.isAnyQueuesActive)
      ::update_gamercards()
  }

  function getQueueType(queue) {
    return queue.typeBit
  }

  function cantSquadQueueMsgBox(params = null, reasonText = "") {
    log($"Error: cant join queue with squad. {reasonText}")
    if (params)
      debugTableData(params)

    local msg = loc("squad/cant_join_queue")
    if (reasonText)
      msg = $"{msg}\n{reasonText}"
    ::showInfoMsgBox(msg, "cant_join_queue")
  }

  function showProgressBox(show, text = "charServer/purchase0") {
    if (checkObj(this.progressBox)) {
      this.progressBox.getScene().destroyElement(this.progressBox)
      broadcastEvent("ModalWndDestroy")
      this.progressBox = null
    }
    if (show)
      this.progressBox = ::scene_msg_box("queue_action", null, loc(text),
        [["cancel", function() {}]], "cancel",
        { waitAnim = true,
          delayedButtons = 30
        })
  }

  function joinFriendsQueue(inGameEx, eventId) {
    this.joinQueue({
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

  function joinQueueImpl(queue) {
    queue.join(
      Callback(function(_response) {
        this.afterJoinQueue(queue)
        if (this.isLeaveDelayed || (this.findQueueByName(queue.name) == null))
          this.leaveQueue(queue)
      }, this),
      Callback(function(_response) {
        this.removeQueue(queue)
        if (this.isLeaveDelayed)
          this.showProgressBox(false)
      }, this)
    )
    this.changeState(queue, queueStates.JOINING_QUEUE)
  }

  function joinQueue(params) {
    if (params == null)
      return log("Error: cancel join queue because params = null.")
    if (this.findQueue(params))
      return log("Error: cancel join queue because already exist.")

    this.isLeaveDelayed = false
    this.lastQueueReqParams = clone params
    broadcastEvent("BeforeJoinQueue")
    let queue = this.createQueue(params, true)
    if (queue.hasActualQueueData()) {
      this.joinQueueImpl(queue)
      return
    }

    this.changeState(queue, queueStates.ACTUALIZE)
    queue.actualizeData()
  }

  function afterJoinQueue(queue) {
    this.changeState(queue, queueStates.IN_QUEUE)
    ::set_presence_to_player("queue")
  }

  function leaveAllQueues(params = null, postAction = null, postCancelAction = null, silent = false) { //null = all
    if (params) {
      let list = this.findAllQueues(params)
      foreach (q in list)
        this.leaveQueue(q)
      return
    }

    if (!this.isAnyQueuesActive())
      return postAction && postAction()

    this.showProgressBox(true, "wait/queueLeave")

    let callback = this._getOnLeaveQueueErrorCallback(postAction, postCancelAction, silent)
    foreach (queueType in this.getActiveQueueTypes())
      queueType.leaveAllQueues(callback, callback, false)

    foreach (q in this.queuesList)
      if (q.state != queueStates.NOT_IN_QUEUE)
        this.changeState(q, queueStates.LEAVING_QUEUE)
  }

  function _getOnLeaveQueueErrorCallback(postAction, postCancelAction, silent) {
    return Callback(function(response) {
      this.showProgressBox(false)
      if (response.error == SERVER_ERROR_REQUEST_REJECTED) {
        // Error means that user is joining battle and can't leave the queue
        if (postCancelAction)
          postCancelAction()
        ::SessionLobby.setWaitForQueueRoom(true)
      }
      else {
        if ((response?.error_id ?? ::matching.error_string(response.error)) not in hiddenMatchingError)
          ::checkMatchingError(response, !silent)
        this.afterLeaveQueues({})

        // This check is a workaround that fixes
        // player being able to perform some action
         // split second before battle begins.
         if (!::SessionLobby.isWaitForQueueRoom()
           && !::SessionLobby.isInRoom()) {
            if (postAction)
              postAction()
         }
         else {
           if (postCancelAction)
             postCancelAction()
         }
      }
    }, this)
  }

  function leaveAllQueuesSilent() {
    return this.leaveAllQueues(null, null, null, true)
  }

  function leaveQueue(queue, params = {}) {
    if (queue.state == queueStates.LEAVING_QUEUE)
      return
    if (queue.state == queueStates.NOT_IN_QUEUE || queue.state == queueStates.ACTUALIZE)
      return this.removeQueue(queue)
    if (queue.state == queueStates.JOINING_QUEUE) {
      this.isLeaveDelayed = true
      this.showProgressBox(true, "wait/queueLeave")
      return
    }

    this.lastQueueReqParams = null
    this.showProgressBox(true, "wait/queueLeave")

    ::add_big_query_record("exit_waiting_for_battle_screen",
      ::save_to_json({ waitingTime = queue.getActiveTime()
        queueType = queue.queueType.typeName
        eventId = this.getQueueMode(queue)
        country = this.getQueueCountry(queue)
        rank = this.getMyRankInQueue(queue)
        isCanceledByPlayer = params?.isCanceledByPlayer ?? false }))

    queue.leave(
      this.getOnLeaveQueueSuccessCallback(queue),
      this.getOnLeaveQueueErrorCallback(queue)
    )

    this.changeState(queue, queueStates.LEAVING_QUEUE)
  }

  function getOnLeaveQueueErrorCallback(queue) {
    return Callback(function(response) {
      this.showProgressBox(false)
      if (response.error == SERVER_ERROR_REQUEST_REJECTED) {
        // Error means that user is joining battle and can't leave the queue
        ::SessionLobby.setWaitForQueueRoom(true)
        return
      }

      if ((response?.error_id ?? ::matching.error_string(response.error)) not in hiddenMatchingError)
        ::checkMatchingError(response)
      this.removeQueue(queue)
    }, this)
  }

  function getOnLeaveQueueSuccessCallback(_queue) {
    return Callback(@(_response) this.showProgressBox(false), this)
  }

  function afterLeaveQueue(queue, msg = null) {
    this.removeQueue(queue)
    if (msg && !checkObj(::get_gui_scene()["leave_queue_msgbox"]))
      ::showInfoMsgBox(msg, "leave_queue_msgbox")
  }

  //handles all queus, matches with @params
  function afterLeaveQueues(params) {
    let list = this.findAllQueues(params)
    foreach (q in list)
      if (q.removeQueueByParams(params)) {
        if (!q.isActive())
          this.removeQueue(q)
        else
          broadcastEvent("QueueChanged", q)
      }
  }

  function leaveAllQueuesAndDo(action, cancelAction = null) {
    this.leaveAllQueues(null, action, cancelAction)
  }

  function isCanModifyQueueParams(typeMask) {
    return this.findQueue({}, typeMask) == null
  }

  function isCanNewflight(...) {
    return !this.isAnyQueuesActive()
  }

  function isCanChangeCluster(...) {
    return !this.isAnyQueuesActive()
  }

  function isCanUseOnlineShop(...) {
    return !this.isAnyQueuesActive()
  }

  function isCanGoForward(...) {
    return true
  }

  function isCanModifyCrew(...) {
    return !this.isAnyQueuesActive()
  }

  function isCanAirChange(...) {
    if (!this.isCanGoForward())
      return false

    foreach (q in this.queuesList)
      if (this.isQueueActive(q)) {
        let event = this.getQueueEvent(q)
        if (event && !::events.isEventMultiSlotEnabled(event))
          return false
      }
    return true
  }

  function isClanQueue(queue) {
    let event = ::events.getEvent(queue.name)
    if (event == null)
      return false
    return ::events.isEventForClan(event)
  }

  function getQueueEvent(queue) {
    return ::events.getEvent(queue.name)
  }

  function getQueueMode(queue) {
    return ("mode" in queue.params) ? queue.params.mode : ""
  }

  function getQueueTeam(queue) {
    return ("team" in queue.params) ? queue.params.team : Team.Any
  }

  function getQueueCountry(queue) {
    return ("country" in queue.params) ? queue.params.country : ""
  }

  function getQueueClusters(queue) {
    return "clusters" in queue.params ? queue.params.clusters : []
  }

  function getQueueSlots(queue) {
    return ("slots" in queue.params) ? queue.params.slots : null
  }

  function getQueueOperationId(queue) {
    return queue.params?.operationId ?? -1
  }

  function getMyRankInQueue(queue) {
    let event = this.getQueueEvent(queue)
    if (!event)
      return -1

    let country = this.getQueueCountry(queue)
    return ::events.getSlotbarRank(event,
                                   country,
                                   getTblValue(country, this.getQueueSlots(queue), 0)
                                  )
  }

  function getQueuesInfoText() {
    local text = loc("inQueueList/header")
    foreach (queue in this.queuesList)
      if (this.isQueueActive(queue))
        text = $"{text}\n{queue.getDescription()}"

    return text
  }

  function isEventQueue(queue) {
    if (!queue)
      return false
    return queue.typeBit == QUEUE_TYPE_BIT.EVENT
  }

  function isDominationQueue(queue) {
    if (!queue)
      return false
    return queue.typeBit == QUEUE_TYPE_BIT.DOMINATION
  }

  function checkQueueType(queue, typeMask) {
    return (getTblValue("typeBit", queue, 0) & typeMask) != 0
  }

  function getQueuePreferredViewClass(queue) {
    let defaultHandler = ::gui_handlers.QiHandlerByTeams
    let event = this.getQueueEvent(queue)
    if (!event)
      return defaultHandler
    if (!::events.isEventForClan(event) && ::events.isEventSymmetricTeams(event))
      return ::gui_handlers.QiHandlerByCountries
    return defaultHandler
  }

  function onEventClanInfoUpdate(_params) {
    if (!::my_clan_info)
      foreach (queue in this.queuesList)
        if (this.isClanQueue(queue))
          this.leaveQueue(queue)
  }

  function applyQueueInfo(info, statsClass) {
    let queue = ("queueId" in info) ? this.findQueueByQueueUid(info.queueId)
                  : ("name" in info)  ? this.findQueueByName(info.name)
                                      : null
    if (!queue)
      return false

    if (!queue.queueStats)
      queue.queueStats = statsClass(queue)

    return queue.queueStats.applyQueueInfo(info)
  }

  function onEventQueueInfoRecived(params) {
    local haveChanges = false
    let queueInfo = getTblValue("queue_info", params)

    if (u.isTable(queueInfo))
      haveChanges = this.applyQueueInfo(queueInfo, ::queue_stats_versions.StatsVer2)
    else if (u.isArray(queueInfo)) //queueInfo ver1
      foreach (qi in queueInfo)
        if (this.applyQueueInfo(qi, ::queue_stats_versions.StatsVer1))
          haveChanges = true

    if (haveChanges)
      this.pushQueueInfoUpdatedEvent()
  }

  function pushQueueInfoUpdatedEvent() {
    if (this.delayedInfoUpdateEventtTime > 0 && get_time_msec() - this.delayedInfoUpdateEventtTime < 1000)
      return

    let guiScene = ::get_gui_scene()
    if (!guiScene)
      return

    this.delayedInfoUpdateEventtTime = get_time_msec()
    guiScene.performDelayed(this, function() {
       this.delayedInfoUpdateEventtTime = -1
       if (this.isAnyQueuesActive())
        broadcastEvent("QueueInfoUpdated")
     })
  }

  function updateQueueInfoByType(queueType, successCb, errorCb = null, needAllQueues = false) {
    queueType.updateInfo(
      successCb,
      errorCb,
      needAllQueues
    )
  }

  function onEventMatchingDisconnect(_p) {
    this.afterLeaveQueues({})
  }

  function onEventMatchingConnect(_p) {
    this.afterLeaveQueues({})
  }

  function checkAndStart(onSuccess, onCancel, checkName, checkParams = null) {
    if (!(checkName in this) || this[checkName](checkParams)) {
      if (onSuccess)
        onSuccess()
      return
    }

    if (!::g_squad_utils.canJoinFlightMsgBox(
           {
             isLeaderCanJoin = true,
             msgId = "squad/only_leader_can_cancel"
           }, onSuccess, onCancel
         )
       )
      return

    if (checkParams?.isSilentLeaveQueue) {
      this.leaveAllQueuesAndDo(onSuccess, onCancel)
      return
    }

    ::scene_msg_box("requeue_question", null, loc("msg/cancel_queue_question"),
      [["ok", Callback(@() this.leaveAllQueuesAndDo(onSuccess, onCancel), this)], ["no", onCancel]],
      "ok",
      { cancel_fn = onCancel ?? @()null, checkDuplicateId = true })
  }

  function onEventLobbyStatusChange(_p) {
    if (::SessionLobby.status == lobbyStates.IN_SESSION)
      this.lastQueueReqParams = null
  }
}

::queues = ::QueueManager()

::checkIsInQueue <- function checkIsInQueue() {
  return ::queues.isAnyQueuesActive()
}

::open_search_squad_player <- function open_search_squad_player() {
  ::queues.checkAndStart(::gui_start_search_squadPlayer, null,
    "isCanModifyQueueParams", QUEUE_TYPE_BIT.DOMINATION | QUEUE_TYPE_BIT.NEWBIE)
}
