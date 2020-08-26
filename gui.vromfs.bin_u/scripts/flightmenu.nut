local { openOptionsWnd } = require("scripts/options/handlers/optionsWnd.nut")

::gui_start_flight_menu <- function gui_start_flight_menu()
{
  ::flight_menu_handler = ::handlersManager.loadHandler(::gui_handlers.FlightMenu)
}

::gui_start_flight_menu_failed <- function gui_start_flight_menu_failed()
{
  ::flight_menu_handler = ::handlersManager.loadHandler(::gui_handlers.FlightMenu, { isMissionFailed = true })
}

::gui_start_flight_menu_psn <- function gui_start_flight_menu_psn() {} //unused atm, but still have a case in code

class ::gui_handlers.FlightMenu extends ::gui_handlers.BaseGuiHandlerWT
{
  sceneBlkName = "gui/flightMenu.blk"
  shouldBlurSceneBg = true
  keepLoaded = true
  wndControlsAllowMask = CtrlsInGui.CTRL_ALLOW_FLIGHT_MENU

  isMissionFailed = false
  isShowStat = false
  usePause = true


  function initScreen()
  {
    usePause = !::is_game_paused()
    if (!::handlersManager.isFullReloadInProgress)
    {
      ::in_flight_menu(true)
      if (usePause)
        ::pause_game(true)
    }
    setSceneTitle(getCurMpTitle())
    local items = []

    local resumeItem = { name = "Resume", brAfter = true};

    if (isMissionFailed)
      items=["Restart","QuitMission"]
    else
    {
      items=[resumeItem]
      if (::get_game_mode() != ::GM_BENCHMARK)
        items.append("Options", "Controls", "ControlsHelp")
      items.append("Restart", "Bailout", "QuitMission")
    }

    local blkItems =  ::build_menu_blk(items,"#flightmenu/btn", true)
    guiScene.replaceContentFromText(scene.findObject("menu-buttons"), blkItems,
                                     blkItems.len(), this)

    refreshScreen()
  }

  function reinitScreen(params)
  {
    usePause = !::is_game_paused()
    ::in_flight_menu(true)
    if (usePause)
      ::pause_game(true)
    setParams(params)
    refreshScreen()
    restoreFocus()
  }

