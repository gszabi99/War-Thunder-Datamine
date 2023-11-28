//-file:plus-string
from "%scripts/dagui_library.nut" import *
from "%scripts/mainConsts.nut" import HELP_CONTENT_SET

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
let { get_game_mode } = require("mission")
let { leave_mp_session, quit_to_debriefing, interrupt_multiplayer,
  quit_mission_after_complete, restart_mission, restart_replay, get_mission_status
} = require("guiMission")
let { restartCurrentMission } = require("%scripts/missions/missionsUtilsModule.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { getUnitName } = require("%scripts/unit/unitInfo.nut")

::gui_start_flight_menu <- function gui_start_flight_menu() {
  ::flight_menu_handler = handlersManager.loadHandler(gui_handlers.FlightMenu)
}

::gui_start_flight_menu_failed <- ::gui_start_flight_menu //it checks MISSION_STATUS_FAIL status itself
::gui_start_flight_menu_psn <- function gui_start_flight_menu_psn() {} //unused atm, but still have a case in code

gui_handlers.FlightMenu <- class extends gui_handlers.BaseGuiHandlerWT {
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
    this.usePause = !::is_game_paused()

    if (!handlersManager.isFullReloadInProgress) {
      ::in_flight_menu(true)
      if (this.usePause)
        ::pause_game(true)
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
      ::in_flight_menu(false) //in_flight_menu will call closeScene which call stat chat
      if (this.usePause)
        ::pause_game(false)
    })
  }

  function onCancel(obj) {
    this.onResume(obj)
  }

  function onOptions(_obj) {
    openOptionsWnd()
  }

  function onControls(_obj) {
    ::gui_start_controls();
  }

  function restartBriefing() {
    if (!canRestart())
      return
    if (("is_offline_version" in getroottable()) && ::is_offline_version)
      return restart_mission()

    if ([ GM_CAMPAIGN, GM_SINGLE_MISSION, GM_DYNAMIC ].contains(get_game_mode()))
       this.goForward(::gui_start_briefing_restart)
    else
      restartCurrentMission()
  }

  function onRestart(_obj) {
    if (!canRestart())
      return
    if (("is_offline_version" in getroottable()) && ::is_offline_version)
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
    ::g_orders.disableOrders()
    quit_to_debriefing()
    interrupt_multiplayer(true)
    ::HudBattleLog.reset()
    this.onResumeRaw()
  }

  function onQuitMission(_obj) {
    if (("is_offline_version" in getroottable()) && ::is_offline_version)
      return restart_mission()

    if (is_replay_playing()) {
      this.quitToDebriefing()
    }
    else if (get_mission_status() == MISSION_STATUS_RUNNING) {
      local text = ""
      if (is_mplayer_host())
        text = loc("flightmenu/questionQuitMissionHost")
      else if (get_game_mode() == GM_DOMINATION) {
        let unitsData = ::g_mis_custom_state.getCurMissionRules().getAvailableToSpawnUnitsData()
        let unitsTexts = unitsData.map(function(ud) {
          local res = colorize("userlogColoredText", getUnitName(ud.unit))
          if (ud.comment.len())
            res += loc("ui/parentheses/space", { text = ud.comment })
          return res
        })
        if (unitsTexts.len())
          text = loc("flightmenu/haveAvailableCrews") + "\n" + ", ".join(unitsTexts, true) + "\n\n"

        text += loc("flightmenu/questionQuitMissionInProgress")
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
          ::in_flight_menu(false)
          if (this.usePause)
            ::pause_game(false)
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
      ::do_player_bailout()

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

    if ("toggle_freecam" in getroottable())
      ::toggle_freecam()
  }
}

::quit_mission <- function quit_mission() {
  ::in_flight_menu(false)
  ::pause_game(false)
  ::gui_start_hud()
  broadcastEvent("PlayerQuitMission")

  if (::is_multiplayer())
    return leave_mp_session()

  quit_to_debriefing()
  interrupt_multiplayer(true)
}
