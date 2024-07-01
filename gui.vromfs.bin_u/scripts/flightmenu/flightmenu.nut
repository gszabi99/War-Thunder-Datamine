//-file:plus-string
from "%scripts/dagui_natives.nut" import do_player_bailout, toggle_freecam, pause_game, is_game_paused, in_flight_menu, set_context_to_player
from "app" import is_offline_version
from "%scripts/dagui_library.nut" import *
from "%scripts/mainConsts.nut" import HELP_CONTENT_SET
from "%scripts/options/optionsExtNames.nut" import USEROPT_DIFFICULTY

let { HudBattleLog } = require("%scripts/hud/hudBattleLog.nut")
let { eventbus_subscribe } = require("eventbus")
let DataBlock = require("DataBlock")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { move_mouse_on_obj, handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { is_mplayer_host } = require("multiplayer")
let { canRestart, canBailout } = require("%scripts/flightMenu/flightMenuState.nut")
let flightMenuButtonTypes = require("%scripts/flightMenu/flightMenuButtonTypes.nut")
let { openOptionsWnd } = require("%scripts/options/handlers/optionsWnd.nut")
let exitGame = require("%scripts/utils/exitGame.nut")
let { setMousePointerInitialPos } = require("%scripts/controls/mousePointerInitialPos.nut")
let { getPlayerCurUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { guiStartMPStatScreen } = require("%scripts/statistics/mpStatisticsUtil.nut")
let { is_replay_playing } = require("replays")
let { get_game_mode, get_game_type } = require("mission")
let { leave_mp_session, quit_to_debriefing, interrupt_multiplayer,
  quit_mission_after_complete, restart_mission, restart_replay, get_mission_status,
  get_meta_mission_info_by_gm_and_name, get_mission_difficulty
} = require("guiMission")
let { get_gui_option } = require("guiOptions")
let { restartCurrentMission } = require("%scripts/missions/missionsUtilsModule.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { getUnitName } = require("%scripts/unit/unitInfo.nut")
let { getCurMissionRules } = require("%scripts/misCustomRules/missionCustomState.nut")
let { gui_start_controls } = require("%scripts/controls/startControls.nut")
let { guiStartCdOptions, getCurrentCampaignMission } = require("%scripts/missions/startMissionsList.nut")
let { disableOrders } = require("%scripts/items/orders.nut")
let { get_current_mission_info_cached } = require("blkGetters")
let { isMissionExtr } = require("%scripts/missions/missionsUtils.nut")

function gui_start_briefing_restart(_ = {}) {
  log("gui_start_briefing_restart")
  let missionName = getCurrentCampaignMission()
  if (missionName != null) {
    let missionBlk = DataBlock()
    let gm = get_game_mode()
    let missionInfoBlk = get_meta_mission_info_by_gm_and_name(gm, missionName)
    if (missionInfoBlk != null)
      missionBlk.setFrom(missionInfoBlk)
    let briefingOptions = ::get_briefing_options(gm, get_game_type(), missionBlk)
    if (briefingOptions.len() == 0)
      return restartCurrentMission()
  }

  let params = {
    isRestart = true
    backSceneParams = { eventbusName = "gui_start_flight_menu" }
  }

  let finalApplyFunc = function() {
    set_context_to_player("difficulty", get_mission_difficulty())
    restartCurrentMission()
  }
  params.applyFunc <- function() {
    if (get_gui_option(USEROPT_DIFFICULTY) == "custom")
      guiStartCdOptions(finalApplyFunc)
    else
      finalApplyFunc()
  }

  handlersManager.loadHandler(gui_handlers.Briefing, params)
  handlersManager.setLastBaseHandlerStartParams({ eventbusName = "gui_start_briefing_restart" })
}

eventbus_subscribe("gui_start_briefing_restart", gui_start_briefing_restart)

gui_handlers.FlightMenu <- class (gui_handlers.BaseGuiHandlerWT) {
  sceneBlkName = "%gui/flightMenu/flightMenu.blk"
  handlerLocId = "flightmenu"
  shouldBlurSceneBg = true
  keepLoaded = true
  wndControlsAllowMask = CtrlsInGui.CTRL_ALLOW_FLIGHT_MENU

  lastSelectedBtnId = null

  menuButtonsCfg = null
  isMissionFailed = false
  isShowStat = false
  usePause = true

  function initScreen() {
    this.setSceneTitle(::getCurMpTitle())

    this.menuButtonsCfg = flightMenuButtonTypes.types.filter(@(btn) btn.isAvailableInMission())
    let markup = handyman.renderCached("%gui/flightMenu/menuButtons.tpl", { buttons = this.menuButtonsCfg })
    this.guiScene.replaceContentFromText(this.scene.findObject("menu-buttons"), markup, markup.len(), this)
    this.guiScene.applyPendingChanges(false)

    this.reinitScreen()
  }

  function reinitScreen(_params = null) {
    this.isMissionFailed = get_mission_status() == MISSION_STATUS_FAIL
    this.usePause = !is_game_paused()

    if (!handlersManager.isFullReloadInProgress) {
      in_flight_menu(true)
      if (this.usePause)
        pause_game(true)
    }

    this.updateButtons()
    this.restoreFocus(true)
  }

  function updateButtons() {
    if (!checkObj(this.scene))
      return

    foreach (btn in this.menuButtonsCfg) {
      let isShow = btn.isVisible()
      let btnObj = showObjById(btn.buttonId, isShow, this.scene)
      if (!isShow)
        continue
      let txt = btn.getUpdatedLabelText()
      if (btnObj != null && txt != "")
        btnObj.setValue(txt)
    }

    showObjById("btn_back", !this.isMissionFailed, this.scene)
  }

  function restoreFocus(isInitial = false) {
    if (!this.isSceneActiveNoModals())
      return
    let btnId = this.lastSelectedBtnId ?? (this.isMissionFailed ? "btn_restart" : "btn_resume")
    let btnObj = this.getObj(btnId)

    if (showConsoleButtons.value)
      move_mouse_on_obj(btnObj)
    else if (isInitial)
      setMousePointerInitialPos(btnObj)
  }

  function onEventModalWndDestroy(params) {
    base.onEventModalWndDestroy(params)
    this.restoreFocus()
  }

  function goBack() {
    this.onResume()
  }

  function onResume(_obj = null) {
    if (this.isMissionFailed)
      return
    this.onResumeRaw()
  }

  _isWaitForResume = false
  function onResumeRaw() {
    if (this.isMissionFailed || this._isWaitForResume)
      return

    this._isWaitForResume = true
    this.guiScene.performDelayed(this, function() {
      if (!this.isValid())
        return
      this._isWaitForResume = false
      this.lastSelectedBtnId = null
      in_flight_menu(false) //in_flight_menu will call closeScene which call stat chat
      if (this.usePause)
        pause_game(false)
    })
  }

  function onCancel(obj) {
    this.onResume(obj)
  }

  function onOptions(_obj) {
    openOptionsWnd()
  }

  function onControls(_obj) {
    gui_start_controls()
  }

  function restartBriefing() {
    if (!canRestart())
      return
    if (is_offline_version())
      return restart_mission()

    if ([ GM_CAMPAIGN, GM_SINGLE_MISSION, GM_DYNAMIC ].contains(get_game_mode()))
       this.goForward(gui_start_briefing_restart)
    else
      restartCurrentMission()
  }

  function onRestart(_obj) {
    if (!canRestart())
      return
    if (is_offline_version())
      return restart_mission()

    if (this.isMissionFailed)
      this.restartBriefing()
    else if (get_mission_status() == MISSION_STATUS_RUNNING) {
      this.msgBox("question_restart_mission", loc("flightmenu/questionRestartMission"),
      [
        ["yes", this.restartBriefing],
        ["no"]
      ], "no", { cancel_fn = @() null })
    }
    else if (is_replay_playing())
      restart_replay()
    else
      restartCurrentMission()
  }

  function sendDisconnectMessage() {
    broadcastEvent("PlayerQuitMission")
    if (::is_multiplayer()) {
      leave_mp_session()
      this.onResumeRaw()
    }
    else
      this.quitToDebriefing()
  }

  function quitToDebriefing() {
    disableOrders()
    quit_to_debriefing()
    interrupt_multiplayer(true)
    HudBattleLog.reset()
    this.onResumeRaw()
  }

  function onQuitMission(_obj) {
    if (is_offline_version())
      return restart_mission()

    if (is_replay_playing()) {
      this.quitToDebriefing()
    }
    else if (get_mission_status() == MISSION_STATUS_RUNNING) {
      local text = ""
      if (is_mplayer_host())
        text = loc("flightmenu/questionQuitMissionHost")
      else if (get_game_mode() == GM_DOMINATION) {
        let misBlk = get_current_mission_info_cached()
        local unitsData = getCurMissionRules().getAvailableToSpawnUnitsData()
        if (isMissionExtr())
          unitsData = unitsData.filter(@(ud) ud.unit.name not in misBlk?.editSlotbar[ud.unit.shopCountry])

        let unitsTexts = unitsData.map(function(ud) {
          local res = colorize("userlogColoredText", getUnitName(ud.unit))
          if (ud.comment.len())
            res += loc("ui/parentheses/space", { text = ud.comment })
          return res
        })
        if (unitsTexts.len())
          text = loc("flightmenu/haveAvailableCrews") + "\n" + ", ".join(unitsTexts, true) + "\n\n"

        text = "".concat(text, (misBlk?.gt_use_wp && misBlk?.gt_use_xp)
          ? loc("flightmenu/questionQuitMissionInProgress")
          : loc("flightmenu/questionQuitMission"))
      }
      else
        text = loc("flightmenu/questionQuitMission")
      this.msgBox("question_quit_mission", text,
      [
        ["yes", this.sendDisconnectMessage],
        ["no"]
      ], "no", { cancel_fn = @() null })
    }
    else if (this.isMissionFailed) {
      let text = loc("flightmenu/questionQuitMission")
      this.msgBox("question_quit_mission", text,
      [
        ["yes", function() {
          quit_to_debriefing()
          interrupt_multiplayer(true)
          in_flight_menu(false)
          if (this.usePause)
            pause_game(false)
        }],
        ["no"]
      ], "yes", { cancel_fn = @() null })
    }
    else {
      quit_mission_after_complete()
      this.onResumeRaw()
    }
  }

  function onCompleteMission(obj) {
    this.onQuitMission(obj)
  }

  function onQuitGame(_obj) {
    this.msgBox("question_quit_flight", loc("flightmenu/questionQuitGame"),
      [
        ["yes", exitGame],
        ["no"]
      ], "no", { cancel_fn = @() null })
  }

  function doBailout() {
    if (canBailout())
      do_player_bailout()

    this.onResume(null)
  }

  function onBailout(_obj) {
    if (canBailout()) {
      this.msgBox("question_bailout", getPlayerCurUnit()?.unitType.getBailoutQuestionText() ?? "",
        [
          ["yes", this.doBailout],
          ["no"]
        ], "no", { cancel_fn = @() null })
    }
    else
      this.onResume(null)
  }

  function onControlsHelp() {
    ::gui_modal_help(false, HELP_CONTENT_SET.MISSION)
  }

  onStats = @() guiStartMPStatScreen()

  function onMenuBtnHover(obj) {
    if (!checkObj(obj))
      return
    let id = obj.id
    let isHover = obj.isHovered()
    if (!isHover && id != this.lastSelectedBtnId)
      return
    this.lastSelectedBtnId = isHover ? id : null
  }

  function onFreecam(_obj) {
    this.onResumeRaw()
    toggle_freecam?()
  }
}

function gui_start_flight_menu(_ = null) {
  handlersManager.loadHandler(gui_handlers.FlightMenu)
}

eventbus_subscribe("gui_start_flight_menu", gui_start_flight_menu)
eventbus_subscribe("gui_start_flight_menu_failed", gui_start_flight_menu) //it checks MISSION_STATUS_FAIL status itself
eventbus_subscribe("gui_start_flight_menu_psn", @(_) null) //unused atm, but still have a case in code

return {
  gui_start_flight_menu
}
