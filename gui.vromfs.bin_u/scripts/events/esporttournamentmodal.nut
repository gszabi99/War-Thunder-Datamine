let { DAY, getSessionParams, getTourCommonViewParams, getMatchingEventId, updateTourView,
  isTourStateChanged } = require("%scripts/events/eSport.nut")
let { suggestAndAllowPsnPremiumFeatures } = require("scripts/user/psnFeatures.nut")
let QUEUE_TYPE_BIT = require("scripts/queue/queueTypeBit.nut")

local ESportTournament = class extends ::gui_handlers.BaseGuiHandlerWT {
  wndType         = handlerType.MODAL
  sceneTplName    = "%gui/events/eSportTournamentModal"
  slotbarActions  = ["aircraft", "crew", "sec_weapons", "weapons", "showroom", "repair"]
  queueToShow     = null
  tournamentId    = null
  tourStatesList  = {}
  queueInfoHandlerWeak = null
  // Incomong params
  tournament = null

  function getSceneTplView() {
    let sesParams = getSessionParams(tournament)
    tournamentId = getMatchingEventId(
      tournament.id, sesParams.dayNum >= 0 ? sesParams.dayNum + 1 : 1, sesParams.isTraining)

    return getTourCommonViewParams(tournament, sesParams, true)
  }

  function initScreen() {
    scene.findObject("update_timer").setUserData(this)
    updateQueueInterface()
    updateContentView(getSessionParams(tournament))
    createSlotbar({
      eventId = tournamentId
      afterSlotbarSelect = updateApplyButton
      afterFullUpdate = updateApplyButton
      hasResearchesBtn = true
    })
  }

  isInEventQueue = @() queueToShow != null

  function checkQueueInfoBox() {
    if (!queueToShow || ::handlersManager.isHandlerValid(queueInfoHandlerWeak))
      return

    let queueObj = this.showSceneBtn("queue_progress", true)
    queueObj.height = "ph"
    let queueHandlerClass = queueToShow && ::queues.getQueuePreferredViewClass(queueToShow)
    let queueHandler = ::handlersManager.loadHandler(queueHandlerClass, {
      scene = queueObj
      leaveQueueCb = ::Callback(onLeaveEvent, this)
    })
    registerSubHandler(queueHandler)
    queueInfoHandlerWeak = queueHandler
  }

  function updateQueueInterface() {
    if (!queueToShow || !::queues.isQueueActive(queueToShow))
      queueToShow = getCurEventQueue()
    checkQueueInfoBox()
    let slotbar = getSlotbar()
    if (slotbar)
      slotbar.shade(isInEventQueue())
  }

  function getCurEventQueue() {
    local q = ::queues.findQueue({}, QUEUE_TYPE_BIT.EVENT)
    return (q && ::queues.isQueueActive(q)) ? q : null
  }

  function onEventQueueChangeState(p){
    if (!::queues.isEventQueue(p?.queue))
      return

    updateQueueInterface()
    updateApplyButton()
  }

  function updateContentView(sesParams) {
    let prevState = clone tourStatesList?[tournament.id]
    tourStatesList[tournament.id] <- sesParams
    if (!isTourStateChanged(prevState, sesParams))
      return

    let isFinished = sesParams.dayNum == DAY.FINISH
    let isActive = sesParams.dayNum >= 0 || sesParams.dayNum == DAY.NEXT
    ::showBtnTable(scene, {
      join_btn    = !isFinished
      scheduler   = isActive
    })
    foreach (key in ["h_left", "h_center", "h_right"]) {
      let obj = scene.findObject(key)
      if (obj?.isValid())
        obj["background-saturate"] = isFinished ? 0 : 1
    }

    updateApplyButton()
  }

  function updateApplyButton() {
    let event = ::events.getEvent(tournamentId)
    let isEvent = event != null
    let isInQueue = isInEventQueue()
    let isMouseMode = !::show_console_buttons || ::is_mouse_last_time_used()
    let reasonData = ::events.getCantJoinReasonData(
      isEvent && (isMouseMode || isInQueue) ? event : null)
    let isReady = ::g_squad_manager.isMeReady()
    let isSquadMember = ::g_squad_manager.isSquadMember()

    let joinButtonObj = ::showBtn("join_btn",
      isEvent && (!isInQueue || (isSquadMember && !isReady)), scene)
    joinButtonObj.inactiveColor = (reasonData.activeJoinButton && !isInQueue) ? "no" : "yes"
    joinButtonObj.tooltip = isSquadMember ? reasonData.reasonText : ""
    showSceneBtn("leave_btn", isInQueue)
  }

  function onJoinEvent(isFromDebriefing = false) {
    let event = ::events.getEvent(tournamentId)
    if (!event || !suggestAndAllowPsnPremiumFeatures())
      return

    let configForStatistic = {
      actionPlace = "event_window"
      economicName = ::events.getEventEconomicName(event)
      difficulty = event?.difficulty ?? ""
      canIntoToBattle = true
      missionsComplete = ::my_stats.getMissionsComplete()
    }

    ::EventJoinProcess(event, null,
      @(event) ::add_big_query_record("to_battle_button", ::save_to_json(configForStatistic)),
      function() {
        configForStatistic.canIntoToBattle <- false
        ::add_big_query_record("to_battle_button", ::save_to_json(configForStatistic))
      })
  }

  function onLeaveEvent() {
    if (!::g_squad_utils.canJoinFlightMsgBox(
        {isLeaderCanJoin = true, msgId = "squad/only_leader_can_cancel"},
        ::Callback(onLeaveEventActions, this)))
      return

    onLeaveEventActions()
  }

  function onLeaveEventActions() {
    let q = getCurEventQueue()
    if (!q)
      return

    ::queues.leaveQueue(q, { isCanceledByPlayer = true })
  }

  onTimer = function (obj, dt) {
    let sesParams = getSessionParams(tournament)
    updateTourView(scene, tournament, tourStatesList, sesParams)
    updateContentView(sesParams)
  }

  function onEventAfterJoinEventRoom(event) {
    ::handlersManager.requestHandlerRestore(this, ::gui_handlers.MainMenu)
  }

  function goBack() {
    checkedForward(base.goBack)
  }
}

::gui_handlers.ESportTournament <- ESportTournament

return @(tournament) ::handlersManager.loadHandler(ESportTournament, {tournament})
