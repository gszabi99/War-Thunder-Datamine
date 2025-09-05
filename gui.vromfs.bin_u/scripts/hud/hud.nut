from "%scripts/dagui_natives.nut" import is_tank_damage_indicator_visible, is_freecam_enabled, is_hero_highquality, set_option_hud_screen_safe_area, is_cursor_visible_in_gui, set_hud_width_limit, get_mp_kick_countdown
from "%scripts/dagui_library.nut" import *
from "%scripts/hud/hudConsts.nut" import HUD_VIS_PART, HUD_TYPE
from "%scripts/utils_sa.nut" import is_multiplayer

let { get_current_mission_info_cached } = require("blkGetters")
let { g_hud_tutorial_elements } = require("%scripts/hud/hudTutorialElements.nut")
let { g_hud_live_stats } = require("%scripts/hud/hudLiveStats.nut")
let { HudBattleLog } = require("%scripts/hud/hudBattleLog.nut")
let { g_hud_vis_mode } =  require("%scripts/hud/hudVisMode.nut")
let { g_hud_message_stack } = require("%scripts/hud/hudMessageStack.nut")
let { g_hud_event_manager } = require("%scripts/hud/hudEventManager.nut")
let { serverMessageUpdateScene } = require("%scripts/hud/serverMessages.nut")
let { get_in_battle_time_to_kick_show_timer, get_in_battle_time_to_kick_show_alert } = require("%scripts/statistics/mpStatisticsUtil.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { isDmgIndicatorVisible } = require("gameplayBinding")
let u = require("%sqStdLibs/helpers/u.nut")
let { isXInputDevice } = require("controls")
let { get_time_msec } = require("dagor.time")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { format } = require("string")
let { eventbus_send, eventbus_subscribe } = require("eventbus")
let SecondsUpdater = require("%sqDagui/timer/secondsUpdater.nut")
let time = require("%scripts/time.nut")
let { isProgressVisible, getHudUnitType, hud_is_in_cutscene, is_hud_visible, shouldShowSubmarineMinimap } = require("hudState")
let safeAreaHud = require("%scripts/options/safeAreaHud.nut")
let { useTouchscreen } = require("%scripts/clientState/touchScreen.nut")
let { getActionBarItems, getActionBarUnitName } = require("hudActionBar")
let { is_replay_playing } = require("replays")
let { hitCameraInit, hitCameraReinit, getHitCameraAABB } = require("%scripts/hud/hudHitCamera.nut")
let { hudTypeByHudUnitType } = require("%scripts/hud/hudUnitType.nut")
let { is_benchmark_game_mode, get_game_mode } = require("mission")
let updateExtWatched = require("%scripts/global/updateExtWatched.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { USEROPT_DAMAGE_INDICATOR_SIZE, USEROPT_TACTICAL_MAP_SIZE, USEROPT_HUD_VISIBLE_KILLLOG,
  USEROPT_HUD_VISIBLE_CHAT_PLACE, USEROPT_HUD_VISIBLE_ORDERS, OPTIONS_MODE_GAMEPLAY
} = require("%scripts/options/optionsExtNames.nut")
let { maybeOfferControlsHelp } = require("%scripts/hud/maybeOfferControlsHelp.nut")
let { HudAir } = require("%scripts/hud/hudAir.nut")
let { HudTank } = require("%scripts/hud/hudTank.nut")
let { HudShip } = require("%scripts/hud/hudShip.nut")
let { HudHeli } = require("%scripts/hud/hudHeli.nut")



let { HudCutscene } = require("%scripts/hud/hudCutscene.nut")
let { enableOrders } = require("%scripts/items/orders.nut")
let { initMpChatStates } = require("%scripts/chat/mpChatState.nut")
let { loadGameChatToObj, detachGameChatSceneData } = require("%scripts/chat/mpChat.nut")
let { isInKillerCamera, updateHudStatesSubscribes } = require("%scripts/hud/hudState.nut")
let { clearStreaks, onUpdateStreaks } =  require("%scripts/streaks.nut")
let { get_gui_option_in_mode } = require("%scripts/options/options.nut")
let { get_option } = require("%scripts/options/optionsExt.nut")
let { getUnmappedControlsForCurrentMission } = require("%scripts/controls/controlsUtils.nut")
let { isPlayerDedicatedSpectator } = require("%scripts/matchingRooms/sessionLobbyMembersInfo.nut")
let { isAAComplexMenuActive } = require("%appGlobals/hud/hudState.nut")

dagui_propid_add_name_id("fontSize")

let UNMAPPED_CONTROLS_WARNING_TIME_WINK = 3.0
let getUnmappedControlsWarningTime = @() get_game_mode() == GM_TRAINING ? 180000.0 : 30.0
local defaultFontSize = "small"

let getMissionProgressHeight = @() isProgressVisible() ? to_pixels("@missionProgressHeight") : 0

function getCurActionBar() {
  let handler = handlersManager.findHandlerClassInScene(gui_handlers.Hud)
  return handler?.currentHud.actionBar
}

eventbus_subscribe("collapseActionBar", @(_) getCurActionBar()?.collapse())
eventbus_subscribe("getActionBarState", function(_) {
  let actionBar = getCurActionBar()
  if (actionBar != null)
    eventbus_send("setActionBarState", actionBar.getState())
})
eventbus_subscribe("getHudHitCameraState", function(_) {
  eventbus_send("setHudHitCameraState", getHitCameraAABB())
})

eventbus_subscribe("preload_ingame_scenes", function preload_ingame_scenes(...) {
  handlersManager.clearScene()
  handlersManager.loadHandler(gui_handlers.Hud)
  initMpChatStates()
})

gui_handlers.Hud <- class (gui_handlers.BaseGuiHandlerWT) {
  sceneBlkName         = "%gui/hud/hud.blk"
  keepLoaded           = true
  wndControlsAllowMask = CtrlsInGui.CTRL_ALLOW_FULL

  ucWarningActive   = false
  ucWarningTimeShow = 0.0
  ucNoWinkTime      = 0.0
  ucPrevList        = []
  spectatorMode     = false
  hudType    = HUD_TYPE.NONE
  isXinput   = false
  currentHud = null
  isLowQualityWarningVisible = false
  curTacticalMapObj = null
  afkTimeToKick = null
  curHudVisMode = null
  curChatData = null
  isReinitDelayed = false
  needVoiceChat = false
  sideBlockMaxWidth = null
  isTacticalMapVisibleBySubmarineDepth = true

  objectsTable = {
    [USEROPT_DAMAGE_INDICATOR_SIZE] = {
      objectsToScale = {
        hud_tank_damage_indicator = "@sizeDamageIndicatorFull"
        xray_render_dmg_indicator = "@sizeDamageIndicator"
      }
      objectsToCheckOversize = {
        hud_tank_damage_indicator = true
      }
      fontSizeByScale = {
        hud_tank_damage_indicator = {
          [-2] = "extraTiny",
          [-1] = "tiny",
          [0] = "small",
          [1] = "small",
          [2] = "normal"
        }
      }
      onChangedFunc = @(_obj) g_hud_event_manager.onHudEvent("DamageIndicatorSizeChanged")
    },
    [USEROPT_TACTICAL_MAP_SIZE] = {
      objectsToScale = {
        hud_tank_tactical_map     = "@sizeTacticalMap"
        hud_air_tactical_map      = "@sizeTacticalMap"
      }
      objectsToCheckOversize = {
        hud_tank_tactical_map = true
      }
      onChangedFunc = null
    }
  }

  function initScreen() {
    this.initDargWidgetsList()
    ::init_options()
    g_hud_event_manager.init()
    updateHudStatesSubscribes()
    clearStreaks()
    this.initSubscribes()

    set_hud_width_limit(safeAreaHud.getSafearea()[0])
    set_option_hud_screen_safe_area(safeAreaHud.getValue())

    this.isXinput = isXInputDevice()
    this.spectatorMode = isPlayerDedicatedSpectator() || is_replay_playing()
    this.isTacticalMapVisibleBySubmarineDepth = shouldShowSubmarineMinimap()
    eventbus_send("updateIsSpectatorMode", this.spectatorMode)
    this.unmappedControlsCheck()
    this.warnLowQualityModelCheck()
    this.switchHud(this.getHudType())
    this.loadGameChat()

    this.scene.findObject("hud_update").setUserData(this)
    let gm = get_game_mode()
    showObjById("stats", (gm == GM_DOMINATION || gm == GM_SKIRMISH), this.scene)
    showObjById("voice", (gm == GM_DOMINATION || gm == GM_SKIRMISH), this.scene)

    HudBattleLog.init()
    g_hud_message_stack.init(this.scene)
    g_hud_message_stack.clearMessageStacks()
    g_hud_live_stats.init(this.scene, "hud_live_stats_nest", !this.spectatorMode && is_multiplayer())
    ::g_hud_hints_manager.init(this.scene)
    g_hud_tutorial_elements.init(this.scene)

    this.updateControlsAllowMask()
  }

  function initDargWidgetsList() {
    let hudWidgetId = useTouchscreen ? DargWidgets.HUD_TOUCH : DargWidgets.HUD
    this.widgetsList = [
      { widgetId = hudWidgetId }
      { widgetId = DargWidgets.SCOREBOARD }
    ]
  }

  function updateControlsAllowMask() {
    local mask = this.spectatorMode
      ? CtrlsInGui.CTRL_ALLOW_MP_STATISTICS | CtrlsInGui.CTRL_ALLOW_MP_CHAT
        | CtrlsInGui.CTRL_ALLOW_FLIGHT_MENU | CtrlsInGui.CTRL_ALLOW_SPECTATOR
        | CtrlsInGui.CTRL_ALLOW_TACTICAL_MAP
      : CtrlsInGui.CTRL_ALLOW_FULL

    if (showConsoleButtons.get() && is_cursor_visible_in_gui())
      mask = mask & ~CtrlsInGui.CTRL_ALLOW_VEHICLE_XINPUT

    this.switchControlsAllowMask(mask)
  }

   function onSceneActivate(show) {
    enableOrders(this.scene.findObject("order_status"))
    base.onSceneActivate(show)
  }

  function loadGameChat() {
    if (this.curChatData) {
      detachGameChatSceneData(this.curChatData)
      this.curChatData = null
    }
    if (is_multiplayer())
      this.curChatData = loadGameChatToObj(this.scene.findObject("chatPlace"), "%gui/chat/gameChat.blk", this,
        { selfHideInput = true, selfHideLog = true, selectInputIfFocusLost = true })
  }

  function reinitScreen(params = {}) {
    this.isReinitDelayed = !this.scene.isVisible() 
    if (this.isReinitDelayed)
      return

    this.setParams(params)
    if (this.switchHud(this.getHudType()))
      this.loadGameChat()
    else {
      if (this.currentHud && ("reinitScreen" in this.currentHud))
        this.currentHud.reinitScreen()
      hitCameraReinit()
    }
    g_hud_message_stack.reinit()
    g_hud_live_stats.reinit()
    ::g_hud_hints_manager.reinit(this.scene)
    g_hud_tutorial_elements.reinit()

    this.isTacticalMapVisibleBySubmarineDepth = shouldShowSubmarineMinimap()
    this.unmappedControlsCheck()
    this.warnLowQualityModelCheck()
    this.updateHudVisMode()
    this.onHudUpdate(null, 0.0)
  }

  function initSubscribes() {
    g_hud_event_manager.subscribe("ReinitHud", function(_eventData) {
        this.reinitScreen()
      }, this)
    g_hud_event_manager.subscribe("Cutscene", function(_eventData) {
        this.reinitScreen()
      }, this)
    g_hud_event_manager.subscribe("LiveStatsVisibilityToggled",
        @(_ed) this.warnLowQualityModelCheck(),
        this)
    g_hud_event_manager.subscribe("hudProgress:visibilityChanged",
      @(_eventData) this.updateMissionProgressPlace(), this)
    g_hud_event_manager.subscribe("tacticalMapVisibility:bySubmarineDepth",
      @(eventData) this.updateTacticalMapVisibility(eventData.shouldShow), this)
  }

  function onShowHud(show = true, needApplyPending = true) {
    if (this.currentHud && ("onShowHud" in this.currentHud))
      this.currentHud.onShowHud(show, needApplyPending)
    base.onShowHud(show, needApplyPending)
    if (show && this.isReinitDelayed)
      this.reinitScreen()
  }

  function switchHud(newHudType) {
    if (!checkObj(this.scene))
      return false

    if (newHudType == this.hudType) {
      if (this.isXinput == isXInputDevice())
        return false

      this.isXinput = isXInputDevice()
    }

    let hudObj = this.scene.findObject("hud_obj")
    if (!checkObj(hudObj))
      return false

    this.currentHud?.onDestroy()
    this.guiScene.replaceContentFromText(hudObj, "", 0, this)

    if (newHudType == HUD_TYPE.CUTSCENE)
      this.currentHud = handlersManager.loadHandler(HudCutscene, { scene = hudObj })
    else if (newHudType == HUD_TYPE.SPECTATOR)
      this.currentHud = handlersManager.loadHandler(gui_handlers.Spectator, { scene = hudObj })
    else if (newHudType == HUD_TYPE.AIR)
      this.currentHud = handlersManager.loadHandler(HudAir, { scene = hudObj })
    else if (newHudType == HUD_TYPE.TANK)
      this.currentHud = handlersManager.loadHandler(HudTank, { scene = hudObj })
    else if (newHudType == HUD_TYPE.SHIP)
      this.currentHud = handlersManager.loadHandler(HudShip, { scene = hudObj })
    else if (newHudType == HUD_TYPE.HELICOPTER)
      this.currentHud = handlersManager.loadHandler(HudHeli, { scene = hudObj })




    else 
      this.currentHud = null

    showObjById("ship_obstacle_rf", newHudType == HUD_TYPE.SHIP, this.scene)

    this.hudType = newHudType

    this.onHudSwitched()
    broadcastEvent("HudTypeSwitched")
    maybeOfferControlsHelp()
    return true
  }

  function onHudSwitched() {
    handlersManager.updateWidgets()
    this.updateHudVisModeForce()
    hitCameraInit(this.scene.findObject("hud_hitcamera"))

    
    enableOrders(this.scene.findObject("order_status"))

    this.updateObjectsSize()
    this.updateMissionProgressPlace()
  }

  function onEventChangedCursorVisibility(_params) {
    if (showConsoleButtons.get())
      this.updateControlsAllowMask()
  }

  function onEventHudActionbarInited(params) {
    this.updateObjectsSize(params)
  }

  function updateObjectsSize(params = null) {
    let actionBarItemsAmount = params?.actionBarItemsAmount ?? getActionBarItems().len()
    if (actionBarItemsAmount) {
      let actionBarSize = to_pixels("1@hudActionBarItemSize")
      let actionBarOffset = to_pixels("1@hudActionBarItemOffset")
      let screenWidth = to_pixels("sw")
      let borderWidth = to_pixels("1@bwHud")
      let actionBarWidth = actionBarItemsAmount * actionBarSize + (actionBarItemsAmount + 1) * actionBarOffset

      this.sideBlockMaxWidth = (screenWidth - actionBarWidth) / 2 - borderWidth - to_pixels("1@blockInterval")
    }
    else
      this.sideBlockMaxWidth = null

    this.changeObjectsSize(USEROPT_DAMAGE_INDICATOR_SIZE)
    this.changeObjectsSize(USEROPT_TACTICAL_MAP_SIZE)
  }

  
  function getHudType() {
    if (hud_is_in_cutscene())
      return HUD_TYPE.CUTSCENE
    if (this.spectatorMode)
      return HUD_TYPE.SPECTATOR
    if (is_benchmark_game_mode() && !get_current_mission_info_cached()?.forceHudInBenchmark)
      return HUD_TYPE.BENCHMARK
    if (is_freecam_enabled())
      return HUD_TYPE.FREECAM
    
    if (getActionBarUnitName() == "dummy_plane")
      return HUD_TYPE.NONE
    return hudTypeByHudUnitType?[getHudUnitType()] ?? HUD_TYPE.NONE
  }

  function updateHudVisMode(forceUpdate = false) {
    let visMode = g_hud_vis_mode.getCurMode()
    if (!forceUpdate && visMode == this.curHudVisMode)
      return
    this.curHudVisMode = visMode

    let isDmgPanelVisible = !isInKillerCamera.get()
      && visMode.isPartVisible(HUD_VIS_PART.DMG_PANEL)
      && is_tank_damage_indicator_visible()

    let isTacticalMapVisible = !isInKillerCamera.get()
      && !isAAComplexMenuActive.get()
      && visMode.isPartVisible(HUD_VIS_PART.MAP)
      && this.isTacticalMapVisibleBySubmarineDepth

    let objsToShow = {
      xray_render_dmg_indicator  = isDmgPanelVisible
      hud_tank_damage_indicator  = isDmgPanelVisible
      tank_background            = isDmgIndicatorVisible() && isDmgPanelVisible
      hud_tank_tactical_map_nest = isTacticalMapVisible
      hud_kill_log               = get_gui_option_in_mode(USEROPT_HUD_VISIBLE_KILLLOG, OPTIONS_MODE_GAMEPLAY, true)
      chatPlace                  = get_gui_option_in_mode(USEROPT_HUD_VISIBLE_CHAT_PLACE, OPTIONS_MODE_GAMEPLAY, true)
      hud_enemy_damage_nest      = visMode.isPartVisible(HUD_VIS_PART.KILLCAMERA)
      order_status               = get_gui_option_in_mode(USEROPT_HUD_VISIBLE_ORDERS, OPTIONS_MODE_GAMEPLAY, true)
    }

    updateExtWatched({
      isChatPlaceVisible = objsToShow.chatPlace
      isOrderStatusVisible = objsToShow.order_status
    })

    this.guiScene.setUpdatesEnabled(false, false)
    showObjectsByTable(this.scene, objsToShow)
    this.guiScene.setUpdatesEnabled(true, true)
  }

  function updateTacticalMapVisibility(shouldShow) {
    this.isTacticalMapVisibleBySubmarineDepth = shouldShow
    showObjById("hud_tank_tactical_map_nest", shouldShow, this.scene)
  }

  updateHudVisModeForce = @() this.updateHudVisMode(true)
  onEventChangedPartHudVisible = @(_) this.doWhenActiveOnce("updateHudVisModeForce")

  function onHudUpdate(_obj = null, dt = 0.0) {
    onUpdateStreaks(dt)
    this.unmappedControlsUpdate(dt)
    this.updateAFKTimeKickText(dt)
  }

  function unmappedControlsCheck() {
    if (this.spectatorMode || !is_hud_visible())
      return

    let unmapped = getUnmappedControlsForCurrentMission()

    if (!unmapped.len()) {
      if (this.ucWarningActive) {
        this.ucPrevList = unmapped
        this.ucWarningTimeShow = 0.0
        this.unmappedControlsUpdate()
      }
      return
    }

    if (u.isEqual(unmapped, this.ucPrevList))
      return

    let warningObj = this.scene.findObject("unmapped_shortcuts_warning")
    if (!checkObj(warningObj))
      return

    let unmappedLocalized = unmapped.map(@(v) loc(v))
    let text = "".concat(loc("controls/warningUnmapped"), loc("ui/colon"), "\n",
      loc("ui/comma").join(unmappedLocalized, true))
    warningObj.setValue(text)
    warningObj.show(true)
    warningObj.wink = "yes"

    this.ucWarningTimeShow = getUnmappedControlsWarningTime()
    this.ucNoWinkTime = this.ucWarningTimeShow - UNMAPPED_CONTROLS_WARNING_TIME_WINK
    this.ucPrevList = unmapped
    this.ucWarningActive = true
    this.unmappedControlsUpdate()
  }

  function unmappedControlsUpdate(dt = 0.0) {
    if (!this.ucWarningActive)
      return

    let winkingOld = this.ucWarningTimeShow > this.ucNoWinkTime
    this.ucWarningTimeShow -= dt
    let winkingNew = this.ucWarningTimeShow > this.ucNoWinkTime

    if (this.ucWarningTimeShow <= 0 || winkingOld != winkingNew) {
      let warningObj = this.scene.findObject("unmapped_shortcuts_warning")
      if (!checkObj(warningObj))
        return

      warningObj.wink = "no"

      if (this.ucWarningTimeShow <= 0) {
        warningObj.show(false)
        this.ucWarningActive = false
      }
    }
  }

  function warnLowQualityModelCheck() {
    if (this.spectatorMode || !is_hud_visible())
      return

    let isShow = !is_hero_highquality() && !g_hud_live_stats.isVisible()
    if (isShow == this.isLowQualityWarningVisible)
      return

    this.isLowQualityWarningVisible = isShow
    showObjById("low-quality-model-warning", isShow, this.scene)
  }

  function onEventHudIndicatorChangedSize(params) {
    let option = getTblValue("option", params, -1)
    if (option < 0)
      return

    this.changeObjectsSize(option)
  }

  function changeObjectsSize(optionNum) {
    let option = get_option(optionNum)
    let value = (option && option.value != null) ? option.value : 0
    let vMax   = (option?.max ?? 0) != 0 ? option.max : 2
    let size = 1.0 + 0.333 * value / vMax

    let table = getTblValue(optionNum, this.objectsTable, {})
    foreach (id, cssConst in getTblValue("objectsToScale", table, {})) {
      let obj = this.scene.findObject(id)
      if (!checkObj(obj))
        continue

      let objWidth = format("%.3f*%s", size, cssConst)
      let objWidthValue = to_pixels(objWidth)
      let canApplyOptionValue = !table?.objectsToCheckOversize?[id] ||
                                  !this.sideBlockMaxWidth ||
                                  objWidthValue <= this.sideBlockMaxWidth
      let fontSize = table?.fontSizeByScale[id][value]
      if (fontSize != null)
        obj.fontSize = canApplyOptionValue ? fontSize : defaultFontSize
      obj.size = canApplyOptionValue
        ? format("%.3f*%s, %.3f*%s", size, cssConst, size, cssConst)
        : format("%d, %d", this.sideBlockMaxWidth, this.sideBlockMaxWidth)
      this.guiScene.applyPendingChanges(false)

      if (optionNum == USEROPT_TACTICAL_MAP_SIZE)
        this.curTacticalMapObj = obj

      let func = getTblValue("onChangedFunc", table)
      if (func)
        func.call(this, obj)
    }
  }

  function getTacticalMapObj() {
    return this.curTacticalMapObj
  }

  function getMultiplayerScoreObj() {
    return this.scene.findObject("hud_multiplayer_score_progress_bar")
  }

  function getHudActionBarObj() {
    return this.scene.findObject("hud_action_bar")
  }

  function getDamagePannelObj() {
    return this.scene.findObject("xray_render_dmg_indicator")
  }

  function getTankDebufsObj() {
    return this.scene.findObject("tank_debuffs")
  }

  function updateAFKTimeKick() {
    this.afkTimeToKick = get_mp_kick_countdown()
  }

  function updateAFKTimeKickText(sec) {
    let timeToKickAlertObj = this.scene.findObject("time_to_kick_alert_text")
    if (!checkObj(timeToKickAlertObj) || timeToKickAlertObj.getModalCounter() != 0)
      return

    this.updateAFKTimeKick()
    let showAlertText = get_in_battle_time_to_kick_show_alert() >= this.afkTimeToKick
    let showTimerText = get_in_battle_time_to_kick_show_timer() >= this.afkTimeToKick
    let showMessage = this.afkTimeToKick >= 0 && (showTimerText || showAlertText)
    timeToKickAlertObj.show(showMessage)
    if (!showMessage)
      return

    if (showAlertText) {
      timeToKickAlertObj.setValue(this.afkTimeToKick > 0
        ? loc("inBattle/timeToKick", { timeToKick = time.secondsToString(this.afkTimeToKick, true, true) })
        : "")

      let curTime = get_time_msec()
      let prevSeconds = ((curTime - 1000 * sec) / 1000).tointeger()
      let currSeconds = (curTime / 1000).tointeger()

      if (currSeconds != prevSeconds) {
        timeToKickAlertObj["_blink"] = "yes"
        this.guiScene.playSound("kick_alert")
      }
    }
    else if (showTimerText)
      timeToKickAlertObj.setValue(loc("inBattle/timeToKickAlert"))
  }

  
  
  

  function onEventServerMessage(_params) {
    let serverMessageTimerObject = this.scene.findObject("server_message_timer")
    if (checkObj(serverMessageTimerObject)) {
      SecondsUpdater(serverMessageTimerObject, (@(scene) function (_obj, _params) {
        return !serverMessageUpdateScene(scene)
      })(this.scene))
    }
  }

  function updateMissionProgressPlace() {
    let curHud = this.getHudType()
    if (curHud == HUD_TYPE.SHIP || curHud == HUD_TYPE.AIR) {
      eventbus_send("updateMissionProgressHeight", getMissionProgressHeight())
      return
    }

    local obj = this.scene.findObject("mission_progress_place")
    if (!obj?.isValid())
      return

    let isVisible = isProgressVisible()
    if (obj.isVisible() == isVisible)
      return

    obj.show(isVisible)
    this.guiScene.applyPendingChanges(false)
    this.currentHud?.updateDmgIndicatorState()
  }
}

function updateHudVisModeForce() {
  let handler = handlersManager.findHandlerClassInScene(gui_handlers.Hud)
  if (handler == null)
    return
  handler.doWhenActiveOnce("updateHudVisModeForce")
}

isInKillerCamera.subscribe(@(_) updateHudVisModeForce())
isAAComplexMenuActive.subscribe(@(_) updateHudVisModeForce())
