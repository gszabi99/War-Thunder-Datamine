from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let { get_time_msec } = require("dagor.time")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { format } = require("string")
let { send } = require("eventbus")
let SecondsUpdater = require("%sqDagui/timer/secondsUpdater.nut")
let time = require("%scripts/time.nut")
let { isProgressVisible } = require("hudState")
let safeAreaHud = require("%scripts/options/safeAreaHud.nut")
let globalCallbacks = require("%sqDagui/globalCallbacks/globalCallbacks.nut")
let { showHudTankMovementStates } = require("%scripts/hud/hudTankStates.nut")
let { mpTankHudBlkPath } = require("%scripts/hud/hudBlkPath.nut")
let { isDmgIndicatorVisible } = require_native("gameplayBinding")
let { getPlayerCurUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { initIconedHints } = require("%scripts/hud/iconedHints.nut")
let { useTouchscreen } = require("%scripts/clientState/touchScreen.nut")
let { setShortcutOn, setShortcutOff } = require("%globalScripts/controls/shortcutActions.nut")
let { getActionBarItems } = require_native("hudActionBar")
let { is_replay_playing } = require("replays")
let { hitCameraInit, hitCameraReinit } = require("%scripts/hud/hudHitCamera.nut")

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

::air_hud_actions <- {
  flaps = {
    id     = "flaps"
    image  = "#ui/gameuiskin#aerodinamic_wing.png"
    action = "ID_FLAPS"
  }

  gear = {
    id     = "gear"
    image  = "#ui/gameuiskin#hidraulic.png"
    action = "ID_GEAR"
  }

  rocket = {
    id     = "rocket"
    image  = "#ui/gameuiskin#rocket.png"
    action = "ID_ROCKETS"
  }

  bomb = {
    id     = "bomb"
    image  = "#ui/gameuiskin#torpedo_bomb.png"
    action = "ID_BOMBS"
  }
}

globalCallbacks.addTypes({
  onShortcutOn = {
    onCb = @(obj, _params) setShortcutOn(obj.shortcut_id)
  }
  onShortcutOff = {
    onCb = @(obj, _params) setShortcutOff(obj.shortcut_id)
  }
})

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
    initDargWidgetsList()
    ::init_options()
    ::g_hud_event_manager.init()
    ::g_streaks.clear()
    initSubscribes()

    ::set_hud_width_limit(safeAreaHud.getSafearea()[0])
    ::set_option_hud_screen_safe_area(safeAreaHud.getValue())

    isXinput = ::is_xinput_device()
    spectatorMode = ::isPlayerDedicatedSpectator() || is_replay_playing()
    unmappedControlsCheck()
    warnLowQualityModelCheck()
    switchHud(getHudType())
    loadGameChat()

    this.scene.findObject("hud_update").setUserData(this)
    let gm = ::get_game_mode()
    this.showSceneBtn("stats", (gm == GM_DOMINATION || gm == GM_SKIRMISH))
    this.showSceneBtn("voice", (gm == GM_DOMINATION || gm == GM_SKIRMISH))

    ::HudBattleLog.init()
    ::g_hud_message_stack.init(this.scene)
    ::g_hud_message_stack.clearMessageStacks()
    ::g_hud_live_stats.init(this.scene, "hud_live_stats_nest", !spectatorMode && ::is_multiplayer())
    ::g_hud_hints_manager.init(this.scene)
    ::g_hud_tutorial_elements.init(this.scene)

    updateControlsAllowMask()
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
    local mask = spectatorMode
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
    if (curChatData)
    {
      ::detachGameChatSceneData(curChatData)
      curChatData = null
    }
    if (::is_multiplayer())
      curChatData = ::loadGameChatToObj(this.scene.findObject("chatPlace"), "%gui/chat/gameChat.blk", this,
        { selfHideInput = true, selfHideLog = true, selectInputIfFocusLost = true })
  }

  function reinitScreen(params = {})
  {
    isReinitDelayed = !this.scene.isVisible() //hud not visible. we just wait for show_hud event
    if (isReinitDelayed)
      return

    this.setParams(params)
    if (switchHud(getHudType()))
      loadGameChat()
    else
    {
      if (currentHud && ("reinitScreen" in currentHud))
        currentHud.reinitScreen()
      hitCameraReinit()
    }
    ::g_hud_message_stack.reinit()
    ::g_hud_live_stats.reinit()
    ::g_hud_hints_manager.reinit()
    ::g_hud_tutorial_elements.reinit()

    unmappedControlsCheck()
    warnLowQualityModelCheck()
    updateHudVisMode()
    onHudUpdate(null, 0.0)
  }

  function initSubscribes()
  {
    ::g_hud_event_manager.subscribe("ReinitHud", function(_eventData)
      {
        reinitScreen()
      }, this)
    ::g_hud_event_manager.subscribe("Cutscene", function(_eventData)
      {
        reinitScreen()
      }, this)
    ::g_hud_event_manager.subscribe("LiveStatsVisibilityToggled",
        @(_ed) warnLowQualityModelCheck(),
        this)

    ::g_hud_event_manager.subscribe("hudProgress:visibilityChanged",
      @(_eventData) updateMissionProgressPlace(), this)
  }

  function onShowHud(show = true, needApplyPending = true)
  {
    if (currentHud && ("onShowHud" in currentHud))
      currentHud.onShowHud(show, needApplyPending)
    base.onShowHud(show, needApplyPending)
    if (show && isReinitDelayed)
      reinitScreen()
  }

  function switchHud(newHudType)
  {
    if (!checkObj(this.scene))
      return false

    if (newHudType == hudType)
    {
      if (isXinput == ::is_xinput_device())
        return false

      isXinput = ::is_xinput_device()
    }

    let hudObj = this.scene.findObject("hud_obj")
    if (!checkObj(hudObj))
      return false

    this.guiScene.replaceContentFromText(hudObj, "", 0, this)

    if (newHudType == HUD_TYPE.CUTSCENE)
      currentHud = ::handlersManager.loadHandler(::HudCutscene, { scene = hudObj })
    else if (newHudType == HUD_TYPE.SPECTATOR)
      currentHud = ::handlersManager.loadHandler(::Spectator, { scene = hudObj })
    else if (newHudType == HUD_TYPE.AIR)
      currentHud = ::handlersManager.loadHandler(useTouchscreen && !isXinput ? ::HudTouchAir : ::HudAir, { scene = hudObj })
    else if (newHudType == HUD_TYPE.TANK)
      currentHud = ::handlersManager.loadHandler(useTouchscreen && !isXinput ? ::HudTouchTank : ::HudTank, { scene = hudObj })
    else if (newHudType == HUD_TYPE.SHIP)
      currentHud = ::handlersManager.loadHandler(useTouchscreen && !isXinput ? ::HudTouchShip : ::HudShip, { scene = hudObj })
    else if (newHudType == HUD_TYPE.HELICOPTER)
      currentHud = ::handlersManager.loadHandler(::HudHelicopter, { scene = hudObj })
    else if (newHudType == HUD_TYPE.FREECAM && useTouchscreen && !isXinput)
      currentHud = ::handlersManager.loadHandler(::HudTouchFreecam, { scene = hudObj })
    else //newHudType == HUD_TYPE.NONE
      currentHud = null

    this.showSceneBtn("ship_obstacle_rf", newHudType == HUD_TYPE.SHIP)

    hudType = newHudType

    onHudSwitched()
    ::broadcastEvent("HudTypeSwitched")
    return true
  }

  function onHudSwitched()
  {
    ::handlersManager.updateWidgets()
    updateHudVisMode(::FORCE_UPDATE)
    hitCameraInit(this.scene.findObject("hud_hitcamera"))

    // All required checks are performed internally.
    ::g_orders.enableOrders(this.scene.findObject("order_status"))

    updateObjectsSize()
    updateMissionProgressPlace()
  }

  function onEventChangedCursorVisibility(_params)
  {
    if (::show_console_buttons)
      updateControlsAllowMask()
  }

  function onEventHudActionbarInited(params)
  {
    updateObjectsSize(params)
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

      sideBlockMaxWidth = (screenWidth - actionBarWidth) / 2 - borderWidth - to_pixels("1@blockInterval")
    }
    else
      sideBlockMaxWidth = null

    changeObjectsSize(::USEROPT_DAMAGE_INDICATOR_SIZE)
    changeObjectsSize(::USEROPT_TACTICAL_MAP_SIZE)
  }

  //get means determine in this case, but "determine" is too long for function name
  function getHudType()
  {
    if (::hud_is_in_cutscene())
      return HUD_TYPE.CUTSCENE
    else if (spectatorMode)
      return HUD_TYPE.SPECTATOR
    else if (::get_game_mode() == GM_BENCHMARK)
      return HUD_TYPE.BENCHMARK
    else if (::is_freecam_enabled())
      return HUD_TYPE.FREECAM
    else
    {
      let unit = getPlayerCurUnit()
      if (unit?.isHelicopter?())
        return HUD_TYPE.HELICOPTER

      let unitType = ::get_es_unit_type(unit)
      if (unitType == ES_UNIT_TYPE_AIRCRAFT)
        return HUD_TYPE.AIR
      else if (unitType == ES_UNIT_TYPE_TANK)
        return HUD_TYPE.TANK
      else if (unitType == ES_UNIT_TYPE_SHIP || unitType == ES_UNIT_TYPE_BOAT)
        return HUD_TYPE.SHIP
    }
    return HUD_TYPE.NONE
  }

  function updateHudVisMode(forceUpdate = false)
  {
    let visMode = ::g_hud_vis_mode.getCurMode()
    if (!forceUpdate && visMode == curHudVisMode)
      return
    curHudVisMode = visMode

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
    unmappedControlsUpdate(dt)
    updateAFKTimeKickText(dt)
  }

  function unmappedControlsCheck()
  {
    if (spectatorMode || !::is_hud_visible())
      return

    let unmapped = ::getUnmappedControlsForCurrentMission()

    if (!unmapped.len())
    {
      if (ucWarningActive)
      {
        ucPrevList = unmapped
        ucWarningTimeShow = 0.0
        unmappedControlsUpdate()
      }
      return
    }

    if (::u.isEqual(unmapped, ucPrevList))
      return

    let warningObj = this.scene.findObject("unmapped_shortcuts_warning")
    if (!checkObj(warningObj))
      return

    let unmappedLocalized = ::u.map(unmapped, loc)
    let text = loc("controls/warningUnmapped") + loc("ui/colon") + "\n" + ::g_string.implode(unmappedLocalized, loc("ui/comma"))
    warningObj.setValue(text)
    warningObj.show(true)
    warningObj.wink = "yes"

    ucWarningTimeShow = getUnmappedControlsWarningTime()
    ucNoWinkTime = ucWarningTimeShow - UNMAPPED_CONTROLS_WARNING_TIME_WINK
    ucPrevList = unmapped
    ucWarningActive = true
    unmappedControlsUpdate()
  }

  function unmappedControlsUpdate(dt=0.0)
  {
    if (!ucWarningActive)
      return

    let winkingOld = ucWarningTimeShow > ucNoWinkTime
    ucWarningTimeShow -= dt
    let winkingNew = ucWarningTimeShow > ucNoWinkTime

    if (ucWarningTimeShow <= 0 || winkingOld != winkingNew)
    {
      let warningObj = this.scene.findObject("unmapped_shortcuts_warning")
      if (!checkObj(warningObj))
        return

      warningObj.wink = "no"

      if (ucWarningTimeShow <= 0)
      {
        warningObj.show(false)
        ucWarningActive = false
      }
    }
  }

  function warnLowQualityModelCheck()
  {
    if (spectatorMode || !::is_hud_visible())
      return

    let isShow = !::is_hero_highquality() && !::g_hud_live_stats.isVisible()
    if (isShow == isLowQualityWarningVisible)
      return

    isLowQualityWarningVisible = isShow
    this.showSceneBtn("low-quality-model-warning", isShow)
  }

  function onEventHudIndicatorChangedSize(params)
  {
    let option = getTblValue("option", params, -1)
    if (option < 0)
      return

    changeObjectsSize(option)
  }

  function changeObjectsSize(optionNum)
  {
    let option = ::get_option(optionNum)
    let value = (option && option.value != null) ? option.value : 0
    let vMax   = (option?.max ?? 0) != 0 ? option.max : 2
    let size = 1.0 + 0.333 * value / vMax

    let table = getTblValue(optionNum, objectsTable, {})
    foreach (id, cssConst in getTblValue("objectsToScale", table, {}))
    {
      let obj = this.scene.findObject(id)
      if (!checkObj(obj))
        continue

      let objWidth = format("%.3f*%s", size, cssConst)
      let objWidthValue = to_pixels(objWidth)
      let canApplyOptionValue = !table?.objectsToCheckOversize?[id] ||
                                  !sideBlockMaxWidth ||
                                  objWidthValue <= sideBlockMaxWidth
      let fontSize = table?.fontSizeByScale[id][value]
      if (fontSize != null)
        obj.fontSize = canApplyOptionValue ? fontSize : defaultFontSize
      obj.size = canApplyOptionValue
        ? format("%.3f*%s, %.3f*%s", size, cssConst, size, cssConst)
        : format("%d, %d", sideBlockMaxWidth, sideBlockMaxWidth)
      this.guiScene.applyPendingChanges(false)

      if (optionNum == ::USEROPT_TACTICAL_MAP_SIZE)
        curTacticalMapObj = obj

      let func = getTblValue("onChangedFunc", table)
      if (func)
        func.call(this, obj)
    }
  }

  function getTacticalMapObj()
  {
    return curTacticalMapObj
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
    afkTimeToKick = ::get_mp_kick_countdown()
  }

  function updateAFKTimeKickText(sec)
  {
    let timeToKickAlertObj = this.scene.findObject("time_to_kick_alert_text")
    if (!checkObj(timeToKickAlertObj) || timeToKickAlertObj.getModalCounter() != 0)
      return

    updateAFKTimeKick()
    let showAlertText = ::get_in_battle_time_to_kick_show_alert() >= afkTimeToKick
    let showTimerText = ::get_in_battle_time_to_kick_show_timer() >= afkTimeToKick
    let showMessage = afkTimeToKick >= 0 && (showTimerText || showAlertText)
    timeToKickAlertObj.show(showMessage)
    if (!showMessage)
      return

    if (showAlertText)
    {
      timeToKickAlertObj.setValue(afkTimeToKick > 0
        ? loc("inBattle/timeToKick", {timeToKick = time.secondsToString(afkTimeToKick, true, true)})
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
    if (getHudType() == HUD_TYPE.SHIP) {
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
    currentHud?.updateChatOffset()

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

  function initScreen()
  {
    base.initScreen()
  }

  function reinitScreen(_params = {})
  {
  }
}

::HudAir <- class extends ::gui_handlers.BaseUnitHud
{
  sceneBlkName = "%gui/hud/hudAir.blk"

  function initScreen()
  {
    base.initScreen()
    ::g_hud_display_timers.init(this.scene, ES_UNIT_TYPE_AIRCRAFT)
    this.actionBar = ::ActionBar(this.scene.findObject("hud_action_bar"))

    updateTacticalMapVisibility()
    updateDmgIndicatorVisibility()
    updateShowHintsNest()
    this.updatePosHudMultiplayerScore()

    ::g_hud_event_manager.subscribe("DamageIndicatorToggleVisbility",
      function(_ed) { updateDmgIndicatorVisibility() },
      this)
    ::g_hud_event_manager.subscribe("DamageIndicatorSizeChanged",
      function(_ed) { updateDmgIndicatorVisibility() },
      this)
  }

  function reinitScreen(_params = {})
  {
    ::g_hud_display_timers.reinit()
    updateTacticalMapVisibility()
    updateDmgIndicatorVisibility()
    updateShowHintsNest()
    this.actionBar.reinit()
  }

  function updateTacticalMapVisibility()
  {
    let isVisible = ::g_hud_vis_mode.getCurMode().isPartVisible(HUD_VIS_PART.MAP)
                         && !is_replay_playing() && (::get_game_type() & GT_RACE)
    this.showSceneBtn("hud_air_tactical_map", isVisible)
  }

  function updateDmgIndicatorVisibility()
  {
    updateChatOffset()
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

    let offset = getChatOffset()
    if (_chatOffset == offset)
      return

    chatObj["margin-bottom"] = offset.tostring()
    _chatOffset = offset
  }
}

::HudTouchAir <- class extends ::HudAir
{
  scene        = null
  sceneBlkName = "%gui/hud/hudTouchAir.blk"
  wndType      = handlerType.CUSTOM

  function initScreen()
  {
    base.initScreen()
    fillAirButtons()
  }

  function reinitScreen(_params = {})
  {
    base.reinitScreen()
    fillAirButtons()
  }

  function fillAirButtons()
  {
    let actionsObj = scene.findObject("hud_air_actions")
    if (!checkObj(actionsObj))
      return

    let view = {
      actionFunction = "onAirHudAction"
      items = function ()
      {
        let res = []
        let availActionsList = ::get_aircraft_available_actions()
        foreach (name,  action in ::air_hud_actions)
          if (isInArray(name, availActionsList))
            res.append(action)
        return res
      }
    }

    let blk = ::handyman.renderCached(("%gui/hud/hudAirActions"), view)
    this.guiScene.replaceContentFromText(actionsObj, blk, blk.len(), this)
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
    updateShowHintsNest()
    this.updatePosHudMultiplayerScore()

    ::g_hud_event_manager.subscribe("DamageIndicatorToggleVisbility",
      @(_eventData) updateDamageIndicatorBackground(),
      this)
    ::g_hud_event_manager.subscribe("DamageIndicatorSizeChanged",
      function(_ed) { updateDmgIndicatorSize() },
      this)
  }

  function reinitScreen(_params = {})
  {
    this.actionBar.reinit()
    ::hudEnemyDamage.reinit()
    ::g_hud_display_timers.reinit()
    ::g_hud_tank_debuffs.reinit()
    ::g_hud_crew_state.reinit()
    updateShowHintsNest()
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

::HudTouchTank <- class extends ::HudTank
{
  scene        = null
  sceneBlkName = "%gui/hud/hudTouchTank.blk"
  wndType      = handlerType.CUSTOM

  function initScreen()
  {
    base.initScreen()
    ::g_hud_event_manager.subscribe(
      "tankRepair:offerRepair",
      function (_eventData) {
        showTankRepairButton(true)
      },
      this
    )
    ::g_hud_event_manager.subscribe(
      "tankRepair:cantRepair",
      function (_eventData) {
        showTankRepairButton(false)
      },
      this
    )
  }

  function reinitScreen(_params = {})
  {
    base.reinitScreen()
  }

  function onEventArtilleryTarget(p)
  {
    let active = getTblValue("active", p, false)
    for(local i = 1; i <= 2; i++)
    {
      this.showSceneBtn("touch_fire_" + i, !active)
      this.showSceneBtn("touch_art_fire_" + i, active)
    }
  }

  function showTankRepairButton(show)
  {
    let repairButtonObj = scene.findObject("repair_tank")
    if (checkObj(repairButtonObj))
    {
      repairButtonObj.show(show)
      repairButtonObj.enable(show)
    }
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

::HudTouchShip <- class extends ::HudShip
{
  scene        = null
  sceneBlkName = "%gui/hud/hudTouchShip.blk"
  wndType      = handlerType.CUSTOM

  function initScreen()
  {
    base.initScreen()
    ::g_hud_event_manager.subscribe("hudProgress:visibilityChanged",
      @(_eventData) updateMissionProgressPlace(), this)
    updateMissionProgressPlace()
  }

  function reinitScreen(_params = {})
  {
    base.reinitScreen()
  }

  function updateMissionProgressPlace() {
    let obj = scene.findObject("movement_controls")
    if (!obj?.isValid())
      return

    obj.top = $"ph - h{isProgressVisible() ? " - @missionProgressHeight" : ""}"
  }
}

::HudTouchFreecam <- class extends ::gui_handlers.BaseUnitHud
{
  scene        = null
  sceneBlkName = "%gui/hud/hudTouchFreecam.blk"
  wndType      = handlerType.CUSTOM

  function initScreen()
  {
    base.initScreen()
  }

  function reinitScreen(_params = {})
  {
    base.reinitScreen()
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
