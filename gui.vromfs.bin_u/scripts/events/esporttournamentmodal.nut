let { DAY, getTourParams, getTourCommonViewParams, getOverlayTextColor, isTourStateChanged,
  getTourActiveTicket, getEventByDay, getEventMission, isRewardsAvailable, setSchedulerTimeColor,
  getMatchingEventId } = require("%scripts/events/eSport.nut")
let { suggestAndAllowPsnPremiumFeatures } = require("scripts/user/psnFeatures.nut")
let { resetSlotbarOverrided, updateOverrideSlotbar } = require("%scripts/slotbar/slotbarOverride.nut")
let { needShowOverrideSlotbar, isLeaderboardsAvailable } = require("%scripts/events/eventInfo.nut")
let { getUnitRole } = require("%scripts/unit/unitInfoTexts.nut")
let QUEUE_TYPE_BIT = require("scripts/queue/queueTypeBit.nut")

let function getActiveTicketTxt(event) {
  let ticket = ::events.getEventActiveTicket(event)
  if (!ticket)
    return ""

  let tournamentData = ticket.getTicketTournamentData(event?.economicName ?? "")
  return ::loc("ui/parentheses/space",
    {text = $"{tournamentData.battleCount}/{ticket.battleLimit}"})
}

local ESportTournament = class extends ::gui_handlers.BaseGuiHandlerWT {
  wndType              = handlerType.MODAL
  sceneTplName         = "%gui/events/eSportTournamentModal"
  slotbarActions       = []
  queueToShow          = null
  tourStatesList       = {}
  isStateChanged       = false
  // Incoming params
  tournament           = null
  curEvent             = null
  curTourParams        = null

  function getSceneTplView() {
    return getTourCommonViewParams(tournament, curTourParams, true).__merge(getDescParams())
  }

  function initScreen() {
    scene.findObject("update_timer").setUserData(this)
    updateQueueInterface()
    updateContentView()

    let showOverrideSlotbar = needShowOverrideSlotbar(curEvent)
    if (showOverrideSlotbar)
      updateOverrideSlotbar(getEventMission(curEvent), curEvent)
    else
      resetSlotbarOverrided()
    createSlotbar({
      eventId = curEvent.name
      needPresetsPanel = !showOverrideSlotbar
      afterSlotbarSelect = updateApplyButton
      afterFullUpdate = updateApplyButton
      showAlwaysFullSlotbar = true
      needCheckUnitUnlock = showOverrideSlotbar
    })
  }

  isInEventQueue = @() queueToShow != null

  function updateCurTournament() {
    curTourParams = getTourParams(tournament)
    curEvent = getEventByDay(tournament.id, curTourParams.dayNum, curTourParams.isTraining)
  }

  function updateQueueInterface() {
    if (!queueToShow || !::queues.isQueueActive(queueToShow))
      queueToShow = getCurEventQueue()
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

  function getDaysParams() {
    local res = []
    let daysNum = tournament.tickets.len()
    for (local i = 0; i < daysNum ; i++) {
      let event = getEventByDay(tournament.id, i)
      let countries = event?.mission_decl.editSlotbar.map(@(v)
        typeof(v) == "table" ? v : null).filter(@(v) v)
      if (countries == null)
        continue

      let isCollapsed = curTourParams.dayNum != i
      local items = []
      local dayCountries = []
      foreach (country, units in countries) {
        dayCountries.append({ icon = ::get_country_icon($"{::g_string.trim(country)}_round") })
        foreach (name, v in units)
          items.append({
            text = ::getUnitName(::getAircraftByName(name), false)
            image = ::getUnitClassIco(name)
            shopItemType = getUnitRole(name)
          })
      }

      res.append({
        day = i+1
        dayCountries = dayCountries
        items = items
        chapterName = ::loc("tournaments/enumerated_day", {num = i + 1})
        isCollapsed = isCollapsed
        collapsed = isCollapsed ? "yes" : "no"
      })
    }

    return res
  }

  function getDescParams() {
    let rangeData = ::events.getPlayersRangeTextData(curEvent)
    let missArr = [$"{::loc("mainmenu/missions")}{::loc("ui/colon")}"]
    foreach (miss, v in (curEvent.mission_decl?.missions_list ?? {}))
      missArr.append("".concat("<color=@activeTextColor>",
        ::get_combine_loc_name_mission(::get_meta_mission_info_by_name(miss)), "</color>"))
    let descTxtArr = [
      ::events.getEventActiveTicketText(curEvent, "activeTextColor"),
      rangeData.isValid ? $"{rangeData.label}<color=@activeTextColor>{rangeData.value}</color>" : "",
      ::events.getRespawnsText(curEvent),
      ::events.getEventDescriptionText(curEvent)
    ].extend(missArr.len() > 1 ? missArr : [])

    return {
      descTxt = "\n".join(descTxtArr, true)
      lbBtnTxt = ::g_string.utf8ToUpper(::loc("tournaments/leaderboard"))
      rewardsBtnTxt = ::g_string.utf8ToUpper(::loc("tournaments/rewards"))
      hasLeaderboardBtn = isLeaderboardsAvailable()
      hasRewardBtn = isRewardsAvailable(tournament)
      days = getDaysParams()
    }
  }

  function updateContentView() {
    updateApplyButton()
    let isFinished = curTourParams.dayNum == DAY.FINISH
    if (isFinished)
      foreach (key in ["h_left", "h_center", "h_right"]) {
        let obj = scene.findObject(key)
        if (obj?.isValid())
          obj["background-saturate"] = 0
      }

    let descObj = ::showBtn("item_desc", !isFinished)
    if (!descObj?.isValid() || isFinished)
      return

    let { descTxt, hasRewardBtn, hasLeaderboardBtn } = getDescParams()
    let eventDescTextObj = descObj.findObject("event_desc_text")
    if (eventDescTextObj?.isValid())
      eventDescTextObj.setValue(descTxt)
    ::showBtn("rewards_btn", hasRewardBtn, scene)
    ::showBtn("leaderboard_obj", hasLeaderboardBtn, scene)
  }

  function updateApplyButton() {
    if (curTourParams.dayNum == DAY.FINISH) {
      ::showBtnTable(scene, {
        action_btn = false
        leave_btn = false
      })
      return
    }

    local startText = "events/join_event"
    let btnObj = ::showBtn("action_btn", !curTourParams.isMyTournament, scene)
    if (!curTourParams.isMyTournament) {
      btnObj.setValue(::loc(startText))
      btnObj.inactiveColor = "no"
      showSceneBtn("leave_btn", false)
      return
    }
    let isEvent = curEvent != null
    let isInQueue = isInEventQueue()
    let hasActiveTicket = !isEvent ? false
      : getTourActiveTicket(curEvent.economicName, tournament.id) != null
    let isReady = ::g_squad_manager.isMeReady()
    let isSquadMember = ::g_squad_manager.isSquadMember()
    let isBtnVisible = isEvent && hasActiveTicket && curTourParams.isSesActive && !isInQueue

    btnObj.show(isBtnVisible)
    btnObj["enable"] = isBtnVisible ? "yes" : "no"
    if (isSquadMember) {
      startText = isReady ? "multiplayer/btnNotReady" : "mainmenu/btnReady"
      btnObj["isCancel"] = isReady ? "yes" : "no"
    }
    else {
      startText = ::loc("mainmenu/toBattle")
      btnObj["isCancel"] = "no"
    }
    btnObj.setValue($"{::loc(startText)}{getActiveTicketTxt(curEvent)}")
    showSceneBtn("leave_btn", isInQueue)
  }

  function updateTourView() {
    let { sesIdx, sesLen, isSesActive, isTraining } = curTourParams
    let { battleDay, curSesTime } = getTourCommonViewParams(tournament, curTourParams)
    let timeTxtObj = scene.findObject("time_txt")
    if (!timeTxtObj?.isValid())
      return

    if (!isStateChanged) {
      if (curSesTime)
        timeTxtObj.setValue(curSesTime)

      return
    }

    scene.findObject("battle_day").setValue(battleDay)
    let txtColor = getOverlayTextColor(isSesActive)
    timeTxtObj.overlayTextColor = txtColor
    let iconImg = $"#ui/gameuiskin#{isSesActive ? "play_tour" : "clock_tour"}.svg"
    scene.findObject("session_ico")["background-image"] = iconImg

    let schedulerObj = scene.findObject("scheduler_obj")
    if (schedulerObj?.isValid())
      for (local i = 0; i < sesLen; i++) {
        let sObj = schedulerObj.findObject($"session_{i}")
        if (sObj?.isValid()) {
          sObj.findObject($"ses_num_txt").visualStyle = i == sesIdx ? "sessionSelected" : ""
          setSchedulerTimeColor(sObj, isTraining, i == sesIdx ? txtColor : "")
        }
      }
  }

  function registerForTournament(){
    let tourId = tournament.id
    let blk = ::DataBlock()
    blk["eventName"] = tourId

    let taskId = ::char_send_blk("cln_subscribe_tournament", blk)
    let taskOptions = {
      showProgressBox = true
      progressBoxText = ::loc("tournaments/registration_in_progress")
    }
    let onSuccess = @() ::broadcastEvent("TourRegistrationComplete", {id = tourId})
    ::g_tasker.addTask(taskId, taskOptions, onSuccess)
  }

  function onEventTourRegistrationComplete(param) {
    curTourParams.isMyTournament = true
    ::showBtn("my_tournament_img", true, scene)
    updateContentView()
  }

  function onBtnAction() {
    if (curEvent == null)
      return

    if (curTourParams.isMyTournament)
      joinEvent()
    else
      registerForTournament()
  }

  function goToBattleFromDebriefing(){
    joinEvent("debriefing")
  }

  function joinEvent(actionPlace = "event_window") {
    if (!curEvent || !suggestAndAllowPsnPremiumFeatures())
      return

    let configForStatistic = {
      actionPlace = actionPlace
      economicName = ::events.getEventEconomicName(curEvent)
      difficulty = curEvent?.difficulty ?? ""
      canIntoToBattle = true
      missionsComplete = ::my_stats.getMissionsComplete()
    }

    ::EventJoinProcess(curEvent, null,
      @(curEvent) ::add_big_query_record("to_battle_button", ::save_to_json(configForStatistic)),
      function() {
        configForStatistic.canIntoToBattle <- false
        ::add_big_query_record("to_battle_button", ::save_to_json(configForStatistic))
      })
  }

  function onLeaveEvent() {
    if (!::g_squad_utils.canJoinFlightMsgBox(
      { isLeaderCanJoin = true, msgId = "squad/only_leader_can_cancel" },
      ::Callback(onLeaveEventActions, this)))
      return
    else
      onLeaveEventActions()
  }

  function onLeaveEventActions() {
    let q = getCurEventQueue()
    if (!q)
      return

    ::queues.leaveQueue(q, { isCanceledByPlayer = true })
  }

  onEventSquadStatusChanged = @(p) updateApplyButton()
  onEventSquadSetReady = @(p) updateApplyButton()
  onEventSquadDataUpdated = @(p) updateApplyButton()

  onLeaderboard = @()
    ::gui_modal_event_leaderboards(getMatchingEventId(tournament.id, curTourParams.dayNum, false))

  function onReward() {
    ::gui_handlers.EventRewardsWnd.open(curEvent, ::get_tournament_desk_blk(tournament.id).awards)
  }

  function updateQueueView() {
    let isInQueue = isInEventQueue()
    let timerObj = ::showBtn("wait_time_block", isInQueue)
    if (!isInQueue)
      return

    let textObj = scene.findObject("waitText")
    let iconObj = scene.findObject("queue_wait_icon")
    ::g_qi_view_utils.updateShortQueueInfo(timerObj, textObj,
      iconObj, ::loc("yn1/waiting_for_game_query"))
  }

  function updateWnd() {
    updateCurTournament()
    let prevState = clone tourStatesList?[tournament.id]
    tourStatesList[tournament.id] <- curTourParams
    isStateChanged = isTourStateChanged(prevState, curTourParams)
    updateTourView()
    if (isStateChanged)
      updateContentView()
  }

  function onTimer(obj, dt) {
    updateWnd()
    updateQueueView()
  }

  function goBackImpl() {
    if (::g_squad_manager.isSquadMember() && getCurEventQueue())
      return

    resetSlotbarOverrided()
    checkedForward(base.goBack)
  }

  function goBack() {
    let q = getCurEventQueue()
    if (!q) {
      goBackImpl()
      return
    }

    ::scene_msg_box("requeue_question", null, ::loc("msg/cancel_queue_question"),
      [["ok", ::Callback(function(){
          onLeaveEvent()
          goBackImpl()
        }, this)], ["no", null]], "ok")
  }

  function onCollapse(obj) {
    let itemObj = obj.getParent()
    if (!itemObj?.isValid())
      return

    let isShow = itemObj.collapsed == "yes"
    itemObj.collapsed  = isShow ? "no" : "yes"

    for (local i = 0; i < itemObj.childrenCount(); i++) {
      let child = itemObj.getChild(i)
      if (child?.collapse_header)
        continue
      child.show(isShow)
      child.enable(isShow)
    }
  }
}

::gui_handlers.ESportTournament <- ESportTournament

return @(params) ::handlersManager.loadHandler(ESportTournament, params)
