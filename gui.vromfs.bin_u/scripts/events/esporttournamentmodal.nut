from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { DAY, getTourParams, getTourCommonViewParams, getOverlayTextColor, isTourStateChanged,
  getTourActiveTicket, getEventByDay, getEventMission, isRewardsAvailable, setSchedulerTimeColor,
  getMatchingEventId, fetchLbData } = require("%scripts/events/eSport.nut")
let { suggestAndAllowPsnPremiumFeatures } = require("%scripts/user/psnFeatures.nut")
let { resetSlotbarOverrided, updateOverrideSlotbar } = require("%scripts/slotbar/slotbarOverride.nut")
let { needShowOverrideSlotbar, isLeaderboardsAvailable } = require("%scripts/events/eventInfo.nut")
let { getUnitRole } = require("%scripts/unit/unitInfoTexts.nut")
let QUEUE_TYPE_BIT = require("%scripts/queue/queueTypeBit.nut")
let { setModalBreadcrumbGoBackParams } = require("%scripts/breadcrumb.nut")

let function getActiveTicketTxt(event) {
  if (!event)
    return ""

  let ticket = ::events.getEventActiveTicket(event)
  if (!ticket)
    return ""

  let tournamentData = event?.economicName
    ? ticket.getTicketTournamentData(event.economicName) : null

  return tournamentData
    ? loc("ui/parentheses/space", {text = $"{tournamentData.battleCount}/{ticket.battleLimit}"})
    : ""
}

