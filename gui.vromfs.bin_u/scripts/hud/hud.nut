from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { get_time_msec } = require("dagor.time")
let { format } = require("string")
let { send } = require("eventbus")
let SecondsUpdater = require("%sqDagui/timer/secondsUpdater.nut")
let time = require("%scripts/time.nut")
let { isProgressVisible, getHudUnitType } = require("hudState")
let safeAreaHud = require("%scripts/options/safeAreaHud.nut")
let { showHudTankMovementStates } = require("%scripts/hud/hudTankStates.nut")
let { mpTankHudBlkPath } = require("%scripts/hud/hudBlkPath.nut")
let { isDmgIndicatorVisible } = require_native("gameplayBinding")
let { getPlayerCurUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { initIconedHints } = require("%scripts/hud/iconedHints.nut")
let { useTouchscreen } = require("%scripts/clientState/touchScreen.nut")
let { getActionBarItems, getOwnerUnitName, getActionBarUnitName } = require_native("hudActionBar")
let { is_replay_playing } = require("replays")
let { hitCameraInit, hitCameraReinit } = require("%scripts/hud/hudHitCamera.nut")
let { hudTypeByHudUnitType } = require("%scripts/hud/hudUnitType.nut")

::dagui_propid.add_name_id("fontSize")

let UNMAPPED_CONTROLS_WARNING_TIME_WINK = 3.0
let getUnmappedControlsWarningTime = @() ::get_game_mode() == GM_TRAINING ? 180000.0 : 30.0
local defaultFontSize = "small"

local controlsHelpShownBits = 0
let function maybeOfferControlsHelp() {
  let unit = getPlayerCurUnit()
  if (![ "combat_track_a", "combat_track_h", "combat_tank_a", "combat_tank_h",
      "mlrs_tank_a", "mlrs_tank_h", "acoustic_heavy_tank_a", "destroyer_heavy_tank_h",
      "dragonfly_a", "dragonfly_h" ].contains(unit?.name))
    return
  let utBit = unit?.unitType.bit ?? 0
  if ((controlsHelpShownBits & utBit) != 0)
    return
  controlsHelpShownBits = controlsHelpShownBits | utBit
  ::g_hud_event_manager.onHudEvent("hint:f1_controls_scripted:show", {})
}

::gui_handlers.Hud <- class extends ::gui_handlers.BaseGuiHandlerWT
{
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

  objectsTable = {
    [::USEROPT_DAMAGE_INDICATOR_SIZE] = {
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
      onChangedFunc = @(_obj) ::g_hud_event_manager.onHudEvent("DamageIndicatorSizeChanged")
    },
    [::USEROPT_TACTICAL_MAP_SIZE] = {
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

  function initScreen()
  {
    this.initDargWidgetsList()
    ::init_options()
    ::g_hud_event_manager.init()
    ::g_streaks.clear()
    this.initSubscribes()

    ::set_hud_width_limit(safeAreaHud.getSafearea()[0])
    ::set_option_hud_screen_safe_area(safeAreaHud.getValue())

    this.isXinput = ::is_xinput_device()
    this.spectatorMode = ::isPlayerDedicatedSpectator() || is_replay_playing()
    this.unmappedControlsCheck()
    this.warnLowQualityModelCheck()
    this.switchHud(this.getHudType())
    this.loadGameChat()

    this.scene.findObject("hud_update").setUserData(this)
    let gm = ::get_game_mode()
    this.showSceneBtn("stats", (gm == GM_DOMINATION || gm == GM_SKIRMISH))
    this.showSceneBtn("voice", (gm == GM_DOMINATION || gm == GM_SKIRMISH))

    ::HudBattleLog.init()
    ::g_hud_message_stack.init(this.scene)
    ::g_hud_message_stack.clearMessageStacks()
    ::g_hud_live_stats.init(this.scene, "hud_live_stats_nest", !this.spectatorMode && ::is_multiplayer())
    ::g_hud_hints_manager.init(this.scene)
    ::g_hud_tutorial_elements.init(this.scene)

    this.updateControlsAllowMask()
  }

  function initDargWidgetsList() {
    let hudWidgetId = useTouchscreen ? DargWidgets.HUD_TOUCH : DargWidgets.HUD
    this.widgetsList = [
      { widgetId = hudWidgetId }
      { widgetId = DargWidgets.SCOREBOARD }
    ]
  }

  function updateControlsAllowMask()
  {
    local mask = this.spectatorMode
      ? CtrlsInGui.CTRL_ALLOW_MP_STATISTICS | CtrlsInGui.CTRL_ALLOW_MP_CHAT
        | CtrlsInGui.CTRL_ALLOW_FLIGHT_MENU | CtrlsInGui.CTRL_ALLOW_SPECTATOR
        | CtrlsInGui.CTRL_ALLOW_TACTICAL_MAP
      : CtrlsInGui.CTRL_ALLOW_FULL

    if (::show_console_buttons && ::is_cursor_visible_in_gui())
      mask = mask & ~CtrlsInGui.CTRL_ALLOW_VEHICLE_XINPUT

    this.switchControlsAllowMask(mask)
  }

  /*override*/ function onSceneActivate(show)
  {
    ::g_orders.enableOrders(this.scene.findObject("order_status"))
    base.onSceneActivate(show)
  }

  function loadGameChat()
  {
    if (this.curChatData)
    {
      ::detachGameChatSceneData(this.curChatData)
      this.curChatData = null
    }
    if (::is_multiplayer())
      this.curChatData = ::loadGameChatToObj(this.scene.findObject("chatPlace"), "%gui/chat/gameChat.blk", this,
        { selfHideInput = true, selfHideLog = true, selectInputIfFocusLost = true })
  }

  function reinitScreen(params = {})
  {
    this.isReinitDelayed = !this.scene.isVisible() //hud not visible. we just wait for show_hud event
    if (this.isReinitDelayed)
      return

    this.setParams(params)
    if (this.switchHud(this.getHudType()))
      this.loadGameChat()
    else
    {
      if (this.currentHud && ("reinitScreen" in this.currentHud))
        this.currentHud.reinitScreen()
      hitCameraReinit()
    }
    ::g_hud_message_stack.reinit()
    ::g_hud_live_stats.reinit()
    ::g_hud_hints_manager.reinit()
    ::g_hud_tutorial_elements.reinit()

    this.unmappedControlsCheck()
    this.warnLowQualityModelCheck()
    this.updateHudVisMode()
    this.onHudUpdate(null, 0.0)
  }

  function initSubscribes()
  {
    ::g_hud_event_manager.subscribe("ReinitHud", function(_eventData)
      {
        this.reinitScreen()
      }, this)
    ::g_hud_event_manager.subscribe("Cutscene", function(_eventData)
      {
        this.reinitScreen()
      }, this)
    ::g_hud_event_manager.subscribe("LiveStatsVisibilityToggled",
        @(_ed) this.warnLowQualityModelCheck(),
        this)

    ::g_hud_event_manager.subscribe("hudProgress:visibilityChanged",
      @(_eventData) this.updateMissionProgressPlace(), this)
  }

  function onShowHud(show = true, needApplyPending = true)
  {
    if (this.currentHud && ("onShowHud" in this.currentHud))
      this.currentHud.onShowHud(show, needApplyPending)
    base.onShowHud(show, needApplyPending)
    if (show && this.isReinitDelayed)
      this.reinitScreen()
  }

  function switchHud(newHudType)
  {
    if (!checkObj(this.scene))
      return false

    if (newHudType == this.hudType)
    {
      if (this.isXinput == ::is_xinput_device())
        return false

      this.isXinput = ::is_xinput_device()
    }

    let hudObj = this.scene.findObject("hud_obj")
    if (!checkObj(hudObj))
      return false

    this.guiScene.replaceContentFromText(hudObj, "", 0, this)

    if (newHudType == HUD_TYPE.CUTSCENE)
      this.currentHud = ::handlersManager.loadHandler(::HudCutscene, { scene = hudObj })
    else if (newHudType == HUD_TYPE.SPECTATOR)
      this.currentHud = ::handlersManager.loadHandler(::Spectator, { scene = hudObj })
    else if (newHudType == HUD_TYPE.AIR)
      this.currentHud = ::handlersManager.loadHandler(::HudAir, { scene = hudObj })
    else if (newHudType == HUD_TYPE.TANK)
      this.currentHud = ::handlersManager.loadHandler(::HudTank, { scene = hudObj })
    else if (newHudType == HUD_TYPE.SHIP)
      this.currentHud = ::handlersManager.loadHandler(::HudShip, { scene = hudObj })
    else if (newHudType == HUD_TYPE.HELICOPTER)
      this.currentHud = ::handlersManager.loadHandler(::HudHelicopter, { scene = hudObj })
    else //newHudType == HUD_TYPE.NONE
      this.currentHud = null

    this.showSceneBtn("ship_obstacle_rf", newHudType == HUD_TYPE.SHIP)

    this.hudType = newHudType

    this.onHudSwitched()
    ::broadcastEvent("HudTypeSwitched")
    return true
  }

  function onHudSwitched()
  {
    ::handlersManager.updateWidgets()
    this.updateHudVisMode(::FORCE_UPDATE)
    hitCameraInit(this.scene.findObject("hud_hitcamera"))

    // All required checks are performed internally.
    ::g_orders.enableOrders(this.scene.findObject("order_status"))

    this.updateObjectsSize()
    this.updateMissionProgressPlace()
  }

  function onEventChangedCursorVisibility(_params)
  {
    if (::show_console_buttons)
      this.updateControlsAllowMask()
  }

  function onEventHudActionbarInited(params)
  {
    this.updateObjectsSize(params)
  }

  function updateObjectsSize(params = null)
  {
    let actionBarItemsAmount = params?.actionBarItemsAmount ?? getActionBarItems().len()
    if (actionBarItemsAmount)
    {
      let actionBarSize = to_pixels("1@hudActionBarItemSize")
      let actionBarOffset = to_pixels("1@hudActionBarItemOffset")
      let screenWidth = to_pixels("sw")
      let borderWidth = to_pixels("1@bwHud")
      let actionBarWidth = actionBarItemsAmount * actionBarSize + (actionBarItemsAmount + 1) * actionBarOffset

      this.sideBlockMaxWidth = (screenWidth - actionBarWidth) / 2 - borderWidth - to_pixels("1@blockInterval")
    }
    else
      this.sideBlockMaxWidth = null

    this.changeObjectsSize(::USEROPT_DAMAGE_INDICATOR_SIZE)
    this.changeObjectsSize(::USEROPT_TACTICAL_MAP_SIZE)
  }

  //get means determine in this case, but "determine" is too long for function name
  function getHudType()
  {
    if (::hud_is_in_cutscene())
      return HUD_TYPE.CUTSCENE
    if (this.spectatorMode)
      return HUD_TYPE.SPECTATOR
    if (::get_game_mode() == GM_BENCHMARK)
      return HUD_TYPE.BENCHMARK
    if (::is_freecam_enabled())
      return HUD_TYPE.FREECAM
    //!!!FIX ME Need remove this check, but client is crashed in hud for dummy plane in ship autotest
    if (getActionBarUnitName() == "dummy_plane")
      return HUD_TYPE.NONE
    return hudTypeByHudUnitType?[getHudUnitType()] ?? HUD_TYPE.NONE
  }

  function updateHudVisMode(forceUpdate = false)
  {
    let visMode = ::g_hud_vis_mode.getCurMode()
    if (!forceUpdate && visMode == this.curHudVisMode)
      return
    this.curHudVisMode = visMode

    let isDmgPanelVisible = visMode.isPartVisible(HUD_VIS_PART.DMG_PANEL) &&
      ::is_tank_damage_indicator_visible()

    let objsToShow = {
      xray_render_dmg_indicator = isDmgPanelVisible
      hud_tank_damage_indicator = isDmgPanelVisible
      tank_background = isDmgIndicatorVisible() && isDmgPanelVisible
      hud_tank_tactical_map     = visMode.isPartVisible(HUD_VIS_PART.MAP)
      hud_kill_log              = visMode.isPartVisible(HUD_VIS_PART.KILLLOG)
      chatPlace                 = visMode.isPartVisible(HUD_VIS_PART.CHAT)
      hud_enemy_damage_nest     = visMode.isPartVisible(HUD_VIS_PART.KILLCAMERA)
      order_status              = visMode.isPartVisible(HUD_VIS_PART.ORDERS)
    }

    send("updateExtWatched", {
      isChatPlaceVisible = objsToShow.chatPlace
      isOrderStatusVisible = objsToShow.order_status
    })

    this.guiScene.setUpdatesEnabled(false, false)
    ::showBtnTable(this.scene, objsToShow)
    this.guiScene.setUpdatesEnabled(true, true)
  }

  function onHudUpdate(_obj=null, dt=0.0)
  {
    ::g_streaks.onUpdate(dt)
    this.unmappedControlsUpdate(dt)
    this.updateAFKTimeKickText(dt)
  }

  function unmappedControlsCheck()
  {
    if (this.spectatorMode || !::is_hud_visible())
      return

    let unmapped = ::getUnmappedControlsForCurrentMission()

    if (!unmapped.len())
    {
      if (this.ucWarningActive)
      {
        this.ucPrevList = unmapped
        this.ucWarningTimeShow = 0.0
        this.unmappedControlsUpdate()
      }
      return
    }

    if (::u.isEqual(unmapped, this.ucPrevList))
      return

    let warningObj = this.scene.findObject("unmapped_shortcuts_warning")
    if (!checkObj(warningObj))
      return

    let unmappedLocalized = ::u.map(unmapped, loc)
    let text = loc("controls/warningUnmapped") + loc("ui/colon") + "\n" + ::g_string.implode(unmappedLocalized, loc("ui/comma"))
    warningObj.setValue(text)
    warningObj.show(true)
    warningObj.wink = "yes"

    this.ucWarningTimeShow = getUnmappedControlsWarningTime()
    this.ucNoWinkTime = this.ucWarningTimeShow - UNMAPPED_CONTROLS_WARNING_TIME_WINK
    this.ucPrevList = unmapped
    this.ucWarningActive = true
    this.unmappedControlsUpdate()
  }

  function unmappedControlsUpdate(dt=0.0)
  {
    if (!this.ucWarningActive)
      return

    let winkingOld = this.ucWarningTimeShow > this.ucNoWinkTime
    this.ucWarningTimeShow -= dt
    let winkingNew = this.ucWarningTimeShow > this.ucNoWinkTime

    if (this.ucWarningTimeShow <= 0 || winkingOld != winkingNew)
    {
      let warningObj = this.scene.findObject("unmapped_shortcuts_warning")
      if (!checkObj(warningObj))
        return

      warningObj.wink = "no"

      if (this.ucWarningTimeShow <= 0)
      {
        warningObj.show(false)
        this.ucWarningActive = false
      }
    }
  }

  function warnLowQualityModelCheck()
  {
    if (this.spectatorMode || !::is_hud_visible())
      return

    let isShow = !::is_hero_highquality() && !::g_hud_live_stats.isVisible()
    if (isShow == this.isLowQualityWarningVisible)
      return

    this.isLowQualityWarningVisible = isShow
    this.showSceneBtn("low-quality-model-warning", isShow)
  }

  function onEventHudIndicatorChangedSize(params)
  {
    let option = getTblValue("option", params, -1)
    if (option < 0)
      return

    this.changeObjectsSize(option)
  }

  function changeObjectsSize(optionNum)
  {
    let option = ::get_option(optionNum)
    let value = (option && option.value != null) ? option.value : 0
    let vMax   = (option?.max ?? 0) != 0 ? option.max : 2
    let size = 1.0 + 0.333 * value / vMax

    let table = getTblValue(optionNum, this.objectsTable, {})
    foreach (id, cssConst in getTblValue("objectsToScale", table, {}))
    {
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

      if (optionNum == ::USEROPT_TACTICAL_MAP_SIZE)
        this.curTacticalMapObj = obj

      let func = getTblValue("onChangedFunc", table)
      if (func)
        func.call(this, obj)
    }
  }

  function getTacticalMapObj()
  {
    return this.curTacticalMapObj
  }

  function getMultiplayerScoreObj()
  {
    return this.scene.findObject("hud_multiplayer_score_progress_bar")
  }

  function getDamagePannelObj()
  {
    return this.scene.findObject("xray_render_dmg_indicator")
  }

  function getTankDebufsObj()
  {
    return this.scene.findObject("tank_debuffs")
  }

  function updateAFKTimeKick()
  {
    this.afkTimeToKick = ::get_mp_kick_countdown()
  }

  function updateAFKTimeKickText(sec)
  {
    let timeToKickAlertObj = this.scene.findObject("time_to_kick_alert_text")
    if (!checkObj(timeToKickAlertObj) || timeToKickAlertObj.getModalCounter() != 0)
      return

    this.updateAFKTimeKick()
    let showAlertText = ::get_in_battle_time_to_kick_show_alert() >= this.afkTimeToKick
    let showTimerText = ::get_in_battle_time_to_kick_show_timer() >= this.afkTimeToKick
    let showMessage = this.afkTimeToKick >= 0 && (showTimerText || showAlertText)
    timeToKickAlertObj.show(showMessage)
    if (!showMessage)
      return

    if (showAlertText)
    {
      timeToKickAlertObj.setValue(this.afkTimeToKick > 0
        ? loc("inBattle/timeToKick", {timeToKick = time.secondsToString(this.afkTimeToKick, true, true)})
        : "")

      let curTime = get_time_msec()
      let prevSeconds = ((curTime - 1000 * sec) / 1000).tointeger()
      let currSeconds = (curTime / 1000).tointeger()

      if (currSeconds != prevSeconds)
      {
        timeToKickAlertObj["_blink"] = "yes"
        this.guiScene.playSound("kick_alert")
      }

    }
    else if (showTimerText)
      timeToKickAlertObj.setValue(loc("inBattle/timeToKickAlert"))
  }

  //
  // Server message
  //

  function onEventServerMessage(_params)
  {
    let serverMessageTimerObject = this.scene.findObject("server_message_timer")
    if (checkObj(serverMessageTimerObject))
    {
      SecondsUpdater(serverMessageTimerObject, (@(scene) function (_obj, _params) {
        return !::server_message_update_scene(scene)
      })(this.scene))
    }
  }

  function updateMissionProgressPlace()
  {
    if (this.getHudType() == HUD_TYPE.SHIP) {
      let missionProgressHeight = isProgressVisible() ? to_pixels("@missionProgressHeight") : 0;
      ::call_darg("hudDmgIndicatorStatesUpdate", {
        size = [0, 0], pos = [0, 0],
        padding = [0, 0, missionProgressHeight, 0]
      })
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
    this.currentHud?.updateChatOffset()

    obj = this.scene.findObject("hud_tank_damage_indicator")
    if (obj?.isValid())
      ::call_darg("hudDmgIndicatorStatesUpdate", {
        size = obj.getSize(), pos = obj.getPos(),
        padding = [0, 0, 0, 0]
      })
  }
}

::HudCutscene <- class extends ::gui_handlers.BaseUnitHud
{
  sceneBlkName = "%gui/hud/hudCutscene.blk"
}

::HudAir <- class extends ::gui_handlers.BaseUnitHud
{
  sceneBlkName = "%gui/hud/hudAir.blk"

  function initScreen()
  {
    base.initScreen()
    ::g_hud_display_timers.init(this.scene, ES_UNIT_TYPE_AIRCRAFT)
    this.actionBar = ::ActionBar(this.scene.findObject("hud_action_bar"))

    this.updateTacticalMapVisibility()
    this.updateDmgIndicatorVisibility()
    this.updateShowHintsNest()
    this.updatePosHudMultiplayerScore()

    ::g_hud_event_manager.subscribe("DamageIndicatorToggleVisbility",
      function(_ed) { this.updateDmgIndicatorVisibility() },
      this)
    ::g_hud_event_manager.subscribe("DamageIndicatorSizeChanged",
      function(_ed) { this.updateDmgIndicatorVisibility() },
      this)
  }

  function reinitScreen(_params = {})
  {
    ::g_hud_display_timers.reinit()
    this.updateTacticalMapVisibility()
    this.updateDmgIndicatorVisibility()
    this.updateShowHintsNest()
    this.actionBar.reinit()
  }

  function updateTacticalMapVisibility()
  {
    let shouldShowMapForAircraft = (::get_game_type() & GT_RACE) != 0 // Race mission
      || (getPlayerCurUnit()?.tags ?? []).contains("type_strike_ucav") // Strike UCAV in Tanks mission
      || (hasFeature("uavMiniMap") && (::getAircraftByName(getOwnerUnitName())?.isTank() ?? false)) // Scout UCAV in Tanks mission
    let isVisible = shouldShowMapForAircraft && !is_replay_playing()
      && ::g_hud_vis_mode.getCurMode().isPartVisible(HUD_VIS_PART.MAP)
    this.showSceneBtn("hud_air_tactical_map", isVisible)
  }

  function updateDmgIndicatorVisibility()
  {
    this.updateChatOffset()
  }

  function updateShowHintsNest()
  {
    this.showSceneBtn("actionbar_hints_nest", false)
  }

  function getChatOffset()
  {
    if (isDmgIndicatorVisible())
    {
      let dmgIndObj = this.scene.findObject("xray_render_dmg_indicator")
      if (checkObj(dmgIndObj))
        return this.guiScene.calcString("sh - 1@bhHud", null) - dmgIndObj.getPosRC()[1]
    }

    let obj = this.scene.findObject("mission_progress_place")
    if (obj?.isValid() && obj.isVisible())
      return this.guiScene.calcString("sh - 1@bhHud - @hudPadding", null) - obj.getPosRC()[1]

    return 0
  }

  _chatOffset = -1
  function updateChatOffset()
  {
    let chatObj = this.scene.findObject("chatPlace")
    if (!checkObj(chatObj))
      return

    let offset = this.getChatOffset()
    if (this._chatOffset == offset)
      return

    chatObj["margin-bottom"] = offset.tostring()
    this._chatOffset = offset
  }
}

::HudTank <- class extends ::gui_handlers.BaseUnitHud
{
  sceneBlkName = mpTankHudBlkPath.value

  widgetsList = [
    {
      widgetId = DargWidgets.DAMAGE_PANEL
    }
  ]

  function initScreen()
  {
    base.initScreen()
    ::g_hud_display_timers.init(this.scene, ES_UNIT_TYPE_TANK)
    initIconedHints(this.scene, ES_UNIT_TYPE_TANK)
    ::g_hud_tank_debuffs.init(this.scene)
    ::g_hud_crew_state.init(this.scene)
    showHudTankMovementStates(this.scene)
    ::hudEnemyDamage.init(this.scene)
    this.actionBar = ::ActionBar(this.scene.findObject("hud_action_bar"))
    this.updateShowHintsNest()
    this.updatePosHudMultiplayerScore()

    ::g_hud_event_manager.subscribe("DamageIndicatorToggleVisbility",
      @(_eventData) this.updateDamageIndicatorBackground(),
      this)
    ::g_hud_event_manager.subscribe("DamageIndicatorSizeChanged",
      function(_ed) { this.updateDmgIndicatorSize() },
      this)
  }

  function reinitScreen(_params = {})
  {
    this.actionBar.reinit()
    ::hudEnemyDamage.reinit()
    ::g_hud_display_timers.reinit()
    ::g_hud_tank_debuffs.reinit()
    ::g_hud_crew_state.reinit()
    this.updateShowHintsNest()
    maybeOfferControlsHelp()
  }

  function updateDamageIndicatorBackground()
  {
    let visMode = ::g_hud_vis_mode.getCurMode()
    let isDmgPanelVisible = isDmgIndicatorVisible() && visMode.isPartVisible(HUD_VIS_PART.DMG_PANEL)
    ::showBtn("tank_background", isDmgPanelVisible, this.scene)
  }

  function updateShowHintsNest()
  {
    this.showSceneBtn("actionbar_hints_nest", true)
  }

  function updateDmgIndicatorSize() {
    let obj = this.scene.findObject("hud_tank_damage_indicator")
    if (obj?.isValid())
      ::call_darg("hudDmgIndicatorStatesUpdate", {
        size = obj.getSize(), pos = obj.getPos(),
        padding = [0, 0, 0, 0]
      })
  }
}

::HudHelicopter <- class extends ::gui_handlers.BaseUnitHud
{
  sceneBlkName = "%gui/hud/hudHelicopter.blk"

  function initScreen()
  {
    base.initScreen()
    ::hudEnemyDamage.init(this.scene)
    this.actionBar = ::ActionBar(this.scene.findObject("hud_action_bar"))
    this.updatePosHudMultiplayerScore()
  }

  function reinitScreen(_params = {})
  {
    this.actionBar.reinit()
    ::hudEnemyDamage.reinit()
    maybeOfferControlsHelp()
  }
}

::HudShip <- class extends ::gui_handlers.BaseUnitHud
{
  sceneBlkName = "%gui/hud/hudShip.blk"
  widgetsList = [
    {
      widgetId = DargWidgets.SHIP_OBSTACLE_RF
      placeholderId = "ship_obstacle_rf"
    }
  ]

  function initScreen()
  {
    base.initScreen()
    ::hudEnemyDamage.init(this.scene)
    ::g_hud_display_timers.init(this.scene, ES_UNIT_TYPE_SHIP)
    ::hud_request_hud_ship_debuffs_state()
    this.actionBar = ::ActionBar(this.scene.findObject("hud_action_bar"))
    this.updatePosHudMultiplayerScore()
  }

  function reinitScreen(_params = {})
  {
    this.actionBar.reinit()
    ::hudEnemyDamage.reinit()
    ::g_hud_display_timers.reinit()
    ::hud_request_hud_ship_debuffs_state()
  }
}

::gui_start_hud <- function gui_start_hud()
{
  ::handlersManager.loadHandler(::gui_handlers.Hud)
}

::gui_start_hud_no_chat <- function gui_start_hud_no_chat()
{
  //HUD can determine is he need chat or not
  //this function is left just for back compotibility with cpp code
  ::gui_start_hud()
}

::gui_start_spectator <- function gui_start_spectator()
{
  ::handlersManager.loadHandler(::gui_handlers.Hud, { spectatorMode = true })
}
