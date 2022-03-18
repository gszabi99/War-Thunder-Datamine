let { needUseHangarDof } = require("scripts/viewUtils/hangarDof.nut")

local MPStatisticsModal = class extends ::gui_handlers.MPStatistics
{
  sceneBlkName = "%gui/mpStatistics.blk"
  sceneNavBlkName = "%gui/navMpStat.blk"
  shouldBlurSceneBgFn = needUseHangarDof
  keepLoaded = true

  wasTimeLeft = -1
  isFromGame = false
  isWideScreenStatTbl = true
  showAircrafts = true
  isResultMPStatScreen = false

  function initScreen()
  {
    ::set_mute_sound_in_flight_menu(false)
    ::in_flight_menu(true)

    //!!init debriefing
    isModeStat = true
    isRespawn = true
    isSpectate = false
    isTeam  = true

    let tblObj1 = scene.findObject("table_kills_team1")
    if (tblObj1.childrenCount() == 0)
      initStats()

    if (gameType & ::GT_COOPERATIVE)
    {
      scene.findObject("team1-root").show(false)
      isTeam = false
    }

    includeMissionInfoBlocksToGamercard()
    setSceneTitle(getCurMpTitle())
    tblObj1.setValue(0)
    scene.findObject("table_kills_team2").setValue(-1)

    refreshPlayerInfo()

    showSceneBtn("btn_back", true)

    wasTimeLeft = -1
    scene.findObject("stat_update").setUserData(this)
    isStatScreen = true
    forceUpdate()
    updateListsButtons()

    updateStats()

    showSceneBtn("btn_activateorder", !isResultMPStatScreen && ::g_orders.showActivateOrderButton())
    let ordersButton = scene.findObject("btn_activateorder")
    if (::checkObj(ordersButton))
    {
      ordersButton.setUserData(this)
      ordersButton.inactiveColor = !::g_orders.orderCanBeActivated() ? "yes" : "no"
    }
    showMissionResult()
  }

  function reinitScreen(params)
  {
    setParams(params)
    ::set_mute_sound_in_flight_menu(false)
    ::in_flight_menu(true)
    forceUpdate()
    if (::is_replay_playing())
      selectLocalPlayer()
    showMissionResult()
  }

  function forceUpdate()
  {
    updateCooldown = -1
    onUpdate(null, 0.0)
  }

  function onUpdate(obj, dt)
  {
    let timeLeft = ::get_multiplayer_time_left()
    local timeDif = wasTimeLeft - timeLeft
    if (timeDif < 0)
      timeDif = -timeDif
    if (timeDif >= 1 || ((wasTimeLeft * timeLeft) < 0))
    {
      setGameEndStat(timeLeft)
      wasTimeLeft = timeLeft
    }
    updateTimeToKick(dt)
    updateTables(dt)
  }

  function goBack(obj)
  {
    if (isResultMPStatScreen) {
      quitToDebriefing()
      return
    }
    ::in_flight_menu(false)
    if (isFromGame)
      ::close_ingame_gui()
    else
      ::gui_handlers.BaseGuiHandlerWT.goBack.bindenv(this)()
  }

  function onApply()
  {
    goBack(null)
  }

  function onHideHUD(obj) {}

  function quitToDebriefing() {
    if (::get_mission_status() == ::MISSION_STATUS_SUCCESS) {
      ::quit_mission_after_complete()
      return
    }

    let text = ::loc("flightmenu/questionQuitMission")
    msgBox("question_quit_mission", text,
      [
        ["yes", function()
          {
          ::quit_to_debriefing()
          ::interrupt_multiplayer(true)
          ::in_flight_menu(false)
        }],
        ["no"]
      ], "yes", { cancel_fn = @() null })
  }

  function showMissionResult() {
    if (!isResultMPStatScreen)
      return

    scene.findObject("root-box").bgrStyle = "transparent"
    scene.findObject("nav-help").hasMaxWindowSize = "yes"
    scene.findObject("flight_menu_bgd").hasMissionResultPadding = "yes"
    scene.findObject("btn_back").setValue(::loc("flightmenu/btnQuitMission"))
    updateMissionResultText()
    ::g_hud_event_manager.subscribe("MissionResult", updateMissionResultText, this)
  }

  function updateMissionResultText(eventData = null) {
    let resultIdx = ::get_mission_status()
    if (resultIdx != ::MISSION_STATUS_SUCCESS && resultIdx != ::MISSION_STATUS_FAIL)
      return

    let view = {
      text = ::loc(resultIdx == ::MISSION_STATUS_SUCCESS ? "MISSION_SUCCESS" : "MISSION_FAIL")
      resultIdx = resultIdx
      useMoveOut = true
    }

    let nest = scene.findObject("mission_result_nest")
    let needShowAnimation = !nest.isVisible()
    nest.show(true)
    if (!needShowAnimation)
      return

    let blk = ::handyman.renderCached("%gui/hud/messageStack/missionResultMessage", view)
    guiScene.replaceContentFromText(nest, blk, blk.len(), this)
    let objTarget = nest.findObject("mission_result_box")
    objTarget.show(true)
    ::create_ObjMoveToOBj(scene, scene.findObject("mission_result_box_start"),
      objTarget, { time = 0.5, bhvFunc = "elasticSmall" })
  }
}

::gui_handlers.MPStatisticsModal <- MPStatisticsModal