local ESportTournament = class extends ::gui_handlers.BaseGuiHandlerWT {
  wndType              = handlerType.MODAL
  sceneTplName         = "%gui/events/eSportTournamentModal.tpl"
  slotbarActions       = []
  queueToShow          = null
  tourStatesList       = {}
  isStateChanged       = false
  // Incoming params
  tournament           = null
  curEvent             = null
  curTourParams        = null

  function getSceneTplView() {
    return getTourCommonViewParams(this.tournament, this.curTourParams, true).__merge(this.getDescParams())
  }

  function initScreen() {
    this.scene.findObject("update_timer").setUserData(this)
    setModalBreadcrumbGoBackParams(this)
    this.updateQueueInterface()
    this.updateContentView()

    let showOverrideSlotbar = needShowOverrideSlotbar(this.curEvent)
    if (showOverrideSlotbar)
      updateOverrideSlotbar(getEventMission(this.curEvent), this.curEvent)
    else
      resetSlotbarOverrided()
    this.createSlotbar({
      eventId = this.curEvent.name
      needPresetsPanel = !showOverrideSlotbar
      afterSlotbarSelect = this.updateApplyButton
      afterFullUpdate = this.updateApplyButton
      showAlwaysFullSlotbar = true
      needCheckUnitUnlock = showOverrideSlotbar
      showTopPanel = false
    })
  }

  isInEventQueue = @() this.queueToShow != null

  function updateCurTournament() {
    this.curTourParams = getTourParams(this.tournament)
    this.curEvent = getEventByDay(this.tournament.id, this.curTourParams.dayNum, this.curTourParams.isTraining)
  }

  function updateQueueInterface() {
    if (!this.queueToShow || !::queues.isQueueActive(this.queueToShow))
      this.queueToShow = this.getCurEventQueue()
    let slotbar = this.getSlotbar()
    if (slotbar)
      slotbar.shade(this.isInEventQueue())
  }

  function getCurEventQueue() {
    local q = ::queues.findQueue({}, QUEUE_TYPE_BIT.EVENT)
    return (q && ::queues.isQueueActive(q)) ? q : null
  }

  function onEventQueueChangeState(p){
    if (!::queues.isEventQueue(p?.queue))
      return

    this.updateQueueInterface()
    this.updateApplyButton()
  }

  function getDaysParams() {
    local res = []
    let daysNum = this.tournament.tickets.len()
    for (local i = 0; i < daysNum ; i++) {
      let event = getEventByDay(this.tournament.id, i)
      let countries = event?.mission_decl.editSlotbar.map(@(v)
        typeof(v) == "table" ? v : null).filter(@(v) v)
      if (countries == null)
        continue

      let isCollapsed = this.curTourParams.dayNum != i
      local items = []
      local dayCountries = []
      foreach (country, units in countries) {
        dayCountries.append({ icon = ::get_country_icon($"{::g_string.trim(country)}_round") })
        foreach (name, _v in units)
          items.append({
            text = ::getUnitName(::getAircraftByName(name))
            image = ::getUnitClassIco(name)
            shopItemType = getUnitRole(name)
          })
      }

      res.append({
        day = i+1
        dayCountries = dayCountries
        items = items
        chapterName = loc("tournaments/enumerated_day", {num = i + 1})
        isCollapsed = isCollapsed
        collapsed = isCollapsed ? "yes" : "no"
      })
    }

    return res
  }

  function updateLbObjects(lbData) {
    let isLbEnable = lbData.rows.len() > 0
    let lbObj = ::showBtn("leaderboard_obj", isLeaderboardsAvailable(), this.scene)
    if (!lbObj?.isValid())
      return

    lbObj.enable(isLbEnable)
    lbObj.inactiveColor = isLbEnable ? "no" : "yes"
    if (!isLbEnable)
      return

    let topObj = this.scene.findObject("top_nest")
    if (!topObj?.isValid())
      return

    let texts = []
    foreach (idx, row in lbData.rows) {
      if (idx > 2)
        break

      let txt = row._id == ::my_user_id_str
        ? colorize("totalTextColor", row.name) : row.name
      texts.append({ text = $"{idx + 1} {txt}"})
    }
    let data = ::handyman.renderCached("%gui/commonParts/text.tpl", {texts = texts})
    this.guiScene.replaceContentFromText(topObj, data, data.len(), this)
  }

  function getDescParams() {
    fetchLbData(
      getEventByDay(this.tournament.id, this.curTourParams.dayNum, false),
      @(lbData) this.updateLbObjects(lbData), this)
    let rangeData = ::events.getPlayersRangeTextData(this.curEvent)
    let missArr = [$"{loc("mainmenu/missions")}{loc("ui/colon")}"]
    foreach (miss, _v in (this.curEvent.mission_decl?.missions_list ?? {}))
      missArr.append("".concat("<color=@activeTextColor>",
        ::get_combine_loc_name_mission(::get_meta_mission_info_by_name(miss)), "</color>"))
    let descTxtArr = [
      ::events.getEventActiveTicketText(this.curEvent, "activeTextColor"),
      rangeData.isValid ? $"{rangeData.label}<color=@activeTextColor>{rangeData.value}</color>" : "",
      ::events.getRespawnsText(this.curEvent),
      ::events.getEventDescriptionText(this.curEvent)
    ].extend(missArr.len() > 1 ? missArr : [])

    return {
      descTxt = "\n".join(descTxtArr, true)
      lbBtnTxt = ::g_string.utf8ToUpper(loc("tournaments/leaderboard"))
      rewardsBtnTxt = ::g_string.utf8ToUpper(loc("tournaments/rewards"))
      hasRewardBtn = isRewardsAvailable(this.tournament)
      days = this.getDaysParams()
    }
  }

  function updateContentView() {
    this.updateApplyButton()
    let isFinished = this.curTourParams.dayNum == DAY.FINISH
    if (isFinished)
      foreach (key in ["h_left", "h_center", "h_right"]) {
        let obj = this.scene.findObject(key)
        if (obj?.isValid())
          obj["background-saturate"] = 0
      }

    let descObj = ::showBtn("item_desc", !isFinished)
    if (!descObj?.isValid() || isFinished)
      return

    let { descTxt, hasRewardBtn } = this.getDescParams()
    let eventDescTextObj = descObj.findObject("event_desc_text")
    if (eventDescTextObj?.isValid())
      eventDescTextObj.setValue(descTxt)
    ::showBtn("rewards_btn", hasRewardBtn, this.scene)
  }

  function updateApplyButton() {
    if (this.curTourParams.dayNum == DAY.FINISH) {
      ::showBtnTable(this.scene, {
        action_btn = false
        leave_btn = false
      })
      return
    }

    local startText = "events/join_event"
    let btnObj = ::showBtn("action_btn", !this.curTourParams.isMyTournament, this.scene)
    if (!this.curTourParams.isMyTournament) {
      btnObj.setValue(loc(startText))
      btnObj.inactiveColor = "no"
      this.showSceneBtn("leave_btn", false)
      return
    }
    let isEvent = this.curEvent != null
    let isInQueue = this.isInEventQueue()
    let hasActiveTicket = !isEvent ? false
      : getTourActiveTicket(this.curEvent.economicName, this.tournament.id) != null
    let isReady = ::g_squad_manager.isMeReady()
    let isSquadMember = ::g_squad_manager.isSquadMember()
    let isBtnVisible = isEvent && hasActiveTicket && this.curTourParams.isSesActive && !isInQueue

    btnObj.show(isBtnVisible)
    btnObj["enable"] = isBtnVisible ? "yes" : "no"
    if (isSquadMember) {
      startText = isReady ? "multiplayer/btnNotReady" : "mainmenu/btnReady"
      btnObj["isCancel"] = isReady ? "yes" : "no"
    }
    else {
      startText = loc("mainmenu/toBattle")
      btnObj["isCancel"] = "no"
    }
    btnObj.setValue($"{loc(startText)}{getActiveTicketTxt(this.curEvent)}")
    this.showSceneBtn("leave_btn", isInQueue)
  }

  function updateTourView() {
    let { sesIdx, sesLen, isSesActive, isTraining } = this.curTourParams
    let { battleDay, curSesTime } = getTourCommonViewParams(this.tournament, this.curTourParams)
    let timeTxtObj = this.scene.findObject("time_txt")
    if (!timeTxtObj?.isValid())
      return

    if (!this.isStateChanged) {
      if (curSesTime)
        timeTxtObj.setValue(curSesTime)

      return
    }

    this.scene.findObject("battle_day").setValue(battleDay)
    let txtColor = getOverlayTextColor(isSesActive)
    timeTxtObj.overlayTextColor = txtColor
    let iconImg = $"#ui/gameuiskin#{isSesActive ? "play_tour" : "clock_tour"}.svg"
    this.scene.findObject("session_ico")["background-image"] = iconImg

    let schedulerObj = this.scene.findObject("scheduler_obj")
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
    let tourId = this.tournament.id
    let blk = ::DataBlock()
    blk["eventName"] = tourId

    let taskId = ::char_send_blk("cln_subscribe_tournament", blk)
    let taskOptions = {
      showProgressBox = true
      progressBoxText = loc("tournaments/registration_in_progress")
    }
    let onSuccess = @() ::broadcastEvent("TourRegistrationComplete", {id = tourId})
    ::g_tasker.addTask(taskId, taskOptions, onSuccess)
  }

  function onEventTourRegistrationComplete(_param) {
    this.curTourParams.isMyTournament = true
    ::showBtn("my_tournament_img", true, this.scene)
    this.updateContentView()
  }

  function onBtnAction() {
    if (this.curEvent == null)
      return

    if (this.curTourParams.isMyTournament)
      this.joinEvent()
    else
      this.registerForTournament()
  }

  function goToBattleFromDebriefing(){
    this.joinEvent("debriefing")
  }

  function joinEvent(actionPlace = "event_window") {
    if (!this.curEvent || !suggestAndAllowPsnPremiumFeatures())
      return

    let configForStatistic = {
      actionPlace = actionPlace
      economicName = ::events.getEventEconomicName(this.curEvent)
      difficulty = this.curEvent?.difficulty ?? ""
      canIntoToBattle = true
      missionsComplete = ::my_stats.getMissionsComplete()
    }

    ::EventJoinProcess(this.curEvent, null,
      @(_curEvent) ::add_big_query_record("to_battle_button", ::save_to_json(configForStatistic)),
      function() {
        configForStatistic.canIntoToBattle <- false
        ::add_big_query_record("to_battle_button", ::save_to_json(configForStatistic))
      })
  }

  function onLeaveEvent() {
    if (!::g_squad_utils.canJoinFlightMsgBox(
      { isLeaderCanJoin = true, msgId = "squad/only_leader_can_cancel" },
      Callback(this.onLeaveEventActions, this)))
      return
    else
      this.onLeaveEventActions()
  }

  function onLeaveEventActions() {
    let q = this.getCurEventQueue()
    if (!q)
      return

    ::queues.leaveQueue(q, { isCanceledByPlayer = true })
  }

  onEventSquadStatusChanged = @(_p) this.updateApplyButton()
  onEventSquadSetReady = @(_p) this.updateApplyButton()
  onEventSquadDataUpdated = @(_p) this.updateApplyButton()

  onLeaderboard = @()
    ::gui_modal_event_leaderboards(getMatchingEventId(this.tournament.id, this.curTourParams.dayNum, false),
      this.tournament.sharedEconomicName)

  function onReward() {
    ::gui_handlers.EventRewardsWnd.open([{
        header = loc("tournaments/rewards")
        event = this.curEvent
        tourId = this.tournament.id
      },{
        header = loc("tournaments/seasonRewards")
        event = this.curEvent
        tourId = this.tournament.sharedEconomicName
      }])
  }

  function updateQueueView() {
    let isInQueue = this.isInEventQueue()
    let timerObj = ::showBtn("wait_time_block", isInQueue)
    if (!isInQueue)
      return

    let textObj = this.scene.findObject("waitText")
    let iconObj = this.scene.findObject("queue_wait_icon")
    ::g_qi_view_utils.updateShortQueueInfo(timerObj, textObj,
      iconObj, loc("yn1/waiting_for_game_query"))
  }

  function updateWnd() {
    this.updateCurTournament()
    let prevState = clone this.tourStatesList?[this.tournament.id]
    this.tourStatesList[this.tournament.id] <- this.curTourParams
    this.isStateChanged = isTourStateChanged(prevState, this.curTourParams)
    this.updateTourView()
    if (this.isStateChanged)
      this.updateContentView()
  }

  function onTimer(_obj, _dt) {
    this.updateWnd()
    this.updateQueueView()
  }

  function goBackImpl() {
    if (::g_squad_manager.isSquadMember() && this.getCurEventQueue())
      return

    resetSlotbarOverrided()
    this.checkedForward(base.goBack)
  }

  function goBack() {
    let q = this.getCurEventQueue()
    if (!q) {
      this.goBackImpl()
      return
    }

    ::scene_msg_box("requeue_question", null, loc("msg/cancel_queue_question"),
      [["ok", Callback(function(){
          this.onLeaveEvent()
          this.goBackImpl()
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
