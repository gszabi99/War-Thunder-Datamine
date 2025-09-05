from "%scripts/dagui_natives.nut" import is_mouse_last_time_used
from "%scripts/dagui_library.nut" import *
from "%scripts/mainConsts.nut" import SEEN

let { getGlobalModule } = require("%scripts/global_modules.nut")
let events = getGlobalModule("events")
let g_squad_manager = getGlobalModule("g_squad_manager")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let DataBlock = require("DataBlock")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { move_mouse_on_child_by_value, move_mouse_on_child } = require("%sqDagui/daguiUtil.nut")
let { loadHandler, handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { format } = require("string")
let seenEvents = require("%scripts/seen/seenList.nut").get(SEEN.EVENTS)
let bhvUnseen = require("%scripts/seen/bhvUnseen.nut")
let { getTextWithCrossplayIcon, isCrossPlayEnabled, needShowCrossPlayInfo
} = require("%scripts/social/crossplay.nut")
let clustersModule = require("%scripts/clusterSelect.nut")
let QUEUE_TYPE_BIT = require("%scripts/queue/queueTypeBit.nut")
let { setDoubleTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { isPlatformSony } = require("%scripts/clientState/platform.nut")
let { suggestAndAllowPsnPremiumFeatures } = require("%scripts/user/psnFeatures.nut")
let { resetSlotbarOverrided, updateOverrideSlotbar } = require("%scripts/slotbar/slotbarOverride.nut")
let { needShowOverrideSlotbar, getCustomViewCountryData, getEventEconomicName, isTeamSizeBalancedEvent,
  isEventWithLobby, getEventReqPack, checkEventFeaturePacks, isEventPlatformOnlyAllowed
} = require("%scripts/events/eventInfo.nut")
let { eachParam } = require("%sqstd/datablock.nut")
let { addPromoAction } = require("%scripts/promo/promoActions.nut")
let { addPromoButtonConfig } = require("%scripts/promo/promoButtonsConfig.nut")
let { setGuiOptionsMode, getGuiOptionsMode } = require("guiOptions")
let { GUI } = require("%scripts/utils/configs.nut")
let { checkAndShowMultiplayerPrivilegeWarning,
  isMultiplayerPrivilegeAvailable } = require("%scripts/user/xboxFeatures.nut")
let { isShowGoldBalanceWarning } = require("%scripts/user/balanceFeatures.nut")
let openClustersMenuWnd = require("%scripts/onlineInfo/clustersMenuWnd.nut")
let { setTimeout, clearTimer } = require("dagor.workcycle")
let { cutPrefix } = require("%sqstd/string.nut")
let { sendBqEvent } = require("%scripts/bqQueue/bqQueue.nut")
let { setPromoButtonText, getPromoVisibilityById } = require("%scripts/promo/promo.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { OPTIONS_MODE_MP_DOMINATION } = require("%scripts/options/optionsExtNames.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let { loadLocalByAccount, saveLocalByAccount
} = require("%scripts/clientState/localProfileDeprecated.nut")
let { getMissionsComplete } = require("%scripts/myStats.nut")
let { getCurrentGameModeEdiff } = require("%scripts/gameModes/gameModeManagerState.nut")
let { getPkgLocName, havePackage } = require("%scripts/clientState/contentPacks.nut")
let { getQueueClass } = require("%scripts/queue/queue/queueClasses.nut")
let { checkQueueAndStart, leaveQueue } = require("%scripts/queue/queueManager.nut")
let { EventJoinProcess } = require("%scripts/events/eventJoinProcess.nut")
let { create_event_description } = require("%scripts/events/eventDescription.nut")
let MRoomsList = require("%scripts/matchingRooms/mRoomsList.nut")
let { isQueueActive, findQueue, isEventQueue } = require("%scripts/queue/queueState.nut")
let { getQueueMode, getQueuePreferredViewClass } = require("%scripts/queue/queueInfo.nut")
let { canJoinFlightMsgBox } = require("%scripts/squads/squadUtils.nut")
let { profileCountrySq, switchProfileCountry } = require("%scripts/user/playerCountry.nut")
let { remove_scene_box } = require("%sqDagui/framework/msgBox.nut")
let { get_charserver_time_sec } = require("chard")

const COLLAPSED_CHAPTERS_SAVE_ID = "events_collapsed_chapters"
const ROOMS_LIST_OPEN_COUNT_SAVE_ID = "tutor/roomsListOpenCount"
const SHOW_RLIST_ASK_DELAY_DEFAULT = 10
const SHOW_RLIST_BEFORE_OPEN_DEFAULT = 10
const CHANGE_TEAM_BOX_ID = "change_team_box"








function guiStartModalEvents(options = {}) {
  if (!suggestAndAllowPsnPremiumFeatures())
    return

  if (!isMultiplayerPrivilegeAvailable.value) {
    checkAndShowMultiplayerPrivilegeWarning()
    return
  }

  if (isShowGoldBalanceWarning())
    return

  local eventId = null
  local chapterId = getTblValue ("chapter", options, null)

  if (chapterId) {
    let chapter = events.getChapter(chapterId)
    if (chapter && !chapter.isEmpty()) {
      let chapterEvents = chapter.getEvents()
      eventId = chapterEvents[0]
    }
  }

  eventId = eventId || getTblValue("event", options, null)

  if (eventId == null) {
    local lastPlayedEvent = events.getLastPlayedEvent()
    eventId = getTblValue("name", lastPlayedEvent, events.getFeaturedEvent())
    chapterId = events.getEventsChapter(events.getEvent(eventId))
  }

  loadHandler(gui_handlers.EventsHandler, {
    curEventId = eventId
    curChapterId = chapterId
    autoJoin = options?.autoJoin ?? false
  })
}

gui_handlers.EventsHandler <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName   = "%gui/events/eventsModal.blk"
  eventsListObj  = null
  curEventId     = ""
  curChapterId = ""
  autoJoin = false
  slotbarActions = ["aircraft", "crew", "sec_weapons", "weapons", "showroom",




  "repair"]

  queueToShow    = null
  skipCheckQueue = false
  queueInfoHandlerWeak = null

  eventDescription = null
  collapsedChapters = null

  canAskAboutRoomsList = true
  isQueueWasStartedWithRoomsList = false

  listMap = null
  listIdxPID = dagui_propid_add_name_id("listIdx")
  hoveredIdx  = -1
  selectedIdx = -1
  isMouseMode = true

  updateButtonsTimer = null
  joinProcessStartTime = 0
  canShowSwitchTeamBox = false

  function initScreen() {
    this.mainOptionsMode = getGuiOptionsMode()
    setGuiOptionsMode(OPTIONS_MODE_MP_DOMINATION)
    this.eventsListObj = this.scene.findObject("items_list")
    if (!checkObj(this.eventsListObj))
      return this.goBack()

    this.updateMouseMode()
    this.eventDescription = create_event_description(this.scene)
    this.skipCheckQueue = true
    this.fillEventsList()
    this.skipCheckQueue = false

    this.updateQueueInterface()
    this.updateButtons()
    this.updateClusters()

    this.scene.findObject("event_update").setUserData(this)
    this.guiScene.applyPendingChanges(false)
    move_mouse_on_child_by_value(this.eventsListObj)
  }

  
  function onItemSelect() {
    this.onItemSelectAction()
  }

  function onItemSelectAction(onlyChanged = true) {
    let curEventIdx = this.eventsListObj.getValue()
    let rowId = this.listMap?[curEventIdx]
    if (rowId == null)
      return
    let newEvent = events.getEvent(rowId)
    let newEventId = newEvent?.name ?? ""
    let newChapterId = newEvent != null ? events.getEventsChapter(newEvent) : rowId

    if (onlyChanged && newChapterId == this.curChapterId && this.curEventId == newEventId)
      return

    if (newChapterId == this.curChapterId && this.curEventId == newEventId)
      return this.updateWindow()

    this.checkQueue(function () {
        this.curChapterId = newChapterId
        this.curEventId = newEventId
        this.selectedIdx = curEventIdx
        this.updateWindow()
      },
      function() { this.selectEvent(this.curEventId) })
  }

  function updateWindow() {
    let event = events.getEvent(this.curEventId)
    let showOverrideSlotbar = needShowOverrideSlotbar(event)
    if (showOverrideSlotbar)
      updateOverrideSlotbar(events.getEventMission(this.curEventId, true), event)
    else
      resetSlotbarOverrided()
    this.createSlotbar({
      eventId = this.curEventId
      afterSlotbarSelect = this.updateButtons
      afterFullUpdate = this.updateButtons
      needPresetsPanel = !showOverrideSlotbar
      showAlwaysFullSlotbar = true
      customViewCountryData = getCustomViewCountryData(event)
      needCheckUnitUnlock = showOverrideSlotbar
    })
    this.showEventDescription(this.curEventId)
    this.updateButtons()
  }

  function selectEvent(eventId) {
    if (eventId == "" || !checkObj(this.eventsListObj))
      return false
    for (local i = 0; i < this.eventsListObj.childrenCount(); i++)
      if (this.eventsListObj.getChild(i).id == eventId) {
        this.eventsListObj.setValue(i)
        this.onItemSelectAction()
        return true
      }
    return false
  }

  function onJoinEvent() {
    this.joinEvent()
  }

  function goToBattleFromDebriefing() {
    this.joinEvent(true)
  }
  function joinEvent(isFromDebriefing = false) {
    let event = events.getEvent(this.curEventId)
    if (!event)
      return

    if (!suggestAndAllowPsnPremiumFeatures())
      return
    if (!isMultiplayerPrivilegeAvailable.value) {
      checkAndShowMultiplayerPrivilegeWarning()
      return
    }

    if (isShowGoldBalanceWarning())
      return

    this.isQueueWasStartedWithRoomsList = isEventWithLobby(event)
    let configForStatistic = {
      actionPlace = isFromDebriefing ? "debriefing" : "event_window"
      economicName = getEventEconomicName(event)
      difficulty = event?.difficulty ?? ""
      canIntoToBattle = true
      missionsComplete = getMissionsComplete()
    }

    EventJoinProcess(event, null,
      @(_event) sendBqEvent("CLIENT_BATTLE_2", "to_battle_button", configForStatistic),
      function() {
        configForStatistic.canIntoToBattle <- false
        sendBqEvent("CLIENT_BATTLE_2", "to_battle_button", configForStatistic)
      })

    this.canShowSwitchTeamBox = this.canAskAboutSwitchTeam()
    this.joinProcessStartTime = get_charserver_time_sec()
  }

  function onUpdate(_obj, _dt) {
    this.checkAskAboutSwitchTeam()
    this.checkAskOpenRoomsList()
  }

  function showSwitchTeamMsgBox() {
    this.canShowSwitchTeamBox = false
    let thisCapture = this
    let buttons = [
      [loc("ok"), @() thisCapture.changeTeam()],
      [loc("cancel"), @() null]
    ]
    let defBtn = "cancel"
    let options = {cancel_fn = @() null}
    remove_scene_box(CHANGE_TEAM_BOX_ID)
    scene_msg_box(CHANGE_TEAM_BOX_ID, null, loc("multiplayer/ask_switch_team"), buttons, defBtn, options)
  }

  function canAskAboutSwitchTeam() {
    let squadMembers = g_squad_manager.getMembers()
    let isSquadLeader = g_squad_manager.isSquadLeader()
    if (squadMembers.len() > 0 && !isSquadLeader)
      return false
    let event = events.getEvent(this.curEventId)
    if (!event?.suggestToChangeTeamOnQueueDisbalanceSec || !isTeamSizeBalancedEvent(event) || !event?.teamA || !event?.teamB)
      return false
    return true
  }

  function needSwitchTeam() {
    let event = events.getEvent(this.curEventId)
    if (this.queueToShow?.queueStats == null || this.queueToShow?.queueStats.isClanStats
      || !isTeamSizeBalancedEvent(event))
      return false

    let minTeamSize = events.getMinTeamSize(event)
    let isSquadLeader = g_squad_manager.isSquadLeader()
    let movePlayersCount = isSquadLeader ? g_squad_manager.getMembers() : 1

    let curCountry = profileCountrySq.get()
    let playerTeam = event.teamA.countries.contains(curCountry) ? "teamA" : "teamB"
    let enemyTeam = playerTeam == "teamA" ? "teamB" : "teamA"
    let queueStats = this.queueToShow.queueStats
    let clustersName = queueStats.getClusters()

    foreach (cluster in clustersName) {
      let playerTeamCount = queueStats.getPlayersCountByTeam(playerTeam, cluster) ?? 0
      let enemyTeamCount = queueStats.getPlayersCountByTeam(enemyTeam, cluster) ?? 0
      let newTeamCount = playerTeamCount - movePlayersCount
      if (newTeamCount >= minTeamSize && newTeamCount >= enemyTeamCount + movePlayersCount)
        return true
    }
    return false
  }

  function checkAskAboutSwitchTeam() {
    if (!this.isInEventQueue() || !this.canShowSwitchTeamBox)
      return
    let event = events.getEvent(this.curEventId)
    let suggestToChangeTeamTimeExpired = this.joinProcessStartTime + event.suggestToChangeTeamOnQueueDisbalanceSec <= get_charserver_time_sec()
    if (suggestToChangeTeamTimeExpired)
      if (this.needSwitchTeam())
        this.showSwitchTeamMsgBox()
      else
        this.canShowSwitchTeamBox = false
  }

  function changeTeam() {
    if (this.isInEventQueue())
      this.onLeaveEvent()

    let event = events.getEvent(this.curEventId)
    let curCountry = profileCountrySq.get()
    let newTeam = event.teamA.countries.contains(curCountry) ? event.teamB : event.teamA
    let newCountry = newTeam.countries[0]
    switchProfileCountry(newCountry)
    this.joinEvent()
    this.canShowSwitchTeamBox = false
  }

  function checkAskOpenRoomsList() {
    if (!this.canAskAboutRoomsList
        || !this.isQueueWasStartedWithRoomsList
        || !this.queueToShow)
      return

    let eventRoomsListCfgBlk = GUI.get()?.eventRoomsList

    let delay = eventRoomsListCfgBlk?.timeToAskShowRoomsListSec ?? SHOW_RLIST_ASK_DELAY_DEFAULT
    if (this.queueToShow.getActiveTime() < delay)
      return

    let maxCount = eventRoomsListCfgBlk?.askBeforeOpenCount ?? SHOW_RLIST_BEFORE_OPEN_DEFAULT
    if (maxCount < loadLocalAccountSettings(ROOMS_LIST_OPEN_COUNT_SAVE_ID, 0)) {
      this.canAskAboutRoomsList = false
      return
    }

    let economicName = getEventEconomicName(events.getEvent(this.curEventId))
    let roomsListData = MRoomsList.getMRoomsListByRequestParams({ eventEconomicName = economicName })
    if (!roomsListData.getList().len())
      return

    this.canAskAboutRoomsList = false
    gui_handlers.InfoWnd.openChecked({
      checkId = "askOpenRoomsList"
      header = loc("multiplayer/hint")
      message = loc("multiplayer/rooms_list/askToOpen")
      buttons = [
        {
          text = "#multiplayer/rooms_list"
          shortcut = "A"
          onClick = this.onRoomsList
        }
      ]
      buttonsContext = this
      canCloseByEsc = false
    })
  }

  function onLeaveEvent() {
    if (!canJoinFlightMsgBox({ isLeaderCanJoin = true, msgId = "squad/only_leader_can_cancel" },
                                             Callback(this.onLeaveEventActions, this)))
      return
    else
      this.onLeaveEventActions()
  }

  function getCurEventQueue() {
    let q = findQueue({}, QUEUE_TYPE_BIT.EVENT)
    return (q && isQueueActive(q)) ? q : null
  }

  function isInEventQueue() {
    return this.queueToShow != null  
  }

  function onLeaveEventActions() {
    remove_scene_box(CHANGE_TEAM_BOX_ID)
    let q = this.getCurEventQueue()
    if (!q)
      return

    leaveQueue(q, { isCanceledByPlayer = true })
  }

  function onEventQueueChangeState(p) {
    if (!isEventQueue(p?.queue))
      return

    this.updateQueueInterface()

    if (this.isInEventQueue())
      this.hoveredIdx = -1
    else
      move_mouse_on_child_by_value(this.eventsListObj)

    this.updateButtons()
  }

  function onEventAfterJoinEventRoom(_event) {
    handlersManager.requestHandlerRestore(this, gui_handlers.MainMenu)
  }

  function backPointerToPrevHoveredItem() {
    if (!this.eventsListObj || !this.eventsListObj.isValid() || this.hoveredIdx == -1)
      return
    move_mouse_on_child(this.eventsListObj, this.hoveredIdx)
  }

  function onOpenClusterSelect(obj) {
    let params = {
      align = ALIGN.BOTTOM
      callbackOnClose = Callback(@() this.backPointerToPrevHoveredItem(), this)
    }

    checkQueueAndStart(
      Callback(@() openClustersMenuWnd(obj, params), this),
      null,
      "isCanChangeCluster")
  }

  function onEventEventsDataUpdated(_params) {
    this.fillEventsList()
  }

  function onEventClusterChange(_params) {
    this.updateClusters()
  }

  function updateClusters() {
    clustersModule.updateClusters(this.scene.findObject("cluster_select_button"))
  }

  function goBack() {
    this.checkedForward(base.goBack)
  }

  function goBackShortcut() {
    if (this.isInEventQueue())
      this.onLeaveEvent()
    else
      this.goBack()
  }

  function checkQueue(func, cancelFunc = null) {
    if (this.skipCheckQueue)
      return func()

    this.checkedModifyQueue(QUEUE_TYPE_BIT.EVENT, func, cancelFunc)
  }

  function restoreQueueParams() {
    if (!this.queueToShow || !checkObj(this.scene))
      return

    this.skipCheckQueue = true
    this.selectEvent(getQueueMode(this.queueToShow))
    this.skipCheckQueue = false
  }

  function onItemDblClick() {
    if (showConsoleButtons.get())
      return

    if (this.curEventId == "") {
      this.collapseChapter(this.curChapterId)
      this.updateButtons()
    }
    else
      this.joinEvent()
  }

  function onItemHover(obj) {
    if (!showConsoleButtons.get())
      return
    let isHover = obj.isHovered()
    let idx = obj.getIntProp(this.listIdxPID, -1)
    if (isHover == (this.hoveredIdx == idx))
      return
    this.hoveredIdx = isHover ? idx : -1
    this.updateMouseMode()
    this.updateButtons()
  }

  function onHoveredItemSelect(_obj) {
    if (this.hoveredIdx != -1 && checkObj(this.eventsListObj))
      this.eventsListObj.setValue(this.hoveredIdx)
  }

  function updateMouseMode() {
    this.isMouseMode = !showConsoleButtons.get() || is_mouse_last_time_used()
  }

  function onEventSquadStatusChanged(_params) {
    this.updateButtons()
  }

  function onEventSquadSetReady(_params) {
    this.updateButtons()
  }

  function onEventSquadDataUpdated(_p) {
    this.updateButtons()
  }

  function onDestroy() {
    remove_scene_box(CHANGE_TEAM_BOX_ID)
    seenEvents.markSeen(events.getEventsForEventsWindow())
    resetSlotbarOverrided()
  }

  function getHandlerRestoreData() {
    return {
      openData = { curEventId = this.curEventId }
    }
  }

  function onRoomsList() {
    gui_handlers.EventRoomsHandler.open(events.getEvent(this.curEventId), true)
    this.canAskAboutRoomsList = false
    saveLocalAccountSettings(ROOMS_LIST_OPEN_COUNT_SAVE_ID,
      loadLocalAccountSettings(ROOMS_LIST_OPEN_COUNT_SAVE_ID, 0) + 1)
  }

  function onDownloadPack() {
    checkEventFeaturePacks(events.getEvent(this.curEventId))
  }

  function onQueueOptions(obj) {
    let optionsData = getQueueClass("Event").getOptions(this.curEventId)
    if (!optionsData)
      return

    let params = {
      options = optionsData.options
      optionsConfig = optionsData.context
      wndOptionsMode = OPTIONS_MODE_MP_DOMINATION
      wndGameMode = GM_DOMINATION
      align = ALIGN.TOP
      alignObj = obj
      columnsRatio = 0.6
    }
    loadHandler(gui_handlers.FramedOptionsWnd, params)
  }

  function onCreateRoom() {}
  onShowOnlyAvailableRooms = @() null

  

  
  function showEventDescription(eventId) {
    let event = events.getEvent(eventId)
    this.eventDescription.selectEvent(event)
    if (event != null)
      seenEvents.markSeen(event.name)
  }

  function onEventItemBought(params) {
    let item = getTblValue("item", params)
    if (item && item.isForEvent(this.curEventId))
      this.updateButtons()
  }

  function checkQueueInfoBox() {
    if (!this.queueToShow || handlersManager.isHandlerValid(this.queueInfoHandlerWeak))
      return

    let queueObj = showObjById("div_before_chapters_list", true, this.scene)
    queueObj.height = "ph"
    let queueHandlerClass = this.queueToShow && getQueuePreferredViewClass(this.queueToShow)
    let queueHandler = loadHandler(queueHandlerClass, {
      scene = queueObj,
      leaveQueueCb = Callback(this.onLeaveEvent, this)
    })
    this.registerSubHandler(queueHandler)
    this.queueInfoHandlerWeak = queueHandler
  }

  function updateQueueInterface() {
    if (!this.queueToShow || !isQueueActive(this.queueToShow))
      this.queueToShow = this.getCurEventQueue()
    this.checkQueueInfoBox()
    this.restoreQueueParams()
    this.scene.findObject("chapters_list_place").show(!this.isInEventQueue())
    let slotbar = this.getSlotbar()
    if (slotbar)
      slotbar.shade(this.isInEventQueue())
  }

  function scheduleUpdateButtonsIfNeeded(event) {
    clearTimer(this.updateButtonsTimer)

    local time = events.getEventStartTime(event)
    if (time <= 0)
      time = events.getEventEndTime(event)
    if (time <= 0)
      return

    let cb = Callback(@() this.updateButtons(), this)
    this.updateButtonsTimer = setTimeout(time, @() cb())
  }

  function updateButtons() {
    let event = events.getEvent(this.curEventId)
    let isEvent = event != null
    let isHeader = this.curChapterId != "" && this.curEventId == ""
    let isInQueue = this.isInEventQueue()

    let isCurItemInFocus = (isEvent || isHeader) && (this.isMouseMode || this.hoveredIdx == this.selectedIdx || isInQueue)

    let reasonData = events.getCantJoinReasonData(isCurItemInFocus ? event : null)
    let isReady = g_squad_manager.isMeReady()
    let isSquadMember = g_squad_manager.isSquadMember()

    this.scheduleUpdateButtonsIfNeeded(event)
    showObjById("btn_select_console", !isCurItemInFocus && (isEvent || isHeader), this.scene)

    let showJoinBtn = isCurItemInFocus && (isEvent && (!isInQueue || (isSquadMember && !isReady)))
    let joinButtonObj = this.scene.findObject("btn_join_event")
    joinButtonObj.show(showJoinBtn)
    joinButtonObj.enable(showJoinBtn)
    joinButtonObj.inactiveColor = (reasonData.activeJoinButton && !isInQueue)
                                  ? "no"
                                  : "yes"
    joinButtonObj.tooltip = isSquadMember ? reasonData.reasonText : ""
    local startText = "events/join_event"
    if (isSquadMember)
      startText = isReady ? "multiplayer/btnNotReady" : "mainmenu/btnReady"
    startText = loc(startText)

    
    local uncoloredStartText = startText

    let battlePriceText = events.getEventBattleCostText(event, "activeTextColor", true, true)
    if (battlePriceText.len() > 0) {
      startText = "".concat(startText, format(" (%s)", battlePriceText))
      uncoloredStartText = "".concat(
        uncoloredStartText,
        format(" (%s)", events.getEventBattleCostText(event, "activeTextColor", true, false))
      )
    }

    setDoubleTextToButton(this.scene, "btn_join_event", uncoloredStartText, startText)
    let leaveButtonObj = this.scene.findObject("btn_leave_event")
    leaveButtonObj.show(isInQueue)
    leaveButtonObj.enable(isInQueue)

    let isShowCollapseBtn = isCurItemInFocus && isHeader
    let collapsedButtonObj = showObjById("btn_collapsed_chapter", isShowCollapseBtn, this.scene)
    if (isShowCollapseBtn) {
      let isCollapsedChapter = this.getCollapsedChapters()?[this.curChapterId]
      startText = loc(isCollapsedChapter ? "mainmenu/btnExpand" : "mainmenu/btnCollapse")
      collapsedButtonObj.setValue(startText)
    }

    let reasonTextObj = this.scene.findObject("cant_join_reason")
    reasonTextObj.setValue(reasonData.reasonText)
    reasonTextObj.show(reasonData.reasonText.len() > 0 && !isInQueue)

    showObjById("btn_rooms_list", isCurItemInFocus && isEvent && isEventWithLobby(event), this.scene)

    let pack = isCurItemInFocus && isEvent ? getEventReqPack(event, true) : null
    let needDownloadPack = pack != null && !havePackage(pack)
    let packBtn = showObjById("btn_download_pack", needDownloadPack, this.scene)
    if (needDownloadPack && packBtn) {
      packBtn.tooltip = getPkgLocName(pack)
      packBtn.setValue(" ".concat(loc("msgbox/btn_download"), getPkgLocName(pack, true)))
    }

    showObjById("btn_queue_options", isCurItemInFocus && isEvent
      && getQueueClass("Event").hasOptions(event.name), this.scene)
  }

  function fillEventsList() {
    let chapters = events.getChapters()
    let needSkipCrossplayEvent = isPlatformSony && !isCrossPlayEnabled()

    let view = { items = [] }
    foreach (chapter in chapters) {
      let eventItems = []
      foreach (eventName in chapter.getEvents()) {
        let event = events.getEvent(eventName)
        if (needSkipCrossplayEvent && !isEventPlatformOnlyAllowed(event))
          continue

        eventItems.append({
          itemIcon = events.getDifficultyImg(eventName)
          id = eventName
          itemText = this.getEventNameForListBox(event)
          unseenIcon = bhvUnseen.makeConfigStr(SEEN.EVENTS, eventName)
          isNeedOnHover = showConsoleButtons.get()
        })
      }

      if (eventItems.len() > 0)
        eventItems.insert(0, {
          itemTag = "campaign_item"
          id = chapter.name
          itemText = chapter.getLocName()
          isCollapsable = true
          isNeedOnHover = showConsoleButtons.get()
        })

      view.items.extend(eventItems)
    }

    let data = handyman.renderCached("%gui/missions/missionBoxItemsList.tpl", view)
    this.guiScene.replaceContentFromText(this.eventsListObj, data, data.len(), this)
    for (local i = 0; i < this.eventsListObj.childrenCount(); i++)
      this.eventsListObj.getChild(i).setIntProp(this.listIdxPID, i)

    let cId = this.curEventId
    this.listMap = view.items.map(@(v) v.id)
    this.selectedIdx = this.listMap.findindex(@(rowId) rowId == cId) ?? 0

    if (this.selectedIdx <= 0) {
      this.selectedIdx = 1 
      this.curEventId = "" 
      this.curChapterId = ""
    }
    else if(this.autoJoin)
      this.joinEvent()

    this.eventsListObj.setValue(this.selectedIdx)
    this.onItemSelectAction(false)

    eachParam(this.getCollapsedChapters(), @(_, chapterId) this.collapseChapter(chapterId), this)
  }

  function getEventNameForListBox(event) {
    local text = events.getEventNameText(event)
    if (needShowCrossPlayInfo()) {
      let isPlatformOnlyAllowed = isEventPlatformOnlyAllowed(event)
      text = getTextWithCrossplayIcon(!isPlatformOnlyAllowed, text)
      if (!isPlatformOnlyAllowed && !isCrossPlayEnabled())
        text = colorize("warningTextColor", text)
    }

    if (events.isEventEnded(event))
      text = colorize("oldTextColor", text)

    return text
  }

  function getCurrentEdiff() {
    let event = events.getEvent(this.curEventId)
    let ediff = event ? events.getEDiffByEvent(event) : -1
    return ediff != -1 ? ediff : getCurrentGameModeEdiff()
  }

  function onEventCountryChanged(_p) {
    this.updateButtons()
  }

  function onCollapse(obj) {
    if (!obj?.id)
      return
    this.collapseChapter(cutPrefix(obj.id, "btn_", obj.id)) 
    this.updateButtons()
  }

  function onCollapsedChapter() {
    this.collapseChapter(this.curChapterId)
    this.updateButtons()
  }

  function collapseChapter(chapterId) {
    let chapterObj = this.eventsListObj.findObject(chapterId)
    if (! chapterObj)
      return
    let collapsed = chapterObj.collapsed == "yes"
    let curChapter = events.getChapter(chapterId)
    if (! curChapter)
      return
    foreach (eventName in curChapter.getEvents()) {
      let eventObj = this.eventsListObj.findObject(eventName)
      if (! checkObj(eventObj))
        continue
      eventObj.show(collapsed)
      eventObj.enable(collapsed)
    }

    if (chapterId == this.curChapterId) {
      let chapters = events.getChapters()
      local totalRows = -1
      foreach (chapter in chapters)
        if (chapter.getEvents().len() > 0) {
          totalRows++
          if (chapter.name == this.curChapterId) {
            this.eventsListObj.setValue(totalRows)
            break
          }

          totalRows += chapter.getEvents().len();
        }
    }

    chapterObj.collapsed = collapsed ? "no" : "yes"
    this.getCollapsedChapters()[chapterId] = collapsed ? null : true
    saveLocalByAccount(COLLAPSED_CHAPTERS_SAVE_ID, this.getCollapsedChapters())
  }

  function getCollapsedChapters() {
    if (this.collapsedChapters == null)
      this.collapsedChapters = loadLocalByAccount(COLLAPSED_CHAPTERS_SAVE_ID, DataBlock())
    return this.collapsedChapters
  }
  
}

function openEventsWndFromPromo(owner, params = []) {
  let eventId = params.len() > 0 ? params[0] : null
  owner.checkedForward(@() this.goForwardIfOnline(
    @() guiStartModalEvents({ event = eventId }), false, true))
}

let getEventsPromoText = @() events.getEventsVisibleInEventsWindowCount() == 0
  ? loc("mainmenu/events/eventlist_btn_no_active_events")
  : loc("mainmenu/btnTournamentsAndEvents")

addPromoAction("events", @(handler, params, _obj) openEventsWndFromPromo(handler, params))

let promoButtonId = "events_mainmenu_button"

addPromoButtonConfig({
  promoButtonId = promoButtonId
  getText = getEventsPromoText
  collapsedIcon = loc("icon/events")
  getCustomSeenId = @() bhvUnseen.makeConfigStr(SEEN.EVENTS, SEEN.S_EVENTS_WINDOW)
  updateFunctionInHandler = function() {
    let id = promoButtonId
    local buttonObj = null
    local show = this.isShowAllCheckBoxEnabled()
    if (show)
      buttonObj = showObjById(id, show, this.scene)
    else {
      show = hasFeature("Events")
        && events.getEventsVisibleInEventsWindowCount()
        && isMultiplayerPrivilegeAvailable.value
        && getPromoVisibilityById(id)
      buttonObj = showObjById(id, show, this.scene)
    }

    if (!show || !checkObj(buttonObj))
      return

    setPromoButtonText(buttonObj, id, getEventsPromoText())
  }
  updateByEvents = ["EventsDataUpdated", "MyStatsUpdated", "UnlockedCountriesUpdate"]
})

return {
  guiStartModalEvents
}
