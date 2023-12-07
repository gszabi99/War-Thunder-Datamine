//-file:plus-string
from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { Cost } = require("%scripts/money.nut")
let { shouldShowDynamicLutPopUpMessage, setIsUsingDynamicLut, getTonemappingMode, setTonemappingMode } = require("postFxSettings")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { handlersManager, get_cur_base_gui_handler, loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { format } = require("string")
let DataBlock = require("DataBlock")
let daguiFonts = require("%scripts/viewUtils/daguiFonts.nut")
let tutorialModule = require("%scripts/user/newbieTutorialDisplay.nut")
let crossplayModule = require("%scripts/social/crossplay.nut")
let { recentBR } = require("%scripts/battleRating.nut")
let clanVehiclesModal = require("%scripts/clans/clanVehiclesModal.nut")
let antiCheat = require("%scripts/penitentiary/antiCheat.nut")
let changeStartMission = require("%scripts/missions/changeStartMission.nut")
let { topMenuHandler } = require("%scripts/mainmenu/topMenuStates.nut")
let RB_GM_TYPE = require("%scripts/gameModes/rbGmTypes.nut")
let tutorAction = require("%scripts/tutorials/tutorialActions.nut")
let QUEUE_TYPE_BIT = require("%scripts/queue/queueTypeBit.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { checkDiffTutorial } = require("%scripts/tutorials/tutorialsData.nut")
let { suggestAndAllowPsnPremiumFeatures } = require("%scripts/user/psnFeatures.nut")
let { checkNuclearEvent } = require("%scripts/matching/serviceNotifications/nuclearEventHandler.nut")
let { showMsgboxIfSoundModsNotAllowed } = require("%scripts/penitentiary/soundMods.nut")
let { getToBattleLocIdShort } = require("%scripts/viewUtils/interfaceCustomization.nut")
let { needShowChangelog,
  openChangelog, requestAllPatchnotes } = require("%scripts/changelog/changeLogState.nut")
let { isCountrySlotbarHasUnits, getSelAircraftByCountry, getCurSlotbarUnit,
  isCountryAllCrewsUnlockedInHangar, getCrewByAir
} = require("%scripts/slotbar/slotbarState.nut")
let { getShowedUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { initBackgroundModelHint, placeBackgroundModelHint
} = require("%scripts/hangar/backgroundModelHint.nut")
let { checkAndShowMultiplayerPrivilegeWarning, checkAndShowCrossplayWarning,
  isMultiplayerPrivilegeAvailable } = require("%scripts/user/xboxFeatures.nut")
let { isHaveNonApprovedClanUnitResearches } = require("%scripts/unit/squadronUnitAction.nut")
let { showViralAcquisitionWnd } = require("%scripts/user/viralAcquisition.nut")
let time = require("%scripts/time.nut")
let { LEADER_OPERATION_STATES,
  getLeaderOperationState } = require("%scripts/squads/leaderWwOperationStates.nut")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { isShowGoldBalanceWarning } = require("%scripts/user/balanceFeatures.nut")
let { setGuiOptionsMode, getGuiOptionsMode } = require("guiOptions")
let { select_mission, get_meta_mission_info_by_name } = require("guiMission")
let { sendBqEvent } = require("%scripts/bqQueue/bqQueue.nut")
let tryOpenCaptchaHandler = require("%scripts/captcha/captchaHandler.nut")
let { isPlatformShieldTv } = require("%scripts/clientState/platform.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { OPTIONS_MODE_MP_DOMINATION, USEROPT_COUNTRY } = require("%scripts/options/optionsExtNames.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let { getEsUnitType } = require("%scripts/unit/unitInfo.nut")
let { get_game_settings_blk } = require("blkGetters")
let { getEventEconomicName } = require("%scripts/events/eventInfo.nut")
let { checkSquadUnreadyAndDo } = require("%scripts/squads/squadUtils.nut")
let newIconWidget = require("%scripts/newIconWidget.nut")
let { openClanRequestsWnd } = require("%scripts/clans/clanRequestsModal.nut")
let { isCountryAvailable } = require("%scripts/firstChoice/firstChoice.nut")

gui_handlers.InstantDomination <- class (gui_handlers.BaseGuiHandlerWT) {
  static keepLoaded = true

  sceneBlkName = "%gui/mainmenu/instantAction.blk"

  toBattleButtonObj = null
  gameModeChangeButtonObj = null
  newGameModesWidgetsPlaceObj = null
  inited = false
  wndGameMode = GM_DOMINATION
  startEnabled = false
  queueMask = QUEUE_TYPE_BIT.DOMINATION | QUEUE_TYPE_BIT.NEWBIE

  curQueue = null
  function getCurQueue() { return this.curQueue }
  function setCurQueue(value) {
    this.curQueue = value
    if (value != null) {
      this.initQueueTableHandler()
      this.restoreQueueParams()
    }
  }

  curCountry = ""
  function getCurCountry() { return this.curCountry }
  function setCurCountry(value) {
    this.curCountry = value
  }

  gamercardDrawerHandler = null
  function getGamercardDrawerHandler() {
    if (!handlersManager.isHandlerValid(this.gamercardDrawerHandler))
      this.initGamercardDrawerHandler()
    if (handlersManager.isHandlerValid(this.gamercardDrawerHandler))
      return this.gamercardDrawerHandler
    assert(false, "Failed to get gamercardDrawerHandler.")
    return null
  }

  queueTableHandler = null
  function getQueueTableHandler() {
    if (!handlersManager.isHandlerValid(this.queueTableHandler))
      this.initQueueTableHandler()
    if (handlersManager.isHandlerValid(this.queueTableHandler))
      return this.queueTableHandler
    assert(false, "Failed to get queueTableHandler.")
    return null
  }

  newGameModeIconWidget = null
  slotbarPresetsTutorial = null

  function initScreen() {
    // Causes drawer to initialize once.
    this.getGamercardDrawerHandler()

    this.mainOptionsMode = getGuiOptionsMode()
    setGuiOptionsMode(OPTIONS_MODE_MP_DOMINATION)

    this.initToBattleButton()
    this.setCurrentGameModeName()

    this.setCurQueue(::queues.findQueue({}, this.queueMask))

    this.updateStartButton()

    this.inited = true
    ::dmViewer.update()
    initBackgroundModelHint(this)
    requestAllPatchnotes()
  }

  function reinitScreen(_params) {
    this.inited = false
    this.initScreen()
  }

  function canShowDmViewer() {
    return this.getCurQueue() == null
  }

  function initQueueTableHandler() {
    if (handlersManager.isHandlerValid(this.queueTableHandler))
      return

    let drawer = this.getGamercardDrawerHandler()
    if (drawer == null)
      return

    let queueTableContainer = drawer.scene.findObject("queue_table_container")
    if (queueTableContainer == null)
      return

    let params = {
      scene = queueTableContainer
      queueMask = this.queueMask
    }
    this.queueTableHandler = loadHandler(gui_handlers.QueueTable, params)
  }

  function initGamercardDrawerHandler() {
    if (topMenuHandler.value == null)
      return

    let gamercardPanelCenterObject = topMenuHandler.value.scene.findObject("gamercard_panel_center")
    if (gamercardPanelCenterObject == null)
      return
    gamercardPanelCenterObject.show(true)
    gamercardPanelCenterObject.enable(true)

    let gamercardDrawerContainer = topMenuHandler.value.scene.findObject("gamercard_drawer_container")
    if (gamercardDrawerContainer == null)
      return

    let params = {
      scene = gamercardDrawerContainer
    }
    this.gamercardDrawerHandler = loadHandler(gui_handlers.GamercardDrawer, params)
    this.registerSubHandler(this.gamercardDrawerHandler)
  }

  function initToBattleButton() {
    if (!this.rootHandlerWeak)
      return

    let centeredPlaceObj = showObjById("gamercard_center", true, this.rootHandlerWeak.scene)
    if (!centeredPlaceObj)
      return

    let toBattleNest = showObjById("gamercard_tobattle", true, this.rootHandlerWeak.scene)
    if (toBattleNest) {
      this.rootHandlerWeak.scene.findObject("top_gamercard_bg").needRedShadow = "no"
      let toBattleBlk = handyman.renderCached("%gui/mainmenu/toBattleButton.tpl", {
        enableEnterKey = !isPlatformShieldTv()
      })
      this.guiScene.replaceContentFromText(toBattleNest, toBattleBlk, toBattleBlk.len(), this)
      this.toBattleButtonObj = this.rootHandlerWeak.scene.findObject("to_battle_button")
      this.rootHandlerWeak.scene.findObject("gamercard_tobattle_bg")["background-color"] = "#00000000"
    }
    this.rootHandlerWeak.scene.findObject("gamercard_logo").show(false)
    this.gameModeChangeButtonObj = this.rootHandlerWeak.scene.findObject("game_mode_change_button")

    if (!hasFeature("GameModeSelector")) {
      this.gameModeChangeButtonObj.show(false)
      this.gameModeChangeButtonObj.enable(false)
    }

    this.newGameModesWidgetsPlaceObj = this.rootHandlerWeak.scene.findObject("new_game_modes_widget_place")
    this.updateUnseenGameModesCounter()
  }

  _lastGameModeId = null
  function setGameMode(modeId) {
    let gameMode = ::game_mode_manager.getGameModeById(modeId)
    if (gameMode == null || modeId == this._lastGameModeId)
      return
    this._lastGameModeId = modeId

    this.onCountrySelectAction() //bad function naming. Actually this function validates your units and selected country for new mode
    this.setCurrentGameModeName()
    this.reinitSlotbar()
  }

  function setCurrentGameModeName() {
    if (!checkObj(this.gameModeChangeButtonObj))
      return

    local name = ""

    if (isMultiplayerPrivilegeAvailable.value) {
      let gameMode = ::game_mode_manager.getCurrentGameMode()
      let br = recentBR.value
      name = gameMode && gameMode?.text != ""
        ? gameMode.text + (br > 0 ? loc("mainmenu/BR", { br = format("%.1f", br) }) : "") : ""

      if (::g_squad_manager.isSquadMember() && ::g_squad_manager.isMeReady()) {
        let gameModeId = ::g_squad_manager.getLeaderGameModeId()
        let event = ::events.getEvent(gameModeId)
        let leaderBR = ::g_squad_manager.getLeaderBattleRating()
        if (event)
          name = ::events.getEventNameText(event)
        if (leaderBR > 0)
          name += loc("mainmenu/BR", { br = format("%.1f", leaderBR) })
      }
    }
    else
      name = loc("xbox/noMultiplayer")

    this.gameModeChangeButtonObj.findObject("game_mode_change_button_text").setValue(
      name != "" ? name : loc("mainmenu/gamemodesNotLoaded")
    )
  }

  function updateUnseenGameModesCounter() {
    if (!checkObj(this.newGameModesWidgetsPlaceObj))
      return

    if (!this.newGameModeIconWidget)
      this.newGameModeIconWidget = newIconWidget(this.guiScene, this.newGameModesWidgetsPlaceObj)

    this.newGameModeIconWidget.setValue(::game_mode_manager.getUnseenGameModeCount())
  }

  function goToBattleFromDebriefing() {
    this.determineAndStartAction(true)
  }

  function onEventShowingGameModesUpdated(_params) {
    this.updateUnseenGameModesCounter()
  }

  function onEventMyStatsUpdated(_params) {
    this.setCurrentGameModeName()
    this.doWhenActiveOnce("checkNoviceTutor")
    this.updateStartButton()
  }

  function onEventCrewTakeUnit(_params) {
    this.doWhenActiveOnce("onCountrySelectAction")
  }

  function onEventSlotbarPresetLoaded(params) {
    if (getTblValue("crewsChanged", params, true))
      this.doWhenActiveOnce("onCountrySelectAction")
  }

  function onEventSquadSetReady(_params) {
    this.doWhenActiveOnce("updateStartButton")
  }

  function onEventSquadStatusChanged(_params) {
    this.doWhenActiveOnce("updateStartButton")
  }

  function onEventCrewChanged(_params) {
    this.doWhenActiveOnce("checkCountries")
  }

  function onEventCheckClientUpdate(params) {
    if (!checkObj(this.scene))
      return

    let obj = this.scene.findObject("update_avail")
    if (!checkObj(obj))
      return

    obj.show(getTblValue("update_avail", params, false))
  }

  function onEventNewClientVersion(params) {
    this.doWhenActive(@() checkNuclearEvent(params))
  }

  function checkCountries() {
    this.onCountrySelectAction()
    return
  }

  function onEventQueueChangeState(p) {
    let _queue = p?.queue
    if (!::queues.checkQueueType(_queue, this.queueMask))
      return
    this.setCurQueue(::queues.isQueueActive(_queue) ? _queue : null)
    this.updateStartButton()
    ::dmViewer.update()
  }

  function onEventCurrentGameModeIdChanged(_params) {
    this.setGameMode(::game_mode_manager.getCurrentGameModeId())
    this.updateNoticeGMChanged()
  }

  function onEventGameModesUpdated(_params) {
    this.setGameMode(::game_mode_manager.getCurrentGameModeId())
    this.updateUnseenGameModesCounter()
    this.guiScene.performDelayed(this, function() {
      if (!this.isValid())
        return
      this.doWhenActiveOnce("checkNewUnitTypeToBattleTutor")
    })
  }

  function onCountrySelect() {
    this.checkQueue(this.onCountrySelectAction)
  }

  function onCountrySelectAction() {
    if (!checkObj(this.scene))
      return
    let currentGameMode = ::game_mode_manager.getCurrentGameMode()
    if (currentGameMode == null)
      return
    let multiSlotEnabled = this.isCurrentGameModeMultiSlotEnabled()
    this.setCurCountry(profileCountrySq.value)
    let countryEnabled = isCountryAvailable(this.getCurCountry())
      && ::events.isCountryAvailable(
          ::game_mode_manager.getGameModeEvent(currentGameMode),
          this.getCurCountry()
        )
    let crewsGoodForMode = this.testCrewsForMode(this.getCurCountry())
    let currentUnitGoodForMode = this.testCurrentUnitForMode(this.getCurCountry())
    let requiredUnitsAvailable = this.checkRequiredUnits(this.getCurCountry())
    this.startEnabled = countryEnabled && requiredUnitsAvailable && ((!multiSlotEnabled && currentUnitGoodForMode) || (multiSlotEnabled && crewsGoodForMode))
  }

  function getQueueAircraft(country) {
    let queue = this.getCurQueue()
    let slots = queue == null ? null : ::queues.getQueueSlots(queue)
    if (slots && (country in slots)) {
      foreach (_cIdx, c in ::g_crews_list.get())
        if (c.country == country)
          return ::g_crew.getCrewUnit(country.crews?[slots[country]])
      return null
    }
    return getSelAircraftByCountry(country)
  }

  function onTopMenuGoBack(checkTopMenuButtons = false) {
    if (!this.getCurQueue() && ::g_squad_manager.isSquadMember() && ::g_squad_manager.isMeReady())
      return ::g_squad_manager.setReadyFlag()

    if (this.leaveCurQueue({ isLeaderCanJoin = true
      msgId = "squad/only_leader_can_cancel"
      isCanceledByPlayer = true }))
      return

    if (checkTopMenuButtons && topMenuHandler.value?.leftSectionHandlerWeak != null) {
      topMenuHandler.value.leftSectionHandlerWeak.switchMenuFocus()
      return
    }
  }

  _isToBattleAccessKeyActive = true
  function setToBattleButtonAccessKeyActive(value) {
    if (value == this._isToBattleAccessKeyActive)
      return
    if (this.toBattleButtonObj == null)
      return

    this._isToBattleAccessKeyActive = value
    this.toBattleButtonObj.enable(value)
    let consoleImageObj = this.toBattleButtonObj.findObject("to_battle_console_image")
    if (checkObj(consoleImageObj))
      consoleImageObj.show(value && showConsoleButtons.value)
  }

  function startManualMission(manualMission) {
    let missionBlk = DataBlock()
    missionBlk.setFrom(get_meta_mission_info_by_name(manualMission.name))
    foreach (name, value in manualMission)
      if (name != "name")
        missionBlk[name] <- value
    select_mission(missionBlk, false)
    ::current_campaign_mission = missionBlk.name
    this.guiScene.performDelayed(this, function() { this.goForward(::gui_start_flight) })
  }

  function onStart() {
    if (!suggestAndAllowPsnPremiumFeatures())
      return

    if (!isMultiplayerPrivilegeAvailable.value) {
      checkAndShowMultiplayerPrivilegeWarning()
      return
    }

    if (isShowGoldBalanceWarning())
      return

    if (!::g_squad_manager.isMeReady())
      ::game_mode_manager.setUserGameModeId(::game_mode_manager.getCurrentGameModeId())

    this.determineAndStartAction()
  }

  function onEventSquadDataUpdated(_params) {
    if (::g_squad_manager.isSquadLeader())
      return

    if (::g_squad_manager.isMeReady()) {
      let id = ::g_squad_manager.getLeaderGameModeId()
      if (id == "" || id == ::game_mode_manager.getCurrentGameModeId())
        this.updateNoticeGMChanged()
      else
        ::game_mode_manager.setLeaderGameMode(id)
    }
    else {
      let id = ::game_mode_manager.getUserGameModeId()
      if (id && id != "")
        ::game_mode_manager.setCurrentGameModeById(id, true)
    }
    this.setCurrentGameModeName()
    this.doWhenActiveOnce("updateStartButton")
  }

  onEventOperationInfoUpdated = @(_) this.doWhenActiveOnce("updateStartButton")

  function setSquadReadyFlag() {
    if (getLeaderOperationState() == LEADER_OPERATION_STATES.OUT) {
      //No need to check broken units when set unready
      if (!::g_squad_manager.isMeReady()) {
        let leaderEvent = ::events.getEvent(::g_squad_manager.getLeaderGameModeId())
        if (leaderEvent == null) { //not found game mode of leader, skip check broken units
          ::g_squad_manager.setReadyFlag()
          return
        }
        let repairInfo = ::events.getCountryRepairInfo(leaderEvent, null, profileCountrySq.value)
        ::checkBrokenAirsAndDo(repairInfo, this, @() ::g_squad_manager.setReadyFlag(), false)
        return
      }
      ::g_squad_manager.setReadyFlag()
    }
    else if (::is_worldwar_enabled())
      this.guiScene.performDelayed(this, @() ::g_world_war.joinOperationById(
        ::g_squad_manager.getWwOperationId(), ::g_squad_manager.getWwOperationCountry()))
  }

  function determineAndStartAction(isFromDebriefing = false) {
    if (changeStartMission) {
      this.startManualMission(changeStartMission)
      return
    }

    if (::g_squad_manager.isSquadMember()) {
      if(!::g_squad_manager.isMeReady()) {
        let callback = Callback(@() this.setSquadReadyFlag(), this)
        tryOpenCaptchaHandler(callback)
        return
      }
      this.setSquadReadyFlag()
      return
    }

    if (this.leaveCurQueue({ isLeaderCanJoin = true, isCanceledByPlayer = true }))
      return

    let curGameMode = ::game_mode_manager.getCurrentGameMode()
    let event = ::game_mode_manager.getGameModeEvent(curGameMode)
    if (!antiCheat.showMsgboxIfEacInactive(event) || !showMsgboxIfSoundModsNotAllowed(event))
      return

    if (!this.isCrossPlayEventAvailable(event)) {
      checkAndShowCrossplayWarning(@() showInfoMsgBox(loc("xbox/actionNotAvailableCrossNetworkPlay")))
      return
    }

    if ("onBattleButtonClick" in curGameMode)
      return curGameMode.onBattleButtonClick()

    let configForStatistic = {
      actionPlace = isFromDebriefing ? "debriefing" : "hangar"
      economicName = getEventEconomicName(event)
      difficulty = event?.difficulty ?? ""
      canIntoToBattle = true
      missionsComplete = ::my_stats.getMissionsComplete()
    }

    ::g_squad_utils.checkMembersMrankDiff(this, Callback(@()
      this.checkedNewFlight(function() {
        sendBqEvent("CLIENT_BATTLE_2", "to_battle_button", configForStatistic)
        this.onStartAction()
      }.bindenv(this),
      function() {
        configForStatistic.canIntoToBattle <- false
        sendBqEvent("CLIENT_BATTLE_2", "to_battle_button", configForStatistic)
      }.bindenv(this))
    , this))
  }

  function isCrossPlayEventAvailable(event) {
    return crossplayModule.isCrossPlayEnabled() || ::events.isEventPlatformOnlyAllowed(event)
  }

  function onStartAction() {
    this.checkCountries()

    if (!::is_online_available()) {
      let handler = this
      this.goForwardIfOnline(function() {
          if (handler && checkObj(handler.scene))
            handler.onStartAction.call(handler)
        }, false, true)
      return
    }

    if (::g_squad_utils.canJoinFlightMsgBox({ isLeaderCanJoin = true })) {
      this.setCurCountry(profileCountrySq.value)
      let gameMode = ::game_mode_manager.getCurrentGameMode()
      if (gameMode == null)
        return
      if (this.checkGameModeTutorial(gameMode))
        return

      let event = ::game_mode_manager.getGameModeEvent(gameMode)
      if (!::events.checkEventFeature(event))
        return

      let countryGoodForMode = ::events.isCountryAvailable(event, this.getCurCountry())
      let multiSlotEnabled = this.isCurrentGameModeMultiSlotEnabled()
      let requiredUnitsAvailable = this.checkRequiredUnits(this.getCurCountry())
      if (countryGoodForMode && this.startEnabled)
        this.onCountryApply()
      else if (!requiredUnitsAvailable)
        this.showRequirementsMsgBox()
      else if (countryGoodForMode && !this.testCrewsForMode(this.getCurCountry()))
        this.showNoSuitableVehiclesMsgBox()
      else if (countryGoodForMode && !this.testCurrentUnitForMode(this.getCurCountry()) && !multiSlotEnabled)
        this.showBadCurrentUnitMsgBox()
      else
        loadHandler(gui_handlers.ChangeCountry, {
          currentCountry = this.getCurCountry()
          onCountryChooseCb = Callback(this.onCountryChoose, this)
        })
    }
  }

  function startEventBattle(event) {
    //!!FIX ME: this is a start random_battles or newbie battles events without check old domination modes
    //can be used as base random battles start for new matching.
    //valid only for newbie events yes
    if (::queues.isAnyQueuesActive(this.queueMask) || !::g_squad_utils.canJoinFlightMsgBox({ isLeaderCanJoin = true }))
      return

    ::EventJoinProcess(event)
  }

  function showNoSuitableVehiclesMsgBox() {
    this.msgBox("cant_fly", loc("events/no_allowed_crafts", " "), [["ok", function() {
      this.startSlotbarPresetsTutorial()
    }]], "ok")
  }

  function showBadCurrentUnitMsgBox() {
    this.msgBox("cant_fly", loc("events/no_allowed_crafts", " "), [["ok", function() {
      this.startSlotbarPresetsTutorial()
    }]], "ok")
  }

  function getRequirementsMsgText() {
    let gameMode = ::game_mode_manager.getCurrentGameMode()
    if (!gameMode || gameMode.type != RB_GM_TYPE.EVENT)
      return ""

    local requirements = []
    let event = ::game_mode_manager.getGameModeEvent(gameMode)
    if (!event)
      return ""

    foreach (team in ::events.getSidesList(event)) {
      let teamData = ::events.getTeamData(event, team)
      if (!teamData)
        continue

      requirements = ::events.getRequiredCrafts(teamData)
      if (requirements.len() > 0)
        break
    }
    if (requirements.len() == 0)
      return ""

    local msgText = loc("events/no_required_crafts") + loc("ui/colon")
    foreach (rule in requirements)
      msgText += "\n" + ::events.generateEventRule(rule, true)

    return msgText
  }

  function showRequirementsMsgBox() {
    this.showBadUnitMsgBox(this.getRequirementsMsgText())
  }

  function showBadUnitMsgBox(msgText) {
    let buttonsArray = []

    // "Change mode" button
    let curUnitType = getEsUnitType(getCurSlotbarUnit())
    let gameMode = ::game_mode_manager.getGameModeByUnitType(curUnitType, -1, true)
    if (gameMode != null) {
      buttonsArray.append([
        "#mainmenu/changeMode",
        function () {
          ::game_mode_manager.setCurrentGameModeById(gameMode.id)
          this.checkCountries()
          this.onStart()
        }
      ])
    }

    // "Change vehicle" button
    let currentGameMode = ::game_mode_manager.getCurrentGameMode()
    local properUnitType = null
    if (currentGameMode.type == RB_GM_TYPE.EVENT) {
      let event = ::game_mode_manager.getGameModeEvent(currentGameMode)
      foreach (unitType in unitTypes.types)
        if (::events.isUnitTypeRequired(event, unitType.esUnitType)) {
          properUnitType = unitType
          break
        }
    }

    if (this.rootHandlerWeak) {
      buttonsArray.append([
        "#mainmenu/changeVehicle",
        function () {
          if (this.isValid() && this.rootHandlerWeak)
            this.rootHandlerWeak.openShop(properUnitType)
        }
      ])
    }

    // "Ok" button
    buttonsArray.append(["ok", function () {}])

    this.msgBox("bad_current_unit", msgText, buttonsArray, "ok" /*"#mainmenu/changeMode"*/ , { cancel_fn = function () {} })
  }

  function isCurrentGameModeMultiSlotEnabled() {
    let gameMode = ::game_mode_manager.getCurrentGameMode()
    return ::events.isEventMultiSlotEnabled(getTblValue("source", gameMode, null))
  }

  function onCountryChoose(country) {
    if (isCountryAvailable(country)) {
      this.setCurCountry(country)
      this.topMenuSetCountry(this.getCurCountry())
      this.onCountryApply()
    }
  }

  function topMenuSetCountry(country) {
    let slotbar = this.getSlotbar()
    if (slotbar)
      slotbar.setCountry(country)
  }

  function onAdvertLinkClick(obj, itype, link) {
    this.proccessLinkFromText(obj, itype, link)
  }

  function onCountryApply() {
    let multiSlotEnabled = this.isCurrentGameModeMultiSlotEnabled()
    if (!this.testCrewsForMode(this.getCurCountry()))
      return this.showNoSuitableVehiclesMsgBox()
    if (!multiSlotEnabled && !this.testCurrentUnitForMode(this.getCurCountry()))
      return this.showBadCurrentUnitMsgBox()

    let gameMode   = ::game_mode_manager.getCurrentGameMode()
    if (gameMode == null)
      return
    if (::events.checkEventDisableSquads(this, gameMode.id))
      return
    if (this.checkGameModeTutorial(gameMode))
      return

    if (gameMode.type == RB_GM_TYPE.EVENT)
      return this.startEventBattle(::game_mode_manager.getGameModeEvent(gameMode)) //better to do completely the same here as we do n events.
                                               // but better to refactor this place after remove old gamemodes
  }

  function checkGameModeTutorial(gameMode) {
    let checkTutorUnitType = (gameMode.unitTypes.len() == 1) ? gameMode.unitTypes[0] : null
    let diffCode = ::events.getEventDiffCode(::game_mode_manager.getGameModeEvent(gameMode))
    return checkDiffTutorial(diffCode, checkTutorUnitType)
  }

  function updateStartButton() {
    if (!checkObj(this.scene) || !checkObj(this.toBattleButtonObj))
      return

    let inQueue = this.getCurQueue() != null

    local txt = ""
    local isCancel = false

    if (!inQueue) {
      if (::g_squad_manager.isSquadMember()) {
        let isReady = ::g_squad_manager.isMeReady()
        if (getLeaderOperationState() != LEADER_OPERATION_STATES.OUT) {
          let operationId = ::g_squad_manager.getWwOperationId()
          txt = operationId >= 0 ? "".concat(loc("ui/number_sign"), operationId) : ""
          isCancel = false
        }
        else {
          txt = loc(isReady ? "multiplayer/btnNotReady" : "mainmenu/btnReady")
          isCancel = isReady
        }
      }
      else {
        txt = loc(getToBattleLocIdShort())
        isCancel = false
      }
    }
    else {
      txt = loc("mainmenu/btnCancel")
      isCancel = true
    }

    this.toBattleButtonObj.setValue(txt)
    this.toBattleButtonObj.findObject("to_battle_button_text").setValue(txt)
    this.toBattleButtonObj.isCancel = isCancel ? "yes" : "no"

    this.toBattleButtonObj.fontOverride = daguiFonts.getMaxFontTextByWidth(txt,
      to_pixels("1@maxToBattleButtonTextWidth"), "bold")

    topMenuHandler.value?.onQueue.call(topMenuHandler.value, inQueue)
  }

  function afterCountryApply(membersData = null, team = null, event = null) {
    if (::disable_network()) {
      ::match_search_gm = GM_DOMINATION
      this.guiScene.performDelayed(this, function() {
        this.goForwardIfOnline(::gui_start_session_list, false)
      })
      return
    }

    this.joinQuery(null, membersData, team, event)
  }

  function joinQuery(query = null, membersData = null, _team = null, event = null) {
    this.leaveCurQueue()

    local modeName = ""
    if (event)
      modeName = event.name
    else {
      let gameMode = ::game_mode_manager.getCurrentGameMode()
      modeName = getTblValue("id", gameMode, "")
    }
    if (!query) {
      query = {
        mode = modeName
        country = this.getCurCountry()
      }
    }

    if (membersData)
      query.members <- membersData

    ::set_presence_to_player("queue")
    ::queues.joinQueue(query)

    local chatDiv = null
    if (topMenuHandler.value != null)
      chatDiv = ::getChatDiv(topMenuHandler.value.scene)
    if (!chatDiv && this.scene && this.scene.isValid())
      chatDiv = ::getChatDiv(this.scene)
    if (chatDiv)
      ::switchMenuChatObjIfVisible(chatDiv)
  }

  function leaveCurQueue(options = {}) {
    let queue = this.getCurQueue()
    if (!queue)
      return false

    if (options.len() && !::g_squad_utils.canJoinFlightMsgBox(options))
      return false

    ::queues.leaveQueue(queue, options)
    return true
  }

  function goBack() {
    if (this.leaveCurQueue({ isLeaderCanJoin = true
      msgId = "squad/only_leader_can_cancel"
      isCanceledByPlayer = true }))
      return

    this.onTopMenuGoBack()
  }

  function checkQueue(func) {
    if (!this.inited)
      return func()

    this.checkedModifyQueue(this.queueMask, func, this.restoreQueueParams)
  }

  function restoreQueueParams() {
    let tMsgBox = this.guiScene["req_tutorial_msgbox"]
    if (checkObj(tMsgBox))
      this.guiScene.destroyElement(tMsgBox)
  }

  function testCurrentUnitForMode(country) {
    if (country == "country_0") {
      let option = ::get_option(USEROPT_COUNTRY)
      foreach (idx, optionCountryName in option.values)
        if (optionCountryName != "country_0" && option.items[idx].enabled) {
          let unit = this.getQueueAircraft(optionCountryName)
          if (!unit)
            continue
          if (::game_mode_manager.isUnitAllowedForGameMode(unit))
            return true
        }
      return false
    }
    let unit = getSelAircraftByCountry(country)
    return ::game_mode_manager.isUnitAllowedForGameMode(unit)
  }

  function testCrewsForMode(country) {
    let countryToCheckArr = []
    if (country == "country_0") { //fill countryToCheckArr with countries, allowed by game mode
      let option = ::get_option(USEROPT_COUNTRY)
      foreach (idx, optionCountryName in option.values)
        if (optionCountryName != "country_0" && option.items[idx].enabled)
          countryToCheckArr.append(optionCountryName)
    }
    else
      countryToCheckArr.append(country)

    foreach (countryCrews in ::g_crews_list.get()) {
      if (!isInArray(countryCrews.country, countryToCheckArr))
        continue

      foreach (crew in countryCrews.crews) {
        if (!("aircraft" in crew))
          continue
        let unit = getAircraftByName(crew.aircraft)
        if (::game_mode_manager.isUnitAllowedForGameMode(unit))
          return true
      }
    }

    return false
  }

  function checkRequiredUnits(country) {
    let gameMode = ::game_mode_manager.getCurrentGameMode()
    return gameMode ? ::events.checkRequiredUnits(::game_mode_manager.getGameModeEvent(gameMode), null, country) : true
  }

  function getIaBlockSelObj(obj) {
    let value = obj.getValue() ?? 0
    if (obj.childrenCount() <= value)
      return null

    let id = ::getObjIdByPrefix(obj.getChild(value), "block_")
    if (!id)
      return null

    let selObj = obj.findObject(id)
    return checkObj(selObj) ? selObj : null
  }

  function onIaBlockActivate(obj) {
    let selObj = this.getIaBlockSelObj(obj)
    if (!selObj)
      return

    selObj.select()
  }

  function onUnlockCrew(obj) {
    if (!obj)
      return
    local isGold = false
    if (obj?.id == "btn_unlock_crew_gold")
      isGold = true
    let unit = getShowedUnit()
    if (!unit)
      return

    let crewId = getCrewByAir(unit).id
    let cost = Cost()
    if (isGold)
      cost.gold = ::shop_get_unlock_crew_cost_gold(crewId)
    else
      cost.wp = ::shop_get_unlock_crew_cost(crewId)

    let msg = format("%s %s?", loc("msgbox/question_crew_unlock"), cost.getTextAccordingToBalance())
    this.msgBox("unlock_crew", msg, [
        ["yes", function() {
          this.taskId = ::unlockCrew(crewId, isGold, cost)
          ::sync_handler_simulate_signal("profile_reload")
          if (this.taskId >= 0) {
            ::set_char_cb(this, this.slotOpCb)
            this.showTaskProgressBox()
            this.afterSlotOp = null
          }
        }],
        ["no", function() { return false }]
      ], "no")
  }

  function checkNoviceTutor() {
    if (hasFeature("BattleAutoStart"))
      return

    if (::disable_network() || !::my_stats.isStatsLoaded() || !checkObj(this.toBattleButtonObj))
      return

    if (!tutorialModule.needShowTutorial("toBattle", 1) || ::my_stats.getPvpRespawns())
      return

    this.toBattleTutor()
    tutorialModule.saveShowedTutorial("toBattle")
  }

  function checkUpgradeCrewTutorial() {
    if (!::g_login.isLoggedIn())
      return

    if (!::g_crew.isAllCrewsMinLevel())
      return

    this.tryToStartUpgradeCrewTutorial()
  }

  function getCurrentCrewSlot() {
    let slotbar = this.getSlotbar()
    return slotbar && slotbar.getCurrentCrewSlot()
  }

  function tryToStartUpgradeCrewTutorial() {
    let curCrew = this.getCurCrew()
    if (curCrew == null || curCrew.isEmpty)
      return

    let curCrewSlot = this.getCurrentCrewSlot()
    if (!curCrewSlot)
      return

    let tutorialPageId = ::g_crew.getSkillPageIdToRunTutorial(curCrew)
    if (!tutorialPageId)
      return

    let steps = [
      {
        obj = [curCrewSlot]
        text = loc("tutorials/upg_crew/skill_points_info") + " " + loc("tutorials/upg_crew/press_to_crew")
        actionType = tutorAction.OBJ_CLICK
        shortcut = ::GAMEPAD_ENTER_SHORTCUT
        nextActionShortcut = "help/OBJ_CLICK"
        cb = @() this.openUnitActionsList(curCrewSlot, true, true)
      },
      {
        actionType = tutorAction.WAIT_ONLY
        waitTime = 0.5
      },
      {
        obj = [function() {
          return curCrewSlot.findObject("crew")
        }]
        text = loc("tutorials/upg_crew/select_crew")
        actionType = tutorAction.OBJ_CLICK
        shortcut = ::GAMEPAD_ENTER_SHORTCUT
        nextActionShortcut = "help/OBJ_CLICK"
        cb = function() {
          ::gui_modal_crew({
            countryId = curCrew.idCountry,
            idInCountry = curCrew.idInCountry,
            curPageId = tutorialPageId,
            showTutorial = true
          })
        }
      }
    ]
    ::gui_modal_tutor(steps, this)
  }

  function toBattleTutor() {
    let objs = [this.toBattleButtonObj, topMenuHandler.value.getObj("to_battle_console_image")]
    let steps = [{
      obj = [objs]
      text = loc("tutor/battleButton")
      actionType = tutorAction.OBJ_CLICK
      nextActionShortcut = "help/OBJ_CLICK"
      shortcut = ::SHORTCUT.GAMEPAD_X
      cb = this.onStart
    }]
    ::gui_modal_tutor(steps, this)
  }

  function startSlotbarPresetsTutorial() {
    let tutorialCounter = ::SlotbarPresetsTutorial.getCounter()
    if (tutorialCounter >= ::SlotbarPresetsTutorial.MAX_TUTORIALS)
      return false

    let currentGameMode = ::game_mode_manager.getCurrentGameMode()
    if (currentGameMode == null)
      return false

    let missionCounter = ::stat_get_value_missions_completed(currentGameMode.diffCode, 1)
    if (missionCounter >= ::SlotbarPresetsTutorial.MAX_PLAYS_FOR_GAME_MODE)
      return false

    if (!::slotbarPresets.canEditCountryPresets(this.getCurCountry()))
      return false

    let tutorial = ::SlotbarPresetsTutorial()
    tutorial.currentCountry = this.getCurCountry()
    tutorial.tutorialGameMode = currentGameMode
    tutorial.currentHandler = this
    tutorial.onComplete = function (_params) {
      this.slotbarPresetsTutorial = null
    }.bindenv(this)
    tutorial.preset = ::game_mode_manager.findPresetValidForGameMode(this.getCurCountry())
    if (tutorial.startTutorial()) {
      this.slotbarPresetsTutorial = tutorial
      return true
    }
    return false
  }

  function checkShowViralAcquisition() {
    this.guiScene.performDelayed({}, function() {
      if (::my_stats.isMeNewbie())
        return

      let invitedPlayersBlk = DataBlock()
      ::get_invited_players_info(invitedPlayersBlk)
      if (invitedPlayersBlk.blockCount() == 0) {
        let gmBlk = get_game_settings_blk()
        let reminderPeriod = gmBlk?.viralAcquisitionReminderPeriodDays ?? 10
        let today = time.getUtcDays()
        let never = 0
        let lastLoginDay = loadLocalAccountSettings("viralAcquisition/lastLoginDay", today)
        local lastShowTime = loadLocalAccountSettings("viralAcquisition/lastShowTime", never)

        // Game designers can force reset lastShowTime of all users by increasing this value in cfg:
        if (gmBlk?.resetViralAcquisitionDaysCounter) {
          let newResetVer = gmBlk.resetViralAcquisitionDaysCounter
          let knownResetVer = loadLocalAccountSettings("viralAcquisition/resetDays", 0)
          if (newResetVer > knownResetVer) {
            saveLocalAccountSettings("viralAcquisition/resetDays", newResetVer)
            lastShowTime = never
          }
        }

        saveLocalAccountSettings("viralAcquisition/lastLoginDay", today)
        if ((lastLoginDay - lastShowTime) > reminderPeriod) {
          saveLocalAccountSettings("viralAcquisition/lastShowTime", today)
          showViralAcquisitionWnd()
        }
      }
    })
  }

  function checkShowChangelog() {
    this.guiScene.performDelayed({}, function() {
      if (needShowChangelog() && get_cur_base_gui_handler().isSceneActiveNoModals())
        handlersManager.animatedSwitchScene(openChangelog())
    })
  }

  function setUsingDynamicLut(value) {
    setIsUsingDynamicLut(value); //need to be set first
    setTonemappingMode(getTonemappingMode());
  }

  function checkShowDynamicLutSuggestion() {
    let isShown = loadLocalAccountSettings("isDynamicLutSuggestionShown", false)
    if (isShown || !shouldShowDynamicLutPopUpMessage())
      return

    this.msgBox("dynamic_lut_suggestion", loc("msgBox/dynamic_lut_suggestion/desc"), [
      ["ok", @() this.setUsingDynamicLut(true)],
      ["cancel"]], "ok")

    saveLocalAccountSettings("isDynamicLutSuggestionShown", true)
  }

  function checkNewUnitTypeToBattleTutor() {
    if (::disable_network()
      || !::my_stats.isStatsLoaded()
      || !hasFeature("NewUnitTypeToBattleTutorial"))
      return

    if (!tutorialModule.needShowTutorial("newUnitTypetoBattle", 1)
      || ::my_stats.getMissionsComplete(["pvp_played", "skirmish_played"])
           < ::SlotbarPresetsTutorial.MIN_PLAYS_GAME_FOR_NEW_UNIT_TYPE
      || ::g_squad_manager.isNotAloneOnline()
      || !isCountrySlotbarHasUnits(profileCountrySq.value)
      || !isCountryAllCrewsUnlockedInHangar(profileCountrySq.value))
      return

    this.startNewUnitTypeToBattleTutorial()
  }

  function startNewUnitTypeToBattleTutorial() {
    let currentGameMode = ::game_mode_manager.getCurrentGameMode()
    if (!currentGameMode)
      return

    let currentCountry = profileCountrySq.value
    local gameModeForTutorial = null
    local validPreset = null
    local isNotFoundUnitTypeForTutorial = true
    local isNotFoundValidPresetForTutorial = false
    foreach (unitType in unitTypes.types) {
      if (!unitType.isAvailableForFirstChoice()
        || ::my_stats.getTimePlayedOnUnitType(unitType.esUnitType) > 0)
        continue

      isNotFoundUnitTypeForTutorial = false
      gameModeForTutorial = ::game_mode_manager.getGameModeById(getEventEconomicName(
        ::my_stats.getNextNewbieEvent(currentCountry, unitType.esUnitType)))

      if (!gameModeForTutorial)
        continue

      validPreset = ::game_mode_manager.findPresetValidForGameMode(currentCountry, gameModeForTutorial)
      if (validPreset)
        break

      isNotFoundValidPresetForTutorial = true
    }

    if (!gameModeForTutorial || !validPreset) {
      if (isNotFoundUnitTypeForTutorial || isNotFoundValidPresetForTutorial) {
        sendBqEvent("CLIENT_GAMEPLAY_1", "new_unit_type_to_battle_tutorial_skipped",
          { result = isNotFoundUnitTypeForTutorial ? "isNotFoundUnitTypeForTutorial" : "isNotFoundValidPreset"})
        tutorialModule.saveShowedTutorial("newUnitTypetoBattle")
      }
      return
    }

    scene_msg_box("new_unit_type_to_battle_tutorial_msgbox", null,
      loc("msgBox/start_new_unit_type_to_battle_tutorial", { gameModeName = gameModeForTutorial.text }),
      [
        ["yes", function() {
          sendBqEvent("CLIENT_GAMEPLAY_1", "new_unit_type_to_battle_tutorial_msgbox_btn", { result = "yes" })
          let tutorial = ::SlotbarPresetsTutorial()
          tutorial.currentCountry = currentCountry
          tutorial.tutorialGameMode = gameModeForTutorial
          tutorial.isNewUnitTypeToBattleTutorial = true
          tutorial.currentHandler = this
          tutorial.onComplete = function (_params) {
            this.slotbarPresetsTutorial = null
          }.bindenv(this)
          tutorial.preset = validPreset
          if (tutorial.startTutorial())
            this.slotbarPresetsTutorial = tutorial
        }.bindenv(this)],
        ["no", function() {
          sendBqEvent("CLIENT_GAMEPLAY_1", "new_unit_type_to_battle_tutorial_msgbox_btn", { result = "no" })
        }.bindenv(this)]
      ], "yes")

    tutorialModule.saveShowedTutorial("newUnitTypetoBattle")
  }

  function updateNoticeGMChanged() {
    if (!hasFeature("GameModeSelector"))
      return

    local notice = null
    let alertObj = this.scene.findObject("game_mode_notice")
    if (::g_squad_manager.isSquadMember() && ::g_squad_manager.isMeReady()) {
      let gameModeId = ::g_squad_manager.getLeaderGameModeId()
      if (gameModeId && gameModeId != "")
        notice = loc("mainmenu/leader_gamemode_notice")
      alertObj.hideConsoleImage = "yes"
    }
    else {
      let id = ::game_mode_manager.getUserGameModeId()
      let gameMode = ::game_mode_manager.getGameModeById(id)
      if ((id != "" && gameMode && id != ::game_mode_manager.getCurrentGameModeId()))
        notice = format(loc("mainmenu/gamemode_change_notice"), gameMode.text)
      alertObj.hideConsoleImage = "no"
    }

    if (notice)
      alertObj.setValue(notice)
    alertObj.show(notice)
  }

  function onGMNoticeClick() {
    if (::g_squad_manager.isSquadMember() && ::g_squad_manager.isMeReady())
      return

    let id = ::game_mode_manager.getUserGameModeId()
    if (id != "") {
      ::game_mode_manager.setCurrentGameModeById(id, true)
    }
  }

  function onEventBattleRatingChanged(_params) {
    this.setCurrentGameModeName()
  }

  function checkNonApprovedSquadronResearches() {
    if (isHaveNonApprovedClanUnitResearches())
      clanVehiclesModal.open()
  }

  function onEventClanChanged(_params) {
    if (!hasFeature("AutoFlushClanExp"))
      this.doWhenActiveOnce("checkNonApprovedSquadronResearches")
  }

  function onEventSquadronExpChanged(_params) {
    if (!hasFeature("AutoFlushClanExp"))
      this.doWhenActiveOnce("checkNonApprovedSquadronResearches")
  }

  function onEventPartnerUnlocksUpdated(_p) {
    let hasModalObjectVal = this.guiScene.hasModalObject()
    this.doWhenActive(@() ::g_popup_msg.showPopupWndIfNeed(hasModalObjectVal))
  }

  function onEventCrossPlayOptionChanged(_p) {
    this.setCurrentGameModeName()
  }

  function on_show_clan_requests() { //FIXME: FUNC in 'on_click' somehow calls
    if (::g_clans.isHaveRightsToReviewCandidates())
      openClanRequestsWnd(::g_clans.getMyClanCandidates(), ::clan_get_my_clan_id(), false);
  }

  onEventToBattleLocShortChanged = @(_params) this.doWhenActiveOnce("updateStartButton")

  onEventOpenGameModeSelect = @(_p) this.openGameModeSelect()

  function openGameModeSelect() {
    if (!this.isValid())
      return

    this.checkQueue(@() checkSquadUnreadyAndDo(@() gui_handlers.GameModeSelect.open(), null))
  }

  onBackgroundModelHintTimer = @(obj, _dt) placeBackgroundModelHint(obj)
}
