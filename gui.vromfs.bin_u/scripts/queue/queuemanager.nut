local clustersModule = require("scripts/clusterSelect.nut")
local QUEUE_TYPE_BIT = require("scripts/queue/queueTypeBit.nut")

global enum queueStates
{
  ERROR,
  NOT_IN_QUEUE,
  JOINING_QUEUE,
  LEAVING_QUEUE,
  IN_QUEUE
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
  ::g_script_reloader.loadOnce("scripts/queue/" + fn) // no need to includeOnce to correct reload this scripts pack runtime

::queues <- null //init in second mainmenu

::QueueManager <- class {
  state              = queueStates.NOT_IN_QUEUE

  progressBox        = null
  queuesList         = null
  lastId             = -1

  delayedInfoUpdateEventtTime = -1

  queue_diff_params = ["mode", "team"]

  constructor()
  {
    init()
    ::g_script_reloader.registerPersistentData("QueueManager", this, ["queuesList", "lastId", "state"])
    ::subscribe_handler(this, ::g_listener_priority.DEFAULT_HANDLER)
  }

  function init()
  {
    queuesList = []
    lastId     = -1
  }

  function createQueue(params, needModifyParamsByType = false)
  {
    local queueType = ::g_queue_type.getQueueTypeByParams(params)

    if (needModifyParamsByType)
      params = queueType.prepareQueueParams(params)

    local queue = findQueue(params)
    if (queue)
    {
      if (queue.addQueueByParams(params))
        ::broadcastEvent("QueueClustersChanged", queue)
      return queue
    }

    queue = queueType.createQueue(lastId++, params)
    queuesList.append(queue)

    return queue
  }

  function removeQueue(queue)
  {
    changeState(queue, queueStates.NOT_IN_QUEUE)
    foreach(idx, q in queuesList)
      if (q.id == queue.id)
        return queuesList.remove(idx)
  }

  function isEqual(params1, params2, null_is_equal = true)
  {
    foreach(p in queue_diff_params)
      if ((p in params1) != (p in params2))
      {
        if (!null_is_equal)
          return false
      }
      else if ((p in params1) && params1[p] != params2[p])
        return false
    return true
  }

  function findQueue(params, typeMask = -1, checkActive = true)
  {
    foreach(q in queuesList)
      if ((typeMask < 0 || (typeMask & q.typeBit)) && (!checkActive || isQueueActive(q)))
          if (isEqual(params, q.params))
            return q
    return null
  }

  function isQueuesEqual(q1, q2)
  {
    if (!q1 || !q2)
      return !q1 == !q2
    return q1.id == q2.id
  }

  function findAllQueues(params, typeMask = -1)
  {
    local res = []
    foreach(q in queuesList)
      if (typeMask < 0 || (typeMask & q.typeBit))
        if (isEqual(params, q.params))
          res.append(q)
    return res
  }

  function findQueueByName(name, isActive = false)
  {
    foreach(queue in queuesList)
      if (queue.name == name && (!isActive || isQueueActive(queue)))
        return queue
    return null
  }

  function findQueueByQueueUid(queueUid)
  {
    foreach(queue in queuesList)
      if (queueUid in queue.queueUidsList)
        return queue
    return null
  }

  function getActiveQueueTypes()
  {
    local res = []
    foreach(queue in queuesList)
      if (isQueueActive(queue))
         ::u.appendOnce(queue.queueType, res)

    return res
  }

  function getActiveQueueWithType(typeBit)
  {
    foreach(queue in queuesList)
      if ((typeBit & queue.typeBit) && isQueueActive(queue))
        return queue

    return null
  }

  function hasActiveQueueWithType(typeBit)
  {
    return getActiveQueueWithType(typeBit) != null
  }

  function isQueueActive(queue)
  {
    return queue != null && (queue.state == queueStates.IN_QUEUE || queue.state == queueStates.JOINING_QUEUE)
  }

  function isAnyQueuesActive(typeMask = -1)
  {
    foreach(q in queuesList)
      if (typeMask < 0 || (typeMask & q.typeBit))
        if (isQueueActive(q))
          return true
    return false
  }

  function getActiveQueueByName(id)
  {
    foreach(q in queuesList)
      if (isQueueActive(q))
        return true
    return false
  }

  function leaveQueueByType(typeBit = -1)
  {
    if (typeBit < 0)
      return leaveAllQueues()

    foreach(queue in queuesList)
      if ((typeBit & queue.typeBit) && isQueueActive(queue))
        leaveQueue(queue)
  }

  function changeState(queue, queueState)
  {
    if (queue.state == queueState)
      return

    local wasAnyActive = isAnyQueuesActive()

    queue.state = queueState
    queue.activateTime = isQueueActive(queue)? ::dagor.getCurTime() : -1
    ::broadcastEvent("QueueChangeState", { queue = queue })

    if (wasAnyActive!=isAnyQueuesActive)
      ::update_gamercards()
  }

  function getQueueType(queue)
  {
    return queue.typeBit
  }

  function cantSquadQueueMsgBox(params = null, reasonText = "")
  {
    dagor.debug("Error: cant join queue with squad. " + reasonText)
    if (params)
      debugTableData(params)

    local msg = ::loc("squad/cant_join_queue")
    if (reasonText)
      msg += "\n" + reasonText
    ::showInfoMsgBox(msg, "cant_join_queue")
  }

  function showProgressBox(show, text = "charServer/purchase0")
  {
    if (::checkObj(progressBox))
    {
      progressBox.getScene().destroyElement(progressBox)
      ::broadcastEvent("ModalWndDestroy")
      progressBox = null
    }
    if (show)
      progressBox = ::scene_msg_box("queue_action", null, ::loc(text),
        [["cancel", function(){}]], "cancel",
        { waitAnim = true,
          delayedButtons = 30
        })
  }

  function joinFriendsQueue(inGameEx, eventId)
  {
    joinQueue({
      mode = eventId
      country = ::get_profile_country_sq()
      slots = ::getSelSlotsTable()
      clusters = clustersModule.getCurrentClusters()
      queueSelfActivated = true
      team = inGameEx.team.tointeger()
      roomId = inGameEx.roomId.tointeger()
      gameQueueId = inGameEx.gameQueueId
    })
  }

  function joinQueue(params)
  {
    if (findQueue(params))
      return dagor.debug("Error: cancel join queue becoase already exist.")

    ::queues.showProgressBox(true)
    local queue = createQueue(params, true)

    queue.join(
      function(response) {
        ::queues.showProgressBox(false)
        ::queues.afterJoinQueue(queue)
      },
      function(response) {
        ::queues.showProgressBox(false)
        ::queues.removeQueue(queue)
      }
    )

    changeState(queue, queueStates.JOINING_QUEUE)
  }

  function afterJoinQueue(queue)
  {
    changeState(queue, queueStates.IN_QUEUE)
    ::set_presence_to_player("queue")
  }

  function leaveAllQueues(params = null, postAction = null, postCancelAction = null, silent = false) //null = all
  {
    if (params)
    {
      local list = findAllQueues(params)
      foreach(q in list)
        leaveQueue(q)
      return
    }

    if (!isAnyQueuesActive())
      return postAction && postAction()

    showProgressBox(true)

    local callback = _getOnLeaveQueueErrorCallback(postAction, postCancelAction, silent)
    foreach(queueType in getActiveQueueTypes())
      queueType.leaveAllQueues(callback, callback, false)

    foreach(q in queuesList)
      if (q.state != queueStates.NOT_IN_QUEUE)
        changeState(q, queueStates.LEAVING_QUEUE)
  }

  function _getOnLeaveQueueErrorCallback(postAction, postCancelAction, silent)
  {
    return function(response) {
        ::queues.showProgressBox(false)
        if (response.error == SERVER_ERROR_REQUEST_REJECTED)
        {
          if (postCancelAction)
            postCancelAction()
          ::SessionLobby.setWaitForQueueRoom(true)
        }
        else
        {
          ::checkMatchingError(response, !silent)
          ::queues.afterLeaveQueues({})

          // This check is a workaround that fixes
          // player being able to perform some action
          // split second before battle begins.
          if (!::SessionLobby.isWaitForQueueRoom()
            && !::SessionLobby.isInRoom())
          {
            if (postAction)
              postAction()
          }
          else
          {
            if (postCancelAction)
              postCancelAction()
          }
        }
      }
  }

  function leaveAllQueuesSilent()
  {
    return leaveAllQueues(null, null, null, true)
  }

  function leaveQueue(queue, params = {})
  {
    if (queue.state == queueStates.LEAVING_QUEUE)
      return
    if (queue.state == queueStates.NOT_IN_QUEUE)
      return removeQueue(queue)

    ::queues.showProgressBox(true)

    ::add_big_query_record("exit_waiting_for_battle_screen",
      ::save_to_json({ waitingTime = queue.getActiveTime()
        queueType = queue.queueType.typeName
        eventId = getQueueMode(queue)
        country = getQueueCountry(queue)
        rank = getMyRankInQueue(queue)
        isCanceledByPlayer = params?.isCanceledByPlayer ?? false }))

    queue.leave(
      getOnLeaveQueueSuccessCallback(queue),
      getOnLeaveQueueErrorCallback(queue)
    )

    changeState(queue, queueStates.LEAVING_QUEUE)
  }

  function getOnLeaveQueueErrorCallback(queue)
  {
    return function(response) {
        ::queues.showProgressBox(false)
        if (response.error == SERVER_ERROR_REQUEST_REJECTED)
        {
          ::SessionLobby.setWaitForQueueRoom(true)
          return
        }

        ::checkMatchingError(response)
        ::queues.removeQueue(queue)
      }
  }

  function getOnLeaveQueueSuccessCallback(queue)
  {
    return function(response) {
        ::queues.showProgressBox(false)
        ::queues.afterLeaveQueue(queue)
      }
  }

  function afterLeaveQueue(queue, msg = null)
  {
    removeQueue(queue)
    if (msg && !::checkObj(::get_gui_scene()["leave_queue_msgbox"]))
      ::showInfoMsgBox(msg, "leave_queue_msgbox")
  }

  //handles all queus, matches with @params
  function afterLeaveQueues(params)
  {
    local list = findAllQueues(params)
    foreach(q in list)
      if (q.removeQueueByParams(params))
      {
        if (!q.isActive())
          removeQueue(q)
        else
          ::broadcastEvent("QueueChanged", q)
      }
  }

  function leaveAllQueuesAndDo(action, cancelAction = null)
  {
    leaveAllQueues(null, action, cancelAction)
  }

  function isCanModifyQueueParams(typeMask)
  {
    return findQueue({}, typeMask) == null
  }

  function isCanNewflight(...)
  {
    return !isAnyQueuesActive()
  }

  function isCanChangeCluster(...)
  {
    return !isAnyQueuesActive()
  }

  function isCanUseOnlineShop(...)
  {
    return !isAnyQueuesActive()
  }

  function isCanGoForward(...)
  {
    return true
  }

  function isCanModifyCrew(...)
  {
    return !isAnyQueuesActive()
  }

  function isCanAirChange(...)
  {
    if (!isCanGoForward())
      return false

    foreach(q in queuesList)
      if (isQueueActive(q))
      {
        local event = getQueueEvent(q)
        if (event && !::events.isEventMultiSlotEnabled(event))
          return false
      }
    return true
  }

  function isClanQueue(queue)
  {
    local event = ::events.getEvent(queue.name)
    if (event == null)
      return false
    return ::events.isEventForClan(event)
  }

  function getQueueEvent(queue)
  {
    return ::events.getEvent(queue.name)
  }

  function getQueueMode(queue)
  {
    return ("mode" in queue.params)? queue.params.mode : ""
  }

  function getQueueTeam(queue)
  {
    return ("team" in queue.params)? queue.params.team : Team.Any
  }

  function getQueueCountry(queue)
  {
    return ("country" in queue.params)? queue.params.country : ""
  }

  function getQueueClusters(queue)
  {
    return "clusters" in queue.params ? queue.params.clusters : []
  }

  function getQueueSlots(queue)
  {
    return ("slots" in queue.params)? queue.params.slots : null
  }

  function getQueueOperationId(queue)
  {
    return queue.params?.operationId ?? -1
  }

  function getMyRankInQueue(queue)
  {
    local event = getQueueEvent(queue)
    if (!event)
      return -1

    local country = getQueueCountry(queue)
    return ::events.getSlotbarRank(event,
                                   country,
                                   ::getTblValue(country, getQueueSlots(queue), 0)
                                  )
  }

  function getQueuesInfoText()
  {
    local text = ::loc("inQueueList/header")
    foreach(queue in queuesList)
      if (isQueueActive(queue))
        text += "\n" + queue.getDescription()

    return text
  }

  function isEventQueue(queue)
  {
    if (!queue)
      return false
    return queue.typeBit == QUEUE_TYPE_BIT.EVENT
  }

  function isDominationQueue(queue)
  {
    if (!queue)
      return false
    return queue.typeBit == QUEUE_TYPE_BIT.DOMINATION
  }

  function checkQueueType(queue, typeMask)
  {
    return (::getTblValue("typeBit", queue, 0) & typeMask) != 0
  }

  function getQueuePreferredViewClass(queue)
  {
    local defaultHandler = ::gui_handlers.QiHandlerByTeams
    local event = getQueueEvent(queue)
    if (!event)
      return defaultHandler
    if (!::events.isEventForClan(event) && ::events.isEventSymmetricTeams(event))
      return ::gui_handlers.QiHandlerByCountries
    return defaultHandler
  }

  function onEventClanInfoUpdate(params)
  {
    if (!::my_clan_info)
      foreach(queue in queuesList)
        if (isClanQueue(queue))
          leaveQueue(queue)
  }

  function applyQueueInfo(info, statsClass)
  {
    local queue = ("queueId" in info) ? findQueueByQueueUid(info.queueId)
                  : ("name" in info)  ? findQueueByName(info.name)
                                      : null
    if (!queue)
      return false

    if (!queue.queueStats)
      queue.queueStats = statsClass(queue)

    return queue.queueStats.applyQueueInfo(info)
  }

  function onEventQueueInfoRecived(params)
  {
    local haveChanges = false
    local queueInfo = ::getTblValue("queue_info", params)

    if (::u.isTable(queueInfo))
      haveChanges = applyQueueInfo(queueInfo, ::queue_stats_versions.StatsVer2)
    else if (::u.isArray(queueInfo)) //queueInfo ver1
      foreach(qi in queueInfo)
        if (applyQueueInfo(qi, ::queue_stats_versions.StatsVer1))
          haveChanges = true

    if (haveChanges)
      pushQueueInfoUpdatedEvent()
  }

  function pushQueueInfoUpdatedEvent()
  {
    if (delayedInfoUpdateEventtTime > 0 && ::dagor.getCurTime() - delayedInfoUpdateEventtTime < 1000)
      return

    local guiScene = ::get_gui_scene()
    if (!guiScene)
      return

    delayedInfoUpdateEventtTime = ::dagor.getCurTime()
    guiScene.performDelayed(this, function()
     {
       delayedInfoUpdateEventtTime = -1
       if (isAnyQueuesActive())
        ::broadcastEvent("QueueInfoUpdated")
     })
  }

  function updateQueueInfoByType(queueType, successCb, errorCb = null, needAllQueues = false)
  {
    queueType.updateInfo(
      successCb,
      errorCb,
      needAllQueues
    )
  }

  function onEventMatchingDisconnect(p)
  {
    afterLeaveQueues({})
  }

  function onEventMatchingConnect(p)
  {
    afterLeaveQueues({})
  }

  function checkAndStart(onSuccess, onCancel, checkName, checkParams = null)
  {
    if (!(checkName in this) || this[checkName](checkParams))
    {
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

    local leaveQueueAndConinue = function () {
      ::queues.leaveAllQueuesAndDo(onSuccess, onCancel)
    }

    if (::getTblValue("isSilentLeaveQueue", checkParams))
    {
      leaveQueueAndConinue()
      return
    }

    ::scene_msg_box("requeue_question", null, ::loc("msg/cancel_queue_question"),
      [["ok", leaveQueueAndConinue], ["no", onCancel]],
      "ok",
      { cancel_fn = onCancel || @()null, checkDuplicateId = true })
  }
}

::queues = QueueManager()

::checkIsInQueue <- function checkIsInQueue()
{
  return ::queues.isAnyQueuesActive()
}

::open_search_squad_player <- function open_search_squad_player()
{
  ::queues.checkAndStart(::gui_start_search_squadPlayer, null,
    "isCanModifyQueueParams", QUEUE_TYPE_BIT.DOMINATION | QUEUE_TYPE_BIT.NEWBIE)
}
