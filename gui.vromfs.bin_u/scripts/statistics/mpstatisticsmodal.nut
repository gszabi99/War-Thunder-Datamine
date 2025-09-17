from "%scripts/dagui_natives.nut" import get_multiplayer_time_left
from "%scripts/dagui_library.nut" import *
from "gameplayBinding" import closeIngameGui, inFlightMenu, setMuteSoundInFlightMenu

let { g_hud_event_manager } = require("%scripts/hud/hudEventManager.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { get_game_type } = require("mission")
let { needUseHangarDof } = require("%scripts/viewUtils/hangarDof.nut")
let { MISSION_STATUS_SUCCESS, MISSION_STATUS_FAIL, quit_to_debriefing,
  interrupt_multiplayer, quit_mission_after_complete, get_mission_status} = require("guiMission")
let { openPersonalTasks } = require("%scripts/unlocks/personalTasks.nut")
let { create_ObjMoveToOBj } = require("%sqDagui/guiBhv/bhvAnim.nut")
let { showActivateOrderButton, orderCanBeActivated } = require("%scripts/items/orders.nut")
let { registerRespondent } = require("scriptRespondent")
let { isLoggedIn } = require("%appGlobals/login/loginState.nut")
let { getCurMpTitle } = require("%scripts/statistics/mpStatisticsUtil.nut")
let { updateReplayMatchingPlayersInfoFromMplayerList } = require("%scripts/replays/replayMetadata.nut")

let MPStatisticsModal = class (gui_handlers.MPStatistics) {
  sceneBlkName = "%gui/mpStatistics.blk"
  sceneNavBlkName = "%gui/navMpStat.blk"
  shouldBlurSceneBgFn = needUseHangarDof
  keepLoaded = true

  wasTimeLeft = -1
  isFromGame = false
  isWideScreenStatTbl = true
  showAircrafts = true
  isResultMPStatScreen = false

  function initScreen() {
    setMuteSoundInFlightMenu(false)
    inFlightMenu(true)

    
    this.isModeStat = true
    this.isRespawn = true
    this.isSpectate = false
    this.isTeam  = true

    let tblObj1 = this.scene.findObject("table_kills_team1")
    if (tblObj1.childrenCount() == 0)
      this.initStats()

    if (this.gameType & GT_COOPERATIVE) {
      this.scene.findObject("team1-root").show(false)
      this.isTeam = false
    }

    this.includeMissionInfoBlocksToGamercard()
    this.setSceneTitle(getCurMpTitle())
    this.setSceneMissionEnviroment()
    updateReplayMatchingPlayersInfoFromMplayerList()
    this.refreshPlayerInfo()

    showObjById("btn_back", true, this.scene)

    this.wasTimeLeft = -1
    this.scene.findObject("stat_update").setUserData(this)
    this.isStatScreen = true
    this.forceUpdate()
    this.updateListsButtons()

    this.updateStats()

    showObjById("btn_activateorder", !this.isResultMPStatScreen && showActivateOrderButton(), this.scene)
    let ordersButton = this.scene.findObject("btn_activateorder")
    if (checkObj(ordersButton)) {
      ordersButton.setUserData(this)
      ordersButton.inactiveColor = !orderCanBeActivated() ? "yes" : "no"
    }

    let canUseUnlocks = (get_game_type() & GT_USE_UNLOCKS) != 0
    showObjById("btn_personal_tasks", !this.isResultMPStatScreen && canUseUnlocks, this.scene)

    this.showMissionResult()
    this.selectLocalPlayer()
    this.scene.findObject("table_kills_team2").setValue(-1)
  }

  onPersonalTasksOpen = @() openPersonalTasks()

  function reinitScreen(params) {
    updateReplayMatchingPlayersInfoFromMplayerList()
    this.setParams(params)
    setMuteSoundInFlightMenu(false)
    inFlightMenu(true)
    this.forceUpdate()
    this.guiScene.performDelayed(this, this.selectLocalPlayer)
    this.showMissionResult()
  }

  function forceUpdate() {
    this.updateCooldown = -1
    this.onUpdate(null, 0.0)
  }

  function onUpdate(_obj, dt) {
    let timeLeft = get_multiplayer_time_left()
    local timeDif = this.wasTimeLeft - timeLeft
    if (timeDif < 0)
      timeDif = -timeDif
    if (timeDif >= 1 || ((this.wasTimeLeft * timeLeft) < 0)) {
      this.setGameEndStat(timeLeft)
      this.wasTimeLeft = timeLeft
    }
    this.updateTimeToKick(dt)
    this.updateTables(dt)
  }

  function goBack(_obj) {
    if (this.isResultMPStatScreen) {
      this.quitToDebriefing()
      return
    }
    inFlightMenu(false)
    if (this.isFromGame)
      closeIngameGui()
    else
      gui_handlers.BaseGuiHandlerWT.goBack.bindenv(this)()
  }

  function onApply() {
    this.goBack(null)
  }

  function onHideHUD(_obj) {}

  function quitToDebriefing() {
    if (get_mission_status() == MISSION_STATUS_SUCCESS) {
      quit_mission_after_complete()
      return
    }

    let text = loc("flightmenu/questionQuitMission")
    this.msgBox("question_quit_mission", text,
      [
        ["yes", function() {
          quit_to_debriefing()
          interrupt_multiplayer(true)
          inFlightMenu(false)
        }],
        ["no"]
      ], "yes", { cancel_fn = @() null })
  }

  function showMissionResult() {
    if (!this.isResultMPStatScreen)
      return

    this.scene.findObject("root-box").bgrStyle = "transparent"
    this.scene.findObject("nav-help").hasMaxWindowSize = "yes"
    this.scene.findObject("flight_menu_bgd").hasMissionResultPadding = "yes"
    this.scene.findObject("btn_back").setValue(loc("flightmenu/btnQuitMission"))
    this.updateMissionResultText()
    g_hud_event_manager.subscribe("MissionResult", this.updateMissionResultText, this)
  }

  function updateMissionResultText(_eventData = null) {
    let resultIdx = get_mission_status()
    if (resultIdx != MISSION_STATUS_SUCCESS && resultIdx != MISSION_STATUS_FAIL)
      return

    let view = {
      text = loc(resultIdx == MISSION_STATUS_SUCCESS ? "MISSION_SUCCESS" : "MISSION_FAIL")
      resultIdx = resultIdx
      useMoveOut = true
    }

    let nest = this.scene.findObject("mission_result_nest")
    let needShowAnimation = !nest.isVisible()
    nest.show(true)
    if (!needShowAnimation)
      return

    let blk = handyman.renderCached("%gui/hud/messageStack/missionResultMessage.tpl", view)
    this.guiScene.replaceContentFromText(nest, blk, blk.len(), this)
    let objTarget = nest.findObject("mission_result_box")
    objTarget.show(true)
    create_ObjMoveToOBj(this.scene, this.scene.findObject("mission_result_box_start"),
      objTarget, { time = 0.5, bhvFunc = "elasticSmall" })
  }
}

gui_handlers.MPStatisticsModal <- MPStatisticsModal

registerRespondent("is_mpstatscreen_active", function is_mpstatscreen_active() { 
  if (!isLoggedIn.get())
    return false
  let curHandler = handlersManager.getActiveBaseHandler()
  return curHandler != null && (curHandler instanceof gui_handlers.MPStatisticsModal)
})