  function refreshScreen()
  {
    if (!::checkObj(scene))
      return

    local status = ::get_mission_status()
    local gm = ::get_game_mode()
    local isMp = ::is_multiplayer()

    local restartBtnObj = scene.findObject("btn_Restart")
    local quitMisBtnObj = scene.findObject("btn_QuitMission")

    if (isMissionFailed)
    {
      if (::checkObj(restartBtnObj))
      {
        restartBtnObj.show(true)
        restartBtnObj.select()
      }

      if (::checkObj(quitMisBtnObj))
        quitMisBtnObj.show(true)

      ::showBtnTable(scene, {
          btn_back          = false
          btn_resume        = false
          btn_options       = false
          btn_controlshelp  = false
          btn_bailout       = false
      })

      return
    }

    restartBtnObj.show(!isMp
                      && gm != ::GM_DYNAMIC
                      && gm != ::GM_BENCHMARK
                      && status != ::MISSION_STATUS_SUCCESS
                      && !(::get_game_type() & ::GT_COOPERATIVE)
                      )

    local btnBailout = scene.findObject("btn_Bailout")
    if (::checkObj(btnBailout))
    {
      if ((::get_mission_restore_type() != ::ERT_MANUAL || gm == ::GM_TEST_FLIGHT)
          && gm != ::GM_BENCHMARK
          && !::is_camera_not_flight()
          && ::is_player_can_bailout()
          && (status != ::MISSION_STATUS_SUCCESS || !::isInArray(gm, [::GM_CAMPAIGN, ::GM_SINGLE_MISSION, ::GM_DYNAMIC, ::GM_TRAINING, ::GM_BUILDER]))
         )
      {
        local unit = ::get_player_cur_unit()
        local locId = (unit?.isHelicopter?()) ? "flightmenu/btnBailoutHelicopter"
          : ::is_tank_interface() ? "flightmenu/btnLeaveTheTank"
          : "flightmenu/btnBailout"
        local txt = ::loc(locId)
        if (!isMp && ::get_mission_restore_type() == ::ERT_ATTEMPTS)
        {
          local numLeft = ::get_num_attempts_left()
          if (status == ::MISSION_STATUS_SUCCESS && ::get_game_mode() == ::GM_DYNAMIC)
          {
            txt = ::loc("flightmenu/btnCompleteMission")
          }
  //        else if (gm == ::GM_DYNAMIC || gm == ::GM_BUILDER) - we have attempts there now!
  //        {
  //        }
          else if (numLeft < 0)
            txt += " (" + ::loc("options/attemptsUnlimited") + ")"
          else
            txt += " (" + ::get_num_attempts_left() + " " +
            (numLeft == 1 ? ::loc("options/attemptLeft") : ::loc("options/attemptsLeft")) + ")"
        }
        btnBailout.setValue(txt)
        btnBailout.show(true)
      }
      else
        btnBailout.show(false)
    }

    showSceneBtn("btn_controlshelp", ::has_feature("ControlsHelp"))

    local quitMissionText = ::loc("flightmenu/btnQuitMission")
    if (::is_replay_playing())
      quitMissionText = ::loc("flightmenu/btnQuitReplay")
    else if (status == ::MISSION_STATUS_SUCCESS && ::get_game_mode() == ::GM_DYNAMIC)
      quitMissionText = ::loc("flightmenu/btnCompleteMission")

    if (::checkObj(quitMisBtnObj))
      quitMisBtnObj.setValue(quitMissionText)

    local resumeBtnObj = scene.findObject("btn_Resume")
    if (::checkObj(resumeBtnObj))
      resumeBtnObj.select()
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

  function selectRestartMissionBtn()
  {
    local obj = scene.findObject("btn_restart")
    if (::checkObj(obj))
      obj.select()
  }

  function restartBriefing()
  {
    if (("is_offline_version" in getroottable()) && ::is_offline_version)
      return ::restart_mission();

    local gm = ::get_game_mode()
    if (gm == ::GM_CAMPAIGN || gm == ::GM_SINGLE_MISSION || gm == ::GM_DYNAMIC)
    {
       goForward(::gui_start_briefing_restart)
    }
    else
      ::restart_current_mission()
  }

  function onRestart(obj)
  {
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
        ["no", selectRestartMissionBtn]
      ], "no")
    }
    else
    if (::is_replay_playing())
      ::restart_replay()
    else
      ::restart_current_mission()
  }

  function selectQuitMissionBtn()
  {
    local obj = scene.findObject("btn_quitmission")
    if (::checkObj(obj))
      obj.select()
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
    else if ((::get_mission_status() == ::MISSION_STATUS_RUNNING) && !isMissionFailed)
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
        ["no", selectQuitMissionBtn]
      ], "yes", { cancel_fn = function() {}})
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
        ["no", selectQuitMissionBtn]
      ], "yes", { cancel_fn = function() {}})
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

  function selectQuitBtn()
  {
    local obj = scene.findObject("btn_quitgame")
    if (::checkObj(obj))
      obj.select()
  }

  function onQuitGame(obj)
  {
    msgBox("question_quit_flight", ::loc("flightmenu/questionQuitGame"),
      [
        ["yes", ::exit_game],
        ["no", selectQuitBtn]
      ], "no")
  }

  function selectBailoutBtn()
  {
    local obj = scene.findObject("btn_bailout")
    if (::checkObj(obj))
      obj.select()
  }

  function doBailout()
  {
    ::do_player_bailout()

    onResume(null)
  }

  function onBailout(obj)
  {
    if (::is_player_can_bailout())
    {
      local unit = ::get_player_cur_unit()
      local locId = (unit?.isHelicopter?()) ? "flightmenu/questionBailoutHelicopter"
        : ::is_tank_interface() ? "flightmenu/questionLeaveTheTank"
        : "flightmenu/questionBailout"
      msgBox("question_bailout", ::loc(locId),
        [
          ["yes", doBailout],
          ["no", selectBailoutBtn]
        ], "no", { cancel_fn = function() {}})
    }
  }

  function onControlsHelp()
  {
    ::gui_modal_help(false, HELP_CONTENT_SET.MISSION)
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
