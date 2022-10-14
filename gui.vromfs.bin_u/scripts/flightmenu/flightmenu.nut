from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

let {
  is_mplayer_host = @() ::is_mplayer_host() //compatibility with 2.16.0.X
} = require_optional("multiplayer")
let { canRestart, canBailout } = require("%scripts/flightMenu/flightMenuState.nut")
let flightMenuButtonTypes = require("%scripts/flightMenu/flightMenuButtonTypes.nut")
let { openOptionsWnd } = require("%scripts/options/handlers/optionsWnd.nut")
let exitGame = require("%scripts/utils/exitGame.nut")
let { setMousePointerInitialPos } = require("%scripts/controls/mousePointerInitialPos.nut")
let { getPlayerCurUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { guiStartMPStatScreen } = require("%scripts/statistics/mpStatisticsUtil.nut")
let { is_replay_playing } = require("replays")

::gui_start_flight_menu <- function gui_start_flight_menu()
{
  ::flight_menu_handler = ::handlersManager.loadHandler(::gui_handlers.FlightMenu)
}

::gui_start_flight_menu_failed <- ::gui_start_flight_menu //it checks MISSION_STATUS_FAIL status itself
::gui_start_flight_menu_psn <- function gui_start_flight_menu_psn() {} //unused atm, but still have a case in code

::gui_handlers.FlightMenu <- class extends ::gui_handlers.BaseGuiHandlerWT
{
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

  function initScreen()
  {
    setSceneTitle(::getCurMpTitle())

    menuButtonsCfg = flightMenuButtonTypes.types.filter(@(btn) btn.isAvailableInMission())
    let markup = ::handyman.renderCached("%gui/flightMenu/menuButtons", { buttons = menuButtonsCfg })
    guiScene.replaceContentFromText(scene.findObject("menu-buttons"), markup, markup.len(), this)
    guiScene.applyPendingChanges(false)

    reinitScreen()
  }

  function reinitScreen(params = null)
  {
    isMissionFailed = ::get_mission_status() == MISSION_STATUS_FAIL
    usePause = !::is_game_paused()

    if (!::handlersManager.isFullReloadInProgress)
    {
      ::in_flight_menu(true)
      if (usePause)
        ::pause_game(true)
    }

    updateButtons()
    restoreFocus(true)
  }

  function updateButtons()
  {
    if (!checkObj(scene))
      return

    foreach (btn in menuButtonsCfg)
    {
      let isShow = btn.isVisible()
      let btnObj = ::showBtn(btn.buttonId, isShow, scene)
      if (!isShow)
        continue
      let txt = btn.getUpdatedLabelText()
      if (btnObj != null && txt != "")
        btnObj.setValue(txt)
    }

    ::showBtn("btn_back", !isMissionFailed, scene)
  }

  function restoreFocus(isInitial = false)
  {
    if (!isSceneActiveNoModals())
      return
    let btnId = lastSelectedBtnId ?? (isMissionFailed ? "btn_restart" : "btn_resume")
    let btnObj = getObj(btnId)

    if (::show_console_buttons)
      ::move_mouse_on_obj(btnObj)
    else if (isInitial)
      setMousePointerInitialPos(btnObj)
  }

  function onEventModalWndDestroy(params)
  {
    restoreFocus()
  }

  function goBack()
  {
    onResume()
  }

  function onResume(obj = null)
  {
    if (isMissionFailed)
      return
    onResumeRaw()
  }

  _isWaitForResume = false
  function onResumeRaw()
  {
    if (isMissionFailed || _isWaitForResume)
      return

    _isWaitForResume = true
    guiScene.performDelayed(this, function()
    {
      if (!isValid())
        return
      _isWaitForResume = false
      lastSelectedBtnId = null
      ::in_flight_menu(false) //in_flight_menu will call closeScene which call stat chat
      if (usePause)
        ::pause_game(false)
    })
  }

  function onCancel(obj)
  {
    onResume(obj)
  }

  function onOptions(obj)
  {
    openOptionsWnd()
  }

  function onControls(obj)
  {
    ::gui_start_controls();
  }

  function restartBriefing()
  {
    if (!canRestart())
      return
    if (("is_offline_version" in getroottable()) && ::is_offline_version)
      return ::restart_mission();

    if ([ GM_CAMPAIGN, GM_SINGLE_MISSION, GM_DYNAMIC ].contains(::get_game_mode()))
       goForward(::gui_start_briefing_restart)
    else
      ::restart_current_mission()
  }

  function onRestart(obj)
  {
    if (!canRestart())
      return
    if (("is_offline_version" in getroottable()) && ::is_offline_version)
      return ::restart_mission();

    if (isMissionFailed)
      restartBriefing()
    else
    if (::get_mission_status() == MISSION_STATUS_RUNNING)
    {
      this.msgBox("question_restart_mission", loc("flightmenu/questionRestartMission"),
      [
        ["yes", restartBriefing],
        ["no"]
      ], "no", { cancel_fn = @() null })
    }
    else
    if (is_replay_playing())
      ::restart_replay()
    else
      ::restart_current_mission()
  }

  function sendDisconnectMessage()
  {
    ::broadcastEvent("PlayerQuitMission")
    if (::is_multiplayer())
    {
      ::leave_mp_session()
      onResumeRaw()
    }
    else
      quitToDebriefing()
  }

  function quitToDebriefing()
  {
    ::g_orders.disableOrders()
    ::quit_to_debriefing()
    ::interrupt_multiplayer(true)
    onResumeRaw()
  }

  function onQuitMission(obj)
  {
    if (("is_offline_version" in getroottable()) && ::is_offline_version)
      return ::restart_mission();

    if (is_replay_playing())
    {
      quitToDebriefing()
    }
    else if (::get_mission_status() == MISSION_STATUS_RUNNING)
    {
      local text = ""
      if (is_mplayer_host())
        text = loc("flightmenu/questionQuitMissionHost")
      else if (::get_game_mode() == GM_DOMINATION)
      {
        let unitsData = ::g_mis_custom_state.getCurMissionRules().getAvailableToSpawnUnitsData()
        let unitsTexts = ::u.map(unitsData,
                                   function(ud)
                                   {
                                     local res = colorize("userlogColoredText", ::getUnitName(ud.unit))
                                     if (ud.comment.len())
                                       res += loc("ui/parentheses/space", { text = ud.comment })
                                     return res
                                   })
        if (unitsTexts.len())
          text = loc("flightmenu/haveAvailableCrews") + "\n" + ::g_string.implode(unitsTexts, ", ") + "\n\n"

        text += loc("flightmenu/questionQuitMissionInProgress")
      } else
        text = loc("flightmenu/questionQuitMission")
      this.msgBox("question_quit_mission", text,
      [
        ["yes", sendDisconnectMessage],
        ["no"]
      ], "no", { cancel_fn = @() null })
    }
    else if (isMissionFailed)
    {
      let text = loc("flightmenu/questionQuitMission")
      this.msgBox("question_quit_mission", text,
      [
        ["yes", function()
        {
          ::quit_to_debriefing()
          ::interrupt_multiplayer(true)
          ::in_flight_menu(false)
          if (usePause)
            ::pause_game(false)
        }],
        ["no"]
      ], "yes", { cancel_fn = @() null })
    }
    else
    {
      ::quit_mission_after_complete()
      onResumeRaw()
    }
  }

  function onCompleteMission(obj)
  {
    onQuitMission(obj)
  }

  function onQuitGame(obj)
  {
    this.msgBox("question_quit_flight", loc("flightmenu/questionQuitGame"),
      [
        ["yes", exitGame],
        ["no"]
      ], "no", { cancel_fn = @() null })
  }

  function doBailout()
  {
    if (canBailout())
      ::do_player_bailout()

    onResume(null)
  }

  function onBailout(obj)
  {
    if (canBailout())
    {
      this.msgBox("question_bailout", getPlayerCurUnit()?.unitType.getBailoutQuestionText() ?? "",
        [
          ["yes", doBailout],
          ["no"]
        ], "no", { cancel_fn = @() null })
    }
    else
      onResume(null)
  }

  function onControlsHelp()
  {
    ::gui_modal_help(false, HELP_CONTENT_SET.MISSION)
  }

  onStats = @() guiStartMPStatScreen()

  function onMenuBtnHover(obj)
  {
    if (!checkObj(obj))
      return
    let id = obj.id
    let isHover = obj.isHovered()
    if (!isHover && id != lastSelectedBtnId)
      return
    lastSelectedBtnId = isHover ? id : null
  }

  function onFreecam(obj)
  {
    onResumeRaw()

    if ("toggle_freecam" in getroottable())
      ::toggle_freecam()
  }
}

::quit_mission <- function quit_mission()
{
  ::in_flight_menu(false)
  ::pause_game(false)
  ::gui_start_hud()
  ::broadcastEvent("PlayerQuitMission")

  if (::is_multiplayer())
    return ::leave_mp_session()

  ::quit_to_debriefing()
  ::interrupt_multiplayer(true)
}
