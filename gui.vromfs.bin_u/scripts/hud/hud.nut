local SecondsUpdater = require("sqDagui/timer/secondsUpdater.nut")
local time = require("scripts/time.nut")
local { isProgressVisible } = require("hudState")
local safeAreaHud = require("scripts/options/safeAreaHud.nut")
local globalCallbacks = require("sqDagui/globalCallbacks/globalCallbacks.nut")
local { showHudTankMovementStates } = require("scripts/hud/hudTankStates.nut")
local { mpTankHudBlkPath } = require("scripts/hud/hudBlkPath.nut")
local { isDmgIndicatorVisible } = ::require_native("gameplayBinding")
local { getPlayerCurUnit } = require("scripts/slotbar/playerCurUnit.nut")
local { initIconedHints } = require("scripts/hud/iconedHints.nut")
local { useTouchscreen } = require("scripts/clientState/touchScreen.nut")
local { setShortcutOn, setShortcutOff } = require("globalScripts/controls/shortcutActions.nut")
local { getActionBarItems } = ::require_native("hudActionBar")

::dagui_propid.add_name_id("fontSize")

local UNMAPPED_CONTROLS_WARNING_TIME_WINK = 3.0
local getUnmappedControlsWarningTime = @() ::get_game_mode() == ::GM_TRAINING ? 180000.0 : 30.0
local defaultFontSize = "small"

::air_hud_actions <- {
  flaps = {
    id     = "flaps"
    image  = "#ui/gameuiskin#aerodinamic_wing"
    action = "ID_FLAPS"
  }

  gear = {
    id     = "gear"
    image  = "#ui/gameuiskin#hidraulic"
    action = "ID_GEAR"
  }

  rocket = {
    id     = "rocket"
    image  = "#ui/gameuiskin#rocket"
    action = "ID_ROCKETS"
  }

  bomb = {
    id     = "bomb"
    image  = "#ui/gameuiskin#torpedo_bomb"
    action = "ID_BOMBS"
  }
}

globalCallbacks.addTypes({
  onShortcutOn = {
    onCb = @(obj, params) setShortcutOn(obj.shortcut_id)
  }
  onShortcutOff = {
    onCb = @(obj, params) setShortcutOff(obj.shortcut_id)
  }
})

class ::gui_handlers.Hud extends ::gui_handlers.BaseGuiHandlerWT
{
  sceneBlkName         = "gui/hud/hud.blk"
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
      onChangedFunc = @(obj) ::g_hud_event_manager.onHudEvent("DamageIndicatorSizeChanged")
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
    spectatorMode = ::isPlayerDedicatedSpectator() || ::is_replay_playing()
    unmappedControlsCheck()
    warnLowQualityModelCheck()
    switchHud(getHudType())
    loadGameChat()

    scene.findObject("hud_update").setUserData(this)
    local gm = ::get_game_mode()
    showSceneBtn("stats", (gm == ::GM_DOMINATION || gm == ::GM_SKIRMISH))
    showSceneBtn("voice", (gm == ::GM_DOMINATION || gm == ::GM_SKIRMISH))

    ::HudBattleLog.init()
    ::g_hud_message_stack.init(scene)
    ::g_hud_message_stack.clearMessageStacks()
    ::g_hud_live_stats.init(scene, "hud_live_stats_nest", !spectatorMode && ::is_multiplayer())
    ::g_hud_hints_manager.init(scene)
    ::g_hud_tutorial_elements.init(scene)

