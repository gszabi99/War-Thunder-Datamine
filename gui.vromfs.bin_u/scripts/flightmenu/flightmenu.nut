local { canRestart, canBailout } = require("scripts/flightMenu/flightMenuState.nut")
local flightMenuButtonTypes = require("scripts/flightMenu/flightMenuButtonTypes.nut")
local { openOptionsWnd } = require("scripts/options/handlers/optionsWnd.nut")
local exitGame = require("scripts/utils/exitGame.nut")

::gui_start_flight_menu <- function gui_start_flight_menu()
{
  ::flight_menu_handler = ::handlersManager.loadHandler(::gui_handlers.FlightMenu)
}

::gui_start_flight_menu_failed <- gui_start_flight_menu //it checks MISSION_STATUS_FAIL status itself
::gui_start_flight_menu_psn <- function gui_start_flight_menu_psn() {} //unused atm, but still have a case in code

class ::gui_handlers.FlightMenu extends ::gui_handlers.BaseGuiHandlerWT
{
  sceneBlkName = "gui/flightMenu/flightMenu.blk"
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
    setSceneTitle(getCurMpTitle())

    menuButtonsCfg = flightMenuButtonTypes.types.filter(@(btn) btn.isAvailableInMission())
    local markup = ::handyman.renderCached("gui/flightMenu/menuButtons", { buttons = menuButtonsCfg })
    guiScene.replaceContentFromText(scene.findObject("menu-buttons"), markup, markup.len(), this)

    reinitScreen()
  }

  function reinitScreen(params = null)
  {
    isMissionFailed = ::get_mission_status() == ::MISSION_STATUS_FAIL
    usePause = !::is_game_paused()

    if (!::handlersManager.isFullReloadInProgress)
    {
      ::in_flight_menu(true)
      if (usePause)
        ::pause_game(true)
    }

    updateButtons()
  }

  function updateButtons()
  {
    if (!::check_obj(scene))
      return

    foreach (btn in menuButtonsCfg)
    {
      local isShow = btn.isVisible()
      local btnObj = ::showBtn(btn.buttonId, isShow, scene)
      if (!isShow)
        continue
      local txt = btn.getUpdatedLabelText()
      if (btnObj != null && txt != "")
        btnObj.setValue(txt)
    }

    ::showBtn("btn_back", !isMissionFailed, scene)

    restoreFocus()
  }

  function restoreFocus()
  {
    if (!isSceneActiveNoModals())
      return
    local btnId = lastSelectedBtnId ?? (isMissionFailed ? "btn_restart" : "btn_resume")
    ::move_mouse_on_obj(getObj(btnId))
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

    if ([ ::GM_CAMPAIGN, ::GM_SINGLE_MISSION, ::GM_DYNAMIC ].contains(::get_game_mode()))
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
    if (::get_mission_status() == ::MISSION_STATUS_RUNNING)
    {
      msgBox("question_restart_mission", ::loc("flightmenu/questionRestartMission"),
      [
        ["yes", restartBriefing],
        ["no"]
      ], "no", { cancel_fn = @() null })
    }
    else
    if (::is_replay_playing())
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

    if (::is_replay_playing())
    {
      quitToDebriefing()
    }
    else if (::get_mission_status() == ::MISSION_STATUS_RUNNING)
    {
      local text = ""
      if (::is_mplayer_host())
        text = ::loc("flightmenu/questionQuitMissionHost")
      else if (::get_game_mode() == ::GM_DOMINATION)
      {
        local unitsData = ::g_mis_custom_state.getCurMissionRules().getAvailableToSpawnUnitsData()
        local unitsTexts = ::u.map(unitsData,
                                   function(ud)
                                   {
                                     local res = ::colorize("userlogColoredText", ::getUnitName(ud.unit))
                                     if (ud.comment.len())
                                       res += ::loc("ui/parentheses/space", { text = ud.comment })
                                     return res
                                   })
        if (unitsTexts.len())
          text = ::loc("flightmenu/haveAvailableCrews") + "\n" + ::g_string.implode(unitsTexts, ", ") + "\n\n"

        text += ::loc("flightmenu/questionQuitMissionInProgress")
      } else
        text = ::loc("flightmenu/questionQuitMission")
      msgBox("question_quit_mission", text,
      [
        ["yes", sendDisconnectMessage],
        ["no"]
      ], "no", { cancel_fn = @() null })
    }
    else if (isMissionFailed)
    {
      local text = ::loc("flightmenu/questionQuitMission")
      msgBox("question_quit_mission", text,
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
    msgBox("question_quit_flight", ::loc("flightmenu/questionQuitGame"),
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
      msgBox("question_bailout", ::get_player_cur_unit()?.unitType.getBailoutQuestionText() ?? "",
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

  function onMenuBtnHover(obj)
  {
    if (!::check_obj(obj))
      return
    local id = obj.id
    local isHover = obj.isHovered()
    if (!isHover && id != lastSelectedBtnId)
      return
    lastSelectedBtnId = isHover ? id : null
  }
}

::quit_mission <- function quit_mission()
{
  ::in_flight_menu(false)
  ::pause_game(false)
  gui_start_hud()
  ::broadcastEvent("PlayerQuitMission")

  if (::is_multiplayer())
    return ::leave_mp_session()

  ::quit_to_debriefing()
  ::interrupt_multiplayer(true)
}