    updateControlsAllowMask()
  }

  function initDargWidgetsList() {
    local hudWidgetId = useTouchscreen ? DargWidgets.HUD_TOUCH : DargWidgets.HUD
    widgetsList = [
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

    switchControlsAllowMask(mask)
  }

  /*override*/ function onSceneActivate(show)
  {
    ::g_orders.enableOrders(scene.findObject("order_status"))
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
      curChatData = ::loadGameChatToObj(scene.findObject("chatPlace"), "gui/chat/gameChat.blk", this,
                          { selfHideInput = true, selfHideLog = true })
  }

  function reinitScreen(params = {})
  {
    isReinitDelayed = !scene.isVisible() //hud not visible. we just wait for show_hud event
    if (isReinitDelayed)
      return

    setParams(params)
    if (switchHud(getHudType()))
      loadGameChat()
    else
    {
      if (currentHud && ("reinitScreen" in currentHud))
        currentHud.reinitScreen()
      ::g_hud_hitcamera.reinit()
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
    ::g_hud_event_manager.subscribe("ReinitHud", function(eventData)
      {
        reinitScreen()
      }, this)
    ::g_hud_event_manager.subscribe("Cutscene", function(eventData)
      {
        reinitScreen()
      }, this)
    ::g_hud_event_manager.subscribe("LiveStatsVisibilityToggled",
        @(ed) warnLowQualityModelCheck(),
        this)

    ::g_hud_event_manager.subscribe("hudProgress:visibilityChanged",
      @(eventData) updateMissionProgressPlace(), this)
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
    if (!::checkObj(scene))
      return false

    if (newHudType == hudType)
    {
      if (isXinput == ::is_xinput_device())
        return false

      isXinput = ::is_xinput_device()
    }

    local hudObj = scene.findObject("hud_obj")
    if (!::checkObj(hudObj))
      return false

    guiScene.replaceContentFromText(hudObj, "", 0, this)

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

    showSceneBtn("ship_obstacle_rf", newHudType == HUD_TYPE.SHIP)

    hudType = newHudType

    onHudSwitched()
    ::broadcastEvent("HudTypeSwitched")
    return true
  }

  function onHudSwitched()
  {
    updateHudVisMode(::FORCE_UPDATE)
    ::g_hud_hitcamera.init(scene.findObject("hud_hitcamera"))

    // All required checks are performed internally.
    ::g_orders.enableOrders(scene.findObject("order_status"))

    updateObjectsSize()
    updateMissionProgressPlace()
  }

  function onEventChangedCursorVisibility(params)
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
    local actionBarItemsAmount = params?.actionBarItemsAmount ?? getActionBarItems().len()
    if (actionBarItemsAmount)
    {
      local actionBarSize = ::to_pixels("1@hudActionBarItemSize")
      local actionBarOffset = ::to_pixels("1@hudActionBarItemOffset")
      local screenWidth = ::to_pixels("sw")
      local borderWidth = ::to_pixels("1@bwHud")
      local actionBarWidth = actionBarItemsAmount * actionBarSize + (actionBarItemsAmount + 1) * actionBarOffset

      sideBlockMaxWidth = (screenWidth - actionBarWidth) / 2 - borderWidth - ::to_pixels("1@blockInterval")
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
    else if (::get_game_mode() == ::GM_BENCHMARK)
      return HUD_TYPE.BENCHMARK
    else if (::is_freecam_enabled())
      return HUD_TYPE.FREECAM
    else
    {
      local unit = getPlayerCurUnit()
      if (unit?.isHelicopter?())
        return HUD_TYPE.HELICOPTER

      local unitType = ::get_es_unit_type(unit)
      if (unitType == ::ES_UNIT_TYPE_AIRCRAFT)
        return HUD_TYPE.AIR
      else if (unitType == ::ES_UNIT_TYPE_TANK)
        return HUD_TYPE.TANK
      else if (unitType == ::ES_UNIT_TYPE_SHIP || unitType == ::ES_UNIT_TYPE_BOAT)
        return HUD_TYPE.SHIP
    }
    return HUD_TYPE.NONE
  }

  function updateHudVisMode(forceUpdate = false)
  {
    local visMode = ::g_hud_vis_mode.getCurMode()
    if (!forceUpdate && visMode == curHudVisMode)
      return
    curHudVisMode = visMode

    local isDmgPanelVisible = visMode.isPartVisible(HUD_VIS_PART.DMG_PANEL) &&
      ::is_tank_damage_indicator_visible()

    local objsToShow = {
      xray_render_dmg_indicator = isDmgPanelVisible
      hud_tank_damage_indicator = isDmgPanelVisible
      tank_background = isDmgIndicatorVisible() && isDmgPanelVisible
      hud_tank_tactical_map     = visMode.isPartVisible(HUD_VIS_PART.MAP)
      hud_kill_log              = visMode.isPartVisible(HUD_VIS_PART.KILLLOG)
      chatPlace                 = visMode.isPartVisible(HUD_VIS_PART.CHAT)
      hud_enemy_damage_nest     = visMode.isPartVisible(HUD_VIS_PART.KILLCAMERA)
      order_status              = visMode.isPartVisible(HUD_VIS_PART.ORDERS)
    }

    ::call_darg("updateExtWatched", {
      isChatPlaceVisible = objsToShow.chatPlace
      isOrderStatusVisible = objsToShow.order_status
    })

    guiScene.setUpdatesEnabled(false, false)
    ::showBtnTable(scene, objsToShow)
    guiScene.setUpdatesEnabled(true, true)
  }

  function onHudUpdate(obj=null, dt=0.0)
  {
    ::g_streaks.onUpdate(dt)
    unmappedControlsUpdate(dt)
    updateAFKTimeKickText(dt)
  }

  function unmappedControlsCheck()
  {
    if (spectatorMode || !::is_hud_visible())
      return

    local unmapped = ::getUnmappedControlsForCurrentMission()

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

    local warningObj = scene.findObject("unmapped_shortcuts_warning")
    if (!::checkObj(warningObj))
      return

    local unmappedLocalized = ::u.map(unmapped, ::loc)
    local text = ::loc("controls/warningUnmapped") + ::loc("ui/colon") + "\n" + ::g_string.implode(unmappedLocalized, ::loc("ui/comma"))
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

    local winkingOld = ucWarningTimeShow > ucNoWinkTime
    ucWarningTimeShow -= dt
    local winkingNew = ucWarningTimeShow > ucNoWinkTime

    if (ucWarningTimeShow <= 0 || winkingOld != winkingNew)
    {
      local warningObj = scene.findObject("unmapped_shortcuts_warning")
      if (!::checkObj(warningObj))
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

    local isShow = !::is_hero_highquality() && !::g_hud_live_stats.isVisible()
    if (isShow == isLowQualityWarningVisible)
      return

    isLowQualityWarningVisible = isShow
    showSceneBtn("low-quality-model-warning", isShow)
  }

  function onEventHudIndicatorChangedSize(params)
  {
    local option = ::getTblValue("option", params, -1)
    if (option < 0)
      return

    changeObjectsSize(option)
  }

  function changeObjectsSize(optionNum)
  {
    local option = ::get_option(optionNum)
    local value = (option && option.value != null) ? option.value : 0
    local vMax   = (option?.max ?? 0) != 0 ? option.max : 2
    local size = 1.0 + 0.333 * value / vMax

    local table = ::getTblValue(optionNum, objectsTable, {})
    foreach (id, cssConst in ::getTblValue("objectsToScale", table, {}))
    {
      local obj = scene.findObject(id)
      if (!::checkObj(obj))
        continue

      local objWidth = ::format("%.3f*%s", size, cssConst)
      local objWidthValue = ::to_pixels(objWidth)
      local canApplyOptionValue = !table?.objectsToCheckOversize?[id] ||
                                  !sideBlockMaxWidth ||
                                  objWidthValue <= sideBlockMaxWidth
      local fontSize = table?.fontSizeByScale[id][value]
      if (fontSize != null)
        obj.fontSize = canApplyOptionValue ? fontSize : defaultFontSize
      obj.size = canApplyOptionValue
        ? ::format("%.3f*%s, %.3f*%s", size, cssConst, size, cssConst)
        : ::format("%d, %d", sideBlockMaxWidth, sideBlockMaxWidth)
      guiScene.applyPendingChanges(false)

      if (optionNum == ::USEROPT_TACTICAL_MAP_SIZE)
        curTacticalMapObj = obj

      local func = ::getTblValue("onChangedFunc", table)
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
    return scene.findObject("hud_multiplayer_score_progress_bar")
  }

  function getDamagePannelObj()
  {
    return scene.findObject("xray_render_dmg_indicator")
  }

  function getTankDebufsObj()
  {
    return scene.findObject("tank_debuffs")
  }

  function updateAFKTimeKick()
  {
    afkTimeToKick = ::get_mp_kick_countdown()
  }

  function updateAFKTimeKickText(sec)
  {
    local timeToKickAlertObj = scene.findObject("time_to_kick_alert_text")
    if (!::checkObj(timeToKickAlertObj) || timeToKickAlertObj.getModalCounter() != 0)
      return

    updateAFKTimeKick()
    local showAlertText = ::get_in_battle_time_to_kick_show_alert() >= afkTimeToKick
    local showTimerText = ::get_in_battle_time_to_kick_show_timer() >= afkTimeToKick
    local showMessage = afkTimeToKick >= 0 && (showTimerText || showAlertText)
    timeToKickAlertObj.show(showMessage)
    if (!showMessage)
      return

    if (showAlertText)
    {
      timeToKickAlertObj.setValue(afkTimeToKick > 0
        ? ::loc("inBattle/timeToKick", {timeToKick = time.secondsToString(afkTimeToKick, true, true)})
        : "")

      local curTime = ::dagor.getCurTime()
      local prevSeconds = ((curTime - 1000 * sec) / 1000).tointeger()
      local currSeconds = (curTime / 1000).tointeger()

      if (currSeconds != prevSeconds)
      {
        timeToKickAlertObj["_blink"] = "yes"
        guiScene.playSound("kick_alert")
      }

    }
    else if (showTimerText)
      timeToKickAlertObj.setValue(::loc("inBattle/timeToKickAlert"))
  }

  //
  // Server message
  //

  function onEventServerMessage(params)
  {
    local serverMessageTimerObject = scene.findObject("server_message_timer")
    if (::checkObj(serverMessageTimerObject))
    {
      SecondsUpdater(serverMessageTimerObject, (@(scene) function (obj, params) {
        return !::server_message_update_scene(scene)
      })(scene))
    }
  }

  function updateMissionProgressPlace()
  {
    if (getHudType() == HUD_TYPE.SHIP) {
      local missionProgressHeight = isProgressVisible() ? ::to_pixels("@missionProgressHeight") : 0;
      ::call_darg("hudDmgIndicatorStatesUpdate", {
        size = [0, 0], pos = [0, 0],
        padding = [0, 0, missionProgressHeight, 0]
      })
      return
    }

    local obj = scene.findObject("mission_progress_place")
    if (!obj?.isValid())
      return

    local isVisible = isProgressVisible()
    if (obj.isVisible() == isVisible)
      return

    obj.show(isVisible)
    guiScene.applyPendingChanges(false)
    currentHud?.updateChatOffset()

    obj = scene.findObject("xray_render_dmg_indicator")
    if (obj?.isValid())
      ::call_darg("hudDmgIndicatorStatesUpdate", {
        size = obj.getSize(), pos = obj.getPos(),
        padding = [0, 0, 0, 0]
      })
  }
}

::HudCutscene <- class extends ::gui_handlers.BaseUnitHud
{
  sceneBlkName = "gui/hud/hudCutscene.blk"

  function initScreen()
  {
    base.initScreen()
  }

  function reinitScreen(params = {})
  {
  }
}

::HudAir <- class extends ::gui_handlers.BaseUnitHud
{
  sceneBlkName = "gui/hud/hudAir.blk"

  function initScreen()
  {
    base.initScreen()
    ::g_hud_display_timers.init(scene, ::ES_UNIT_TYPE_AIRCRAFT)
    actionBar = ActionBar(scene.findObject("hud_action_bar"))

    updateTacticalMapVisibility()
    updateDmgIndicatorVisibility()
    updateShowHintsNest()
    updatePosHudMultiplayerScore()

    ::g_hud_event_manager.subscribe("DamageIndicatorToggleVisbility",
      function(ed) { updateDmgIndicatorVisibility() },
      this)
    ::g_hud_event_manager.subscribe("DamageIndicatorSizeChanged",
      function(ed) { updateDmgIndicatorVisibility() },
      this)
  }

  function reinitScreen(params = {})
  {
    ::g_hud_display_timers.reinit()
    updateTacticalMapVisibility()
    updateDmgIndicatorVisibility()
    updateShowHintsNest()
    actionBar.reinit()
  }

  function updateTacticalMapVisibility()
  {
    local isVisible = ::g_hud_vis_mode.getCurMode().isPartVisible(HUD_VIS_PART.MAP)
                         && !is_replay_playing() && (::get_game_type() & ::GT_RACE)
    showSceneBtn("hud_air_tactical_map", isVisible)
  }

  function updateDmgIndicatorVisibility()
  {
    updateChatOffset()
  }

  function updateShowHintsNest()
  {
    showSceneBtn("actionbar_hints_nest", false)
  }

  function getChatOffset()
  {
    if (isDmgIndicatorVisible())
    {
      local dmgIndObj = scene.findObject("xray_render_dmg_indicator")
      if (::check_obj(dmgIndObj))
        return guiScene.calcString("sh - 1@bhHud", null) - dmgIndObj.getPosRC()[1]
    }

    local obj = scene.findObject("mission_progress_place")
    if (obj?.isValid() && obj.isVisible())
      return guiScene.calcString("sh - 1@bhHud - @hudPadding", null) - obj.getPosRC()[1]

    return 0
  }

  _chatOffset = -1
  function updateChatOffset()
  {
    local chatObj = scene.findObject("chatPlace")
    if (!::check_obj(chatObj))
      return

    local offset = getChatOffset()
    if (_chatOffset == offset)
      return

    chatObj["margin-bottom"] = offset.tostring()
    _chatOffset = offset
  }
}

::HudTouchAir <- class extends ::HudAir
{
  scene        = null
  sceneBlkName = "gui/hud/hudTouchAir.blk"
  wndType      = handlerType.CUSTOM

  function initScreen()
  {
    base.initScreen()
    fillAirButtons()
  }

  function reinitScreen(params = {})
  {
    base.reinitScreen()
    fillAirButtons()
  }

  function fillAirButtons()
  {
    local actionsObj = scene.findObject("hud_air_actions")
    if (!::checkObj(actionsObj))
      return

    local view = {
      actionFunction = "onAirHudAction"
      items = function ()
      {
        local res = []
        local availActionsList = ::get_aircraft_available_actions()
        foreach (name,  action in ::air_hud_actions)
          if (::isInArray(name, availActionsList))
            res.append(action)
        return res
      }
    }

    local blk = ::handyman.renderCached(("gui/hud/hudAirActions"), view)
    guiScene.replaceContentFromText(actionsObj, blk, blk.len(), this)
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
    ::g_hud_display_timers.init(scene, ::ES_UNIT_TYPE_TANK)
    initIconedHints(scene, ::ES_UNIT_TYPE_TANK)
    ::g_hud_tank_debuffs.init(scene)
    ::g_hud_crew_state.init(scene)
    showHudTankMovementStates(scene)
    ::hudEnemyDamage.init(scene)
    actionBar = ActionBar(scene.findObject("hud_action_bar"))
    updateShowHintsNest()
    updatePosHudMultiplayerScore()

    ::g_hud_event_manager.subscribe("DamageIndicatorToggleVisbility",
      @(eventData) updateDamageIndicatorBackground(),
      this)
    ::g_hud_event_manager.subscribe("DamageIndicatorSizeChanged",
      function(ed) { updateDmgIndicatorSize() },
      this)
  }

  function reinitScreen(params = {})
  {
    actionBar.reinit()
    ::hudEnemyDamage.reinit()
    ::g_hud_display_timers.reinit()
    ::g_hud_tank_debuffs.reinit()
    ::g_hud_crew_state.reinit()
    updateShowHintsNest()
  }

  function updateDamageIndicatorBackground()
  {
    local visMode = ::g_hud_vis_mode.getCurMode()
    local isDmgPanelVisible = isDmgIndicatorVisible() && visMode.isPartVisible(HUD_VIS_PART.DMG_PANEL)
    ::showBtn("tank_background", isDmgPanelVisible, scene)
  }

  function updateShowHintsNest()
  {
    showSceneBtn("actionbar_hints_nest", true)
  }

  function updateDmgIndicatorSize() {
    local obj = scene.findObject("xray_render_dmg_indicator")
    if (obj?.isValid())
      ::call_darg("hudDmgIndicatorStatesUpdate", {
        size = obj.getSize(), pos = obj.getPos(),
        padding = [0, 0, 0, 0]
      })
  }
}


::HudHelicopter <- class extends ::gui_handlers.BaseUnitHud
{
  sceneBlkName = "gui/hud/hudHelicopter.blk"

  function initScreen()
  {
    base.initScreen()
    ::hudEnemyDamage.init(scene)
    actionBar = ActionBar(scene.findObject("hud_action_bar"))
    updatePosHudMultiplayerScore()
  }

  function reinitScreen(params = {})
  {
    actionBar.reinit()
    ::hudEnemyDamage.reinit()
  }
}

::HudTouchTank <- class extends ::HudTank
{
  scene        = null
  sceneBlkName = "gui/hud/hudTouchTank.blk"
  wndType      = handlerType.CUSTOM

  function initScreen()
  {
    base.initScreen()
    setupTankControlStick()
    ::g_hud_event_manager.subscribe(
      "tankRepair:offerRepair",
      function (eventData) {
        showTankRepairButton(true)
      },
      this
    )
    ::g_hud_event_manager.subscribe(
      "tankRepair:cantRepair",
      function (eventData) {
        showTankRepairButton(false)
      },
      this
    )
  }

  function reinitScreen(params = {})
  {
    base.reinitScreen()
    setupTankControlStick()
  }

  function setupTankControlStick()
  {
    local stickObj = scene.findObject("tank_stick")
    if (!::checkObj(stickObj))
      return

    register_tank_control_stick(stickObj)
  }

  function onEventArtilleryTarget(p)
  {
    local active = ::getTblValue("active", p, false)
    for(local i = 1; i <= 2; i++)
    {
      showSceneBtn("touch_fire_" + i, !active)
      showSceneBtn("touch_art_fire_" + i, active)
    }
  }

  function showTankRepairButton(show)
  {
    local repairButtonObj = scene.findObject("repair_tank")
    if (::checkObj(repairButtonObj))
    {
      repairButtonObj.show(show)
      repairButtonObj.enable(show)
    }
  }
}

::HudShip <- class extends ::gui_handlers.BaseUnitHud
{
  sceneBlkName = "gui/hud/hudShip.blk"
  widgetsList = [
    {
      widgetId = DargWidgets.SHIP_OBSTACLE_RF
      placeholderId = "ship_obstacle_rf"
    }
  ]

  function initScreen()
  {
    base.initScreen()
    ::hudEnemyDamage.init(scene)
    ::g_hud_display_timers.init(scene, ::ES_UNIT_TYPE_SHIP)
    ::hud_request_hud_ship_debuffs_state()
    actionBar = ActionBar(scene.findObject("hud_action_bar"))
    updatePosHudMultiplayerScore()
  }

  function reinitScreen(params = {})
  {
    actionBar.reinit()
    ::hudEnemyDamage.reinit()
    ::g_hud_display_timers.reinit()
    ::hud_request_hud_ship_debuffs_state()
  }
}

::HudTouchShip <- class extends ::HudShip
{
  scene        = null
  sceneBlkName = "gui/hud/hudTouchShip.blk"
  wndType      = handlerType.CUSTOM

  function initScreen()
  {
    base.initScreen()
    ::g_hud_event_manager.subscribe("hudProgress:visibilityChanged",
      @(eventData) updateMissionProgressPlace(), this)
    updateMissionProgressPlace()
  }

  function reinitScreen(params = {})
  {
    base.reinitScreen()
  }

  function updateMissionProgressPlace() {
    local obj = scene.findObject("movement_controls")
    if (!obj?.isValid())
      return

    obj.top = $"ph - h{isProgressVisible() ? " - @missionProgressHeight" : ""}"
  }
}

::HudTouchFreecam <- class extends ::gui_handlers.BaseUnitHud
{
  scene        = null
  sceneBlkName = "gui/hud/hudTouchFreecam.blk"
  wndType      = handlerType.CUSTOM

  function initScreen()
  {
    base.initScreen()
  }

  function reinitScreen(params = {})
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
