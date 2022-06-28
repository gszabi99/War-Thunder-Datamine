let { format, split_by_chars } = require("string")
let u = require("%sqStdLibs/helpers/u.nut")
let time = require("%scripts/time.nut")
let spectatorWatchedHero = require("%scripts/replays/spectatorWatchedHero.nut")
let replayMetadata = require("%scripts/replays/replayMetadata.nut")
let { getUnitRole } = require("%scripts/unit/unitInfoTexts.nut")
let { getPlayerName } = require("%scripts/clientState/platform.nut")
let { useTouchscreen } = require("%scripts/clientState/touchScreen.nut")
let { toggleShortcut } = require("%globalScripts/controls/shortcutActions.nut")
let { getActionBarUnitName } = ::require_native("hudActionBar")
let { guiStartMPStatScreen, getWeaponTypeIcoByWeapon
} = require("%scripts/statistics/mpStatisticsUtil.nut")
let { onSpectatorMode, switchSpectatorTargetById,
  getSpectatorTargetId = @() ::get_spectator_target_id(), // compatibility with 2.15.1.X
  getSpectatorTargetName = @() ::get_spectator_target_name() // compatibility with 2.15.1.X
} = require("guiSpectator")
let { get_time_speeds_list, get_time_speed, is_replay_playing, get_replay_anchors,
  get_replay_info, get_replay_props, move_to_anchor } = require("replays")

enum SPECTATOR_MODE {
  RESPAWN     // Common multiplayer battle participant between respawns or after death.
  SKIRMISH    // Anyone entered as a Referee into any Skirmish session.
  SUPERVISOR  // Special online tournament master or observer, assigned by Operator.
  REPLAY      // Player viewing any locally saved local-replay or server-replay file.
}

enum SPECTATOR_CHAT_TAB {
  HISTORY  = "btn_tab_history"
  CHAT     = "btn_tab_chat"
  ORDERS   = "btn_tab_orders"
}

let weaponIconsReloadBits = {
  bomb = ::BMS_OUT_OF_BOMBS
  rocket = ::BMS_OUT_OF_ROCKETS
  torpedo = ::BMS_OUT_OF_TORPEDOES
}

::Spectator <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  scene  = null
  sceneBlkName = "%gui/spectator.blk"
  wndType      = handlerType.CUSTOM

  debugMode = false
  spectatorModeInited = false
  catchingFirstTarget = false
  ignoreUiInput = false

  mode = SPECTATOR_MODE.SKIRMISH
  gameType            = 0
  gotRefereeRights    = false
  isMultiplayer       = false
  canControlTimeline  = false
  canControlCameras   = false
  canSeeMissionTimer  = false
  canSeeOppositeTeam  = false
  canSendChatMessages = false

  cameraRotationByMouse = null

  replayAuthorUserId = -1
  replayTimeSpeedMin = 1.0
  replayTimeSpeedMax = 1.0
  replayPaused = null
  replayTimeSpeed = 0.0
  replayTimeTotal = 0.0
  replayTimeProgress = 0
  replayMarkersEnabled = null

  updateCooldown = 0.0
  statNumRows = 0
  teams = [ { players = [] }, { players = [] } ]
  lastTargetNick = ""
  lastTargetData = {
    id   = -1
    team = -1
  }
  lastSelectedTableId = ""
  lastHudUnitType = ::ES_UNIT_TYPE_INVALID
  lastFriendlyTeam = 0
  statSelPlayerId = [ null, null ]

  funcSortPlayersSpectator = null
  funcSortPlayersDefault   = null

  scanPlayerParams = [
    "canBeSwitchedTo",
    "id",
    "state",
    "isDead",
    "aircraftName",
    "weapon",
    "isBot",
    "deaths",
    "briefMalfunctionState",
    "isBurning",
    "isExtinguisherActive",
    "isLocal",
    "isInHeroSquad",
  ]

  historyMaxLen = ::g_chat.MAX_ROOM_MSGS_FOR_MODERATOR
  historySkipDuplicatesSec = 10
  historyLogCustomMsgType = -200
  historyLog = null
  chatData = null
  actionBar = null

  staticWidgets = [ "log_div", "map_div", "controls_div" ]
  movingWidgets = { ["spectator_hud_damage"] = [] }

  supportedMsgTypes = [
    ::HUD_MSG_MULTIPLAYER_DMG,
    ::HUD_MSG_STREAK_EX,
    ::HUD_MSG_STREAK,
    ::HUD_MSG_OBJECTIVE,
    ::HUD_MSG_DIALOG,
    ::HUD_MSG_DAMAGE,
    ::HUD_MSG_ENEMY_DAMAGE,
    ::HUD_MSG_ENEMY_CRITICAL_DAMAGE,
    ::HUD_MSG_ENEMY_FATAL_DAMAGE,
    ::HUD_MSG_DEATH_REASON,
    ::HUD_MSG_EVENT,
    -200 // historyLogCustomMsgType
  ]

  curTabId = ""
  tabsList = [
    {
      id = SPECTATOR_CHAT_TAB.HISTORY
      locId = "options/_Bttl"
      containerId = "history_container"
    }
    {
      id = SPECTATOR_CHAT_TAB.CHAT
      locId = "mainmenu/chat"
      containerId = "chat_container"
    }
    {
      id = SPECTATOR_CHAT_TAB.ORDERS
      locId = "itemTypes/orders"
      containerId = "orders_container"
    }
  ]

  function initScreen()
  {
    ::g_script_reloader.registerPersistentData("Spectator", this, [ "debugMode" ])

    gameType = ::get_game_type()
    let mplayerTable = ::get_local_mplayer() || {}
    let isReplay = is_replay_playing()
    let replayProps = get_replay_props()

    if (isReplay)
    {
      // Trying to restore some missing data when replay is started via command-line or browser link
      ::back_from_replays = ::back_from_replays || ::gui_start_mainmenu
      ::current_replay = ::current_replay.len() ? ::current_replay : ::getFromSettingsBlk("viewReplay", "")

      // Trying to restore some SessionLobby data
      replayMetadata.restoreReplayScriptCommentsBlk(::current_replay)
    }

    gotRefereeRights = ::getTblValue("spectator", mplayerTable, 0) == 1
    mode = isReplay ? SPECTATOR_MODE.REPLAY : SPECTATOR_MODE.SKIRMISH
    isMultiplayer = !!(gameType & ::GT_VERSUS) || !!(gameType & ::GT_COOPERATIVE)
    canControlTimeline  = mode == SPECTATOR_MODE.REPLAY && ::getTblValue("timeSpeedAllowed", replayProps, false)
    canControlCameras   = mode == SPECTATOR_MODE.REPLAY || gotRefereeRights
    canSeeMissionTimer  = !canControlTimeline && mode == SPECTATOR_MODE.SKIRMISH
    canSeeOppositeTeam  = mode != SPECTATOR_MODE.RESPAWN
    canSendChatMessages = mode != SPECTATOR_MODE.REPLAY
    let canRewind = canControlTimeline && ::has_feature("replayRewind")
    let anchors = get_replay_anchors()
    let curAnchorIdx = getCurAnchorIdx(anchors)

    fillTabs()
    historyLog = []

    loadGameChat()
    if (!isMultiplayer)
      ::showBtnTable(scene, {
          btn_tab_chat  = false
          target_stats  = false
      })

    let objReplayControls = scene.findObject("controls_div")
    ::showBtnTable(objReplayControls, {
        ID_FLIGHTMENU               = useTouchscreen
        ID_MPSTATSCREEN             = mode != SPECTATOR_MODE.REPLAY
        controls_mpstats_replays    = mode == SPECTATOR_MODE.REPLAY
        ID_PREV_PLANE               = true
        ID_NEXT_PLANE               = true
        controls_cameras_icon       = canControlCameras
        ID_CAMERA_DEFAULT           = canControlCameras
        ID_TOGGLE_FOLLOWING_CAMERA  = canControlCameras
        ID_REPLAY_CAMERA_OPERATOR   = canControlCameras
        ID_REPLAY_CAMERA_FLYBY      = canControlCameras
        ID_REPLAY_CAMERA_WING       = canControlCameras
        ID_REPLAY_CAMERA_GUN        = canControlCameras
        ID_REPLAY_CAMERA_RANDOMIZE  = canControlCameras
        ID_REPLAY_CAMERA_FREE       = canControlCameras
        ID_REPLAY_CAMERA_FREE_PARENTED = canControlCameras
        ID_REPLAY_CAMERA_FREE_ATTACHED = canControlCameras
        ID_REPLAY_CAMERA_HOVER      = canControlCameras
        ID_TOGGLE_FORCE_SPECTATOR_CAM_ROT = true
        ID_REPLAY_SHOW_MARKERS      = mode == SPECTATOR_MODE.REPLAY
        ID_REPLAY_SLOWER            = canControlTimeline
        ID_REPLAY_FASTER            = canControlTimeline
        ID_REPLAY_PAUSE             = canControlTimeline
        ID_REPLAY_BACKWARD          = canRewind
        ID_REPLAY_FORWARD           = canRewind
    })
    ::enableBtnTable(objReplayControls, {
        ID_PREV_PLANE               = mode != SPECTATOR_MODE.REPLAY || isMultiplayer
        ID_NEXT_PLANE               = mode != SPECTATOR_MODE.REPLAY || isMultiplayer
        ID_REPLAY_BACKWARD          = curAnchorIdx >= 0
        ID_REPLAY_FORWARD           = anchors.len() > 0 && (curAnchorIdx + 1) < anchors.len()
    })
    foreach(id, show in {
          txt_replay_time_speed       = canControlTimeline
          controls_timeline           = canControlTimeline
          controls_timer              = canSeeMissionTimer
        })
      scene.findObject(id).show(show)

    for (local i = 0; i < objReplayControls.childrenCount(); i++)
    {
      let obj = objReplayControls.getChild(i)
      if (obj?.is_shortcut && obj?.id)
      {
        local hotkeys = ::get_shortcut_text({
          shortcuts = ::get_shortcuts([ obj.id ])
          shortcutId = 0
          cantBeEmpty = false
          strip_tags = true
        })
        if (hotkeys.len())
          hotkeys = "<color=@hotkeyColor>" + ::loc("ui/parentheses/space", {text = hotkeys}) + "</color>"
        obj.tooltip = ::loc("hotkeys/" + obj.id) + hotkeys
      }
    }

    if (canControlCameras)
    {
      ::showBtnTable(scene, {
          ID_CAMERA_DEFAULT           = mode == SPECTATOR_MODE.REPLAY || gotRefereeRights
          ID_TOGGLE_FOLLOWING_CAMERA  = mode == SPECTATOR_MODE.REPLAY || gotRefereeRights
          ID_REPLAY_CAMERA_OPERATOR   = mode == SPECTATOR_MODE.REPLAY && !gotRefereeRights
          ID_REPLAY_CAMERA_FLYBY      = mode == SPECTATOR_MODE.REPLAY && !gotRefereeRights
          ID_REPLAY_CAMERA_WING       = mode == SPECTATOR_MODE.REPLAY && !gotRefereeRights
          ID_REPLAY_CAMERA_GUN        = mode == SPECTATOR_MODE.REPLAY && !gotRefereeRights
          ID_REPLAY_CAMERA_RANDOMIZE  = mode == SPECTATOR_MODE.REPLAY && !gotRefereeRights
          ID_REPLAY_CAMERA_FREE       = mode == SPECTATOR_MODE.REPLAY && !gotRefereeRights
          ID_REPLAY_CAMERA_FREE_PARENTED = mode == SPECTATOR_MODE.REPLAY && !gotRefereeRights
          ID_REPLAY_CAMERA_FREE_ATTACHED = mode == SPECTATOR_MODE.REPLAY && !gotRefereeRights
      })
    }

    if (mode == SPECTATOR_MODE.REPLAY)
    {
      let timeSpeeds = get_time_speeds_list()
      replayTimeSpeedMin = timeSpeeds[0]
      replayTimeSpeedMax = timeSpeeds[timeSpeeds.len() - 1]

      let info = ::current_replay.len() && get_replay_info(::current_replay)
      let comments = info && ::getTblValue("comments", info)
      if (comments)
      {
        replayAuthorUserId = ::getTblValue("authorUserId", comments, replayAuthorUserId)
        replayTimeTotal = ::getTblValue("timePlayed", comments, replayTimeTotal)
        scene.findObject("txt_replay_time_total").setValue(time.preciseSecondsToString(replayTimeTotal))
      }

      let replaySessionId = ::getTblValue("sessionId", replayProps, "")
      scene.findObject("txt_replay_session_id").setValue(replaySessionId)
    }

    funcSortPlayersSpectator = mpstatSortSpectator.bindenv(this)
    funcSortPlayersDefault   = ::mpstat_get_sort_func(gameType)

    ::g_hud_live_stats.init(scene, "spectator_live_stats_nest", false)
    actionBar = ActionBar(scene.findObject("spectator_hud_action_bar"))
    actionBar.reinit()
    if (!::has_feature("SpectatorUnitDmgIndicator"))
      scene.findObject("xray_render_dmg_indicator_spectator").show(false)
    reinitDmgIndicator()
    recalculateLayout()

    ::g_hud_event_manager.subscribe("HudMessage", function(eventData)
      {
        onHudMessage(eventData)
      }, this)

    onUpdate()
    scene.findObject("update_timer").setUserData(this)

    updateClientHudOffset()
    fillAnchorsMarkers()
  }

  function reinitScreen()
  {
    updateHistoryLog(true)
    loadGameChat()

    ::g_hud_live_stats.update()
    actionBar.reinit()
    reinitDmgIndicator()
    recalculateLayout()
    updateTarget(true)
  }

  function fillTabs()
  {
    let view = {
      tabs = []
    }
    foreach(tab in tabsList)
      view.tabs.append({
        tabName = ::loc(tab.locId)
        id = tab.id
        alert = "no"
        cornerImg = "#ui/gameuiskin#new_icon.svg"
        cornerImgId = "new_msgs"
        cornerImgTiny = true
      })

    let tabsObj = this.showSceneBtn("tabs", true)
    let data = ::handyman.renderCached("%gui/frameHeaderTabs", view)
    guiScene.replaceContentFromText(tabsObj, data, data.len(), this)
    tabsObj.setValue(0)
  }

  function loadGameChat()
  {
    if (isMultiplayer)
    {
      chatData = ::loadGameChatToObj(scene.findObject("chat_container"), "%gui/chat/gameChatSpectator.blk", this,
                                     {selfHideInput = true, hiddenInput = !canSendChatMessages })

      let objGameChat = scene.findObject("gamechat")
      ::showBtnTable(objGameChat, {
          chat_input_div         = canSendChatMessages
          chat_input_placeholder = canSendChatMessages
      })
      let objChatLogDiv = objGameChat.findObject("chat_log_tdiv")
      objChatLogDiv.size = canSendChatMessages ? objChatLogDiv.sizeWithInput : objChatLogDiv.sizeWithoutInput

      if (mode == SPECTATOR_MODE.SKIRMISH || mode == SPECTATOR_MODE.SUPERVISOR)
        ::chat_set_mode(CHAT_MODE_ALL, "")
    }
  }

  function onShowHud(show = true, needApplyPending = false)
  {
  }

  function onUpdate(obj=null, dt=0.0)
  {
    if (!spectatorModeInited && is_in_flight())
    {
      if (!getTargetPlayer())
      {
        spectatorModeInited = true
        onSpectatorMode(true)
        catchingFirstTarget = isMultiplayer && gotRefereeRights
        ::dagor.debug("Spectator: init " + ::getEnumValName("SPECTATOR_MODE", mode))
      }
      updateCooldown = 0.0
    }

    if (!::checkObj(scene))
      return

    updateCooldown -= dt
    let isUpdateByCooldown = updateCooldown <= 0.0

    let targetNick  = getSpectatorTargetName()
    let hudUnitType = ::getAircraftByName(getActionBarUnitName())?.esUnitType ?? ::ES_UNIT_TYPE_INVALID
    let isTargetSwitched = targetNick != lastTargetNick || hudUnitType != lastHudUnitType
    lastTargetNick  = targetNick
    lastHudUnitType = hudUnitType

    let friendlyTeam = ::get_player_army_for_hud()
    let friendlyTeamSwitched = friendlyTeam != lastFriendlyTeam
    lastFriendlyTeam = friendlyTeam

    if (isUpdateByCooldown || isTargetSwitched || friendlyTeamSwitched)
    {
      updateTarget(isTargetSwitched)
      updateStats()
    }

    if (friendlyTeamSwitched || isTargetSwitched)
    {
      ::g_hud_live_stats.show(isMultiplayer, null, spectatorWatchedHero.id)
      ::broadcastEvent("WatchedHeroSwitched")
      updateHistoryLog()
    }

    updateControls(isTargetSwitched)

    if (isUpdateByCooldown)
    {
      updateCooldown = 0.5

      // Forced switching target to catch the first target
      if (spectatorModeInited && catchingFirstTarget)
      {
        if (getTargetPlayer())
          catchingFirstTarget = false
        else
        {
          foreach (info in teams)
            foreach (p in info.players)
              if (p.state == ::PLAYER_IN_FLIGHT && !p.isDead)
              {
                switchTargetPlayer(p.id)
                break
              }
        }
      }
    }
  }

  function isPlayerFriendly(player)
  {
    return player != null && player.team == ::get_player_army_for_hud()
  }

  function getPlayerNick(player, needColored = false, needClanTag = true)
  {
    if (player == null)
      return  ""
    local name = ::g_contacts.getPlayerFullName(
      getPlayerName(player.name), // can add platform icon
      needClanTag && !player.isBot ? player.clanTag : "")
    if (mode == SPECTATOR_MODE.REPLAY && player?.realName != "")
      name = $"{name} ({player.realName})"
    return needColored ? ::colorize(getPlayerColor(player), name) : name
  }

  function getPlayerColor(player)
  {
    return player.isLocal ? "hudColorHero"
    : player.isInHeroSquad ? "hudColorSquad"
    : player.team == ::get_player_army_for_hud() ? "hudColorBlue"
    : "hudColorRed"
  }

  function getPlayerStateDesc(player)
  {
    return !player ? "" :
      !player.ingame ? ::loc(player.deaths ? "spectator/player_quit" : "multiplayer/state/player_not_in_game") :
      player.isDead ? ::loc(player.deaths ? "spectator/player_vehicle_lost" : "spectator/player_connecting") :
      !player.canBeSwitchedTo ? ::loc("multiplayer/state/player_in_game/location_unknown") : ""
  }

  function getUnitMalfunctionDesc(player)
  {
    if (!player || !player.ingame || player.isDead)
      return ""
    let briefMalfunctionState = ::getTblValue("briefMalfunctionState", player, 0)
    let list = []
    if (::getTblValue("isExtinguisherActive", player, false))
      list.append(::loc("fire_extinguished"))
    else if (::getTblValue("isBurning", player, false))
      list.append(::loc("fire_in_unit"))
    if (briefMalfunctionState & ::BMS_ENGINE_BROKEN)
      list.append(::loc("my_dmg_msg/tank_engine"))
    if (briefMalfunctionState & ::BMS_MAIN_GUN_BROKEN)
      list.append(::loc("my_dmg_msg/tank_gun_barrel"))
    if (briefMalfunctionState & ::BMS_TRACK_BROKEN)
      list.append(::loc("my_dmg_msg/tank_track"))
    if (briefMalfunctionState & ::BMS_OUT_OF_AMMO)
      list.append(::loc("controls/no_bullets_left"))
    if (briefMalfunctionState & ::BMS_OUT_OF_BOMBS)
      list.append(::loc("controls/no_bombs_left"))
    if (briefMalfunctionState & ::BMS_OUT_OF_ROCKETS)
      list.append(::loc("controls/no_rockets_left"))
    if (briefMalfunctionState & ::BMS_OUT_OF_TORPEDOES)
      list.append(::loc("controls/no_torpedoes_left"))
    local desc = ::g_string.implode(list, ::loc("ui/semicolon"))
    if (desc.len())
      desc = ::colorize("warningTextColor", desc)
    return desc
  }

  function getPlayer(id)
  {
    foreach (info in teams)
      foreach (p in info.players)
        if (p.id == id)
          return p
    return null
  }

  function getPlayerByUserId(userId)
  {
    foreach (info in teams)
      foreach (p in info.players)
        if (p.userId == userId.tostring())
          return p
    return null
  }

  function getTargetPlayer()
  {
    if (!isMultiplayer)
      return (getSpectatorTargetName().len() && teams.len() && teams[0].players.len())
        ? teams[0].players[0]
        : null

    let targetId = getSpectatorTargetId()
    if (targetId >= 0)
      return getPlayer(targetId)

    return (mode == SPECTATOR_MODE.RESPAWN && lastTargetData.id >= 0)
      ? getPlayer(lastTargetData.id)
      : null
  }

  function setTargetInfo(player)
  {
    let infoObj = scene.findObject("target_info")
    let waitingObj = scene.findObject("waiting_for_target_spawn")
    if (!::checkObj(infoObj) || !::checkObj(waitingObj))
      return

    infoObj.show(player != null && isMultiplayer)
    waitingObj.show(player == null && catchingFirstTarget)

    if (!player || !isMultiplayer)
      return

    guiScene.setUpdatesEnabled(false, false)

    if (isMultiplayer)
    {
      let statusObj = infoObj.findObject("target_state")
      statusObj.setValue(getPlayerStateDesc(player))
    }

    guiScene.setUpdatesEnabled(true, true)
  }

  function updateTarget(targetSwitched = false, needFocusTargetTable = false)
  {
    let player = getTargetPlayer()

    if (targetSwitched)
    {
      spectatorWatchedHero.id      = player?.id ?? -1
      spectatorWatchedHero.squadId = player?.squadId ?? INVALID_SQUAD_ID
      spectatorWatchedHero.name    = player?.name ?? ""
    }

    local isFocused = false
    if (needFocusTargetTable)
      isFocused = selectTargetTeamBlock()

    ::g_hud_live_stats.show(isMultiplayer, null, spectatorWatchedHero.id)
    actionBar.reinit()
    reinitDmgIndicator()
    recalculateLayout()

    setTargetInfo(player)
    return isFocused
  }

  function updateControls(targetSwitched = false)
  {
    if (canControlTimeline)
    {
      if (::is_game_paused() != replayPaused)
      {
        replayPaused = ::is_game_paused()
        scene.findObject("ID_REPLAY_PAUSE").findObject("icon")["background-image"] = replayPaused ? "#ui/gameuiskin#replay_play.svg" : "#ui/gameuiskin#replay_pause.svg"
      }
      if (get_time_speed() != replayTimeSpeed)
      {
        replayTimeSpeed = get_time_speed()
        scene.findObject("txt_replay_time_speed").setValue(format("%.3fx", replayTimeSpeed))
        scene.findObject("ID_REPLAY_SLOWER").enable(replayTimeSpeed > replayTimeSpeedMin)
        scene.findObject("ID_REPLAY_FASTER").enable(replayTimeSpeed < replayTimeSpeedMax)
      }
      if (::is_replay_markers_enabled() != replayMarkersEnabled)
      {
        replayMarkersEnabled = ::is_replay_markers_enabled()
        scene.findObject("ID_REPLAY_SHOW_MARKERS").highlighted = replayMarkersEnabled ? "yes" : "no"
      }
      let replayTimeCurrent = ::get_usefull_total_time()
      scene.findObject("txt_replay_time_current").setValue(time.preciseSecondsToString(replayTimeCurrent))
      let progress = (replayTimeTotal > 0) ? (1000 * replayTimeCurrent / replayTimeTotal).tointeger() : 0
      if (progress != replayTimeProgress)
      {
        replayTimeProgress = progress
        scene.findObject("timeline_progress").setValue(replayTimeProgress)
      }

      if (::has_feature("replayRewind")) {
        let anchors = get_replay_anchors()
        let curAnchorIdx = getCurAnchorIdx(anchors)
        ::enableBtnTable(scene, {
          ID_REPLAY_BACKWARD          = curAnchorIdx >= 0
          ID_REPLAY_FORWARD           = anchors.len() > 0 && (curAnchorIdx + 1) < anchors.len()
        })
      }
    }

    if (canSeeMissionTimer)
    {
      scene.findObject("txt_mission_timer").setValue(time.secondsToString(::get_usefull_total_time(), false))
    }

    if (::is_spectator_rotation_forced() != cameraRotationByMouse)
    {
      cameraRotationByMouse = ::is_spectator_rotation_forced()
      scene.findObject("ID_TOGGLE_FORCE_SPECTATOR_CAM_ROT").highlighted = cameraRotationByMouse ? "yes" : "no"
    }

    if (canControlCameras && targetSwitched)
    {
      let player = getTargetPlayer()
      let isValid = player != null
      let isPlayer = player ? !player.isBot : false
      let userId   = player ? ::getTblValue("userId", player, 0) : 0
      let isAuthor = userId == replayAuthorUserId
      let isAuthorUnknown = replayAuthorUserId == -1
      let isAircraft = ::isInArray(lastHudUnitType, [::ES_UNIT_TYPE_AIRCRAFT, ::ES_UNIT_TYPE_HELICOPTER])

      ::enableBtnTable(scene, {
          ID_CAMERA_DEFAULT           = isValid
          ID_TOGGLE_FOLLOWING_CAMERA  = isValid && isPlayer && (gotRefereeRights || isAuthor || isAuthorUnknown)
          ID_REPLAY_CAMERA_OPERATOR   = isValid
          ID_REPLAY_CAMERA_FLYBY      = isValid
          ID_REPLAY_CAMERA_WING       = isValid
          ID_REPLAY_CAMERA_GUN        = isValid
          ID_REPLAY_CAMERA_RANDOMIZE  = isValid
          ID_REPLAY_CAMERA_FREE       = isValid
          ID_REPLAY_CAMERA_FREE_PARENTED = isValid
          ID_REPLAY_CAMERA_FREE_ATTACHED = isValid
          ID_REPLAY_CAMERA_HOVER      = isValid && !isAircraft
      })
    }
  }

  function reinitDmgIndicator()
  {
    let obj = scene.findObject("spectator_hud_damage")
    if (::check_obj(obj))
      obj.show(getTargetPlayer() != null)
  }

  function statTblGetSelectedPlayer(obj)
  {
    let teamNum = ::getObjIdByPrefix(obj, "table_team")
    if (!teamNum || (teamNum != "1" && teamNum != "2"))
      return null
    let teamIndex = teamNum.tointeger() - 1
    let players =  teams[teamIndex].players
    let value = obj.getValue()
    if (value < 0 || value >= players.len())
      return null

    return players[value]
  }

  function onPlayerClick(obj)
  {
    if (ignoreUiInput)
      return

    selectPlayer(statTblGetSelectedPlayer(obj), obj)
  }

  function selectPlayer(player, tableObj)
  {
    if (!player)
      return

    statSelPlayerId[teamIdToIndex(player.team)] = player.id
    switchTargetPlayer(player.id)
  }

  function onPlayerRClick(obj)
  {
    let player = statTblGetSelectedPlayer(obj)
    if (player)
      ::session_player_rmenu(
        this,
        player,
        {
          chatLog = ::get_game_chat_handler()?.getChatLogForBanhammer() ?? ""
        }
      )
  }

  function switchTargetPlayer(id)
  {
    if (id >= 0)
      switchSpectatorTargetById(id)
  }

  function saveLastTargetPlayerData(player)
  {
    lastTargetData.team = teamIdToIndex(player.team)
    lastTargetData.id = player.id
  }

  function selectTargetTeamBlock()
  {
    let player = getTargetPlayer()
    if (!player)
      return false

    saveLastTargetPlayerData(player)
    statSelPlayerId[lastTargetData.team] = player.id

    let tblObj = getTeamTableObj(player.team)
    if (!tblObj)
      return false
    ::move_mouse_on_child_by_value(tblObj)
    return true
  }

  function selectControlsBlock(obj)
  {
    if (::get_is_console_mode_enabled())
      selectTargetTeamBlock()
  }

  function onSelectPlayer(obj)
  {
    if (ignoreUiInput)
      return

    let player = statTblGetSelectedPlayer(obj)
    if (!player)
      return

    let curPlayer = getTargetPlayer()
    if (::get_is_console_mode_enabled() && u.isEqual(curPlayer, player))
    {
      let selIndex = ::get_obj_valid_index(obj)
      let selectedPlayerBlock = obj.getChild(selIndex >= 0? selIndex : 0)
      ::session_player_rmenu(
        this,
        player,
        {
          chatLog = ::get_game_chat_handler()?.getChatLogForBanhammer() ?? ""
        },
        [
          selectedPlayerBlock.getPosRC()[0] + selectedPlayerBlock.getSize()[0]/2,
          selectedPlayerBlock.getPosRC()[1]
        ]
      )
      return
    }

    saveLastTargetPlayerData(player)
    selectPlayer(player, obj)
  }

  function onChangeFocusTable(obj)
  {
    lastSelectedTableId = obj.id
  }

  function onBtnMpStatScreen(obj)
  {
    if (isMultiplayer)
      guiStartMPStatScreen()
    else
      ::gui_start_tactical_map()
  }

  function onBtnShortcut(obj)
  {
    let id = ::check_obj(obj) ? (obj?.id ?? "") : ""
    if (id.len() > 3 && id.slice(0, 3) == "ID_")
      toggleShortcut(id)
  }

  function onMapClick(obj = null)
  {
    let mapLargePanelObj = scene.findObject("map_large_div")
    if (!::checkObj(mapLargePanelObj))
      return
    let mapLargeObj = mapLargePanelObj.findObject("tactical_map")
    if (!::checkObj(mapLargeObj))
      return

    let toggle = !mapLargePanelObj.isVisible()
    mapLargePanelObj.show(toggle)
    mapLargeObj.show(toggle)
    mapLargeObj.enable(toggle)
  }

  function onToggleButtonClick(obj)
  {
    if (!::checkObj(obj) || !("toggleObj" in obj))
      return
    let toggleObj = scene.findObject(obj?.toggleObj)
    if (!::checkObj(toggleObj))
      return

    let toggle = !toggleObj.isVisible()
    toggleObj.show(toggle)
    obj.toggled = toggle ? "yes" : "no"

    updateHistoryLog(true)
    updateClientHudOffset()
    recalculateLayout()
  }

  function teamIdToIndex(teamId)
  {
    foreach (info in teams)
      if (info.teamId == teamId)
        return info.index
    return 0
  }

  function getTableObj(index)
  {
    let obj = scene.findObject($"table_team{index + 1}")
    return ::check_obj(obj) ? obj : null
  }

  function getTeamTableObj(teamId)
  {
    return getTableObj(teamIdToIndex(teamId))
  }

  function getTeamPlayers(teamId)
  {
    let tbl = (teamId != 0) ? ::get_mplayers_list(teamId, true) : [ ::get_local_mplayer() ]
    for (local i = tbl.len() - 1; i >= 0; i--)
    {
      let player = tbl[i]
      if (player.spectator
        || (mode == SPECTATOR_MODE.SKIRMISH
          && (player.state != ::PLAYER_IN_FLIGHT || player.isDead) && !player.deaths))
      {
        tbl.remove(i)
        continue
      }

      player.team = teamId
      player.ingame <- player.state == ::PLAYER_IN_FLIGHT || player.state == ::PLAYER_IN_RESPAWN
      player.isActing <- player.ingame
        && (!(gameType & ::GT_RACE) || player.raceFinishTime < 0)
        && (!(gameType & ::GT_LAST_MAN_STANDING) || player.deaths == 0)
      if (mode == SPECTATOR_MODE.REPLAY && !player.isBot)
        player.isBot = player.userId == "0" || ::getTblValue("invitedName", player) != null
      local unitId = (!player.isDead && player.state == ::PLAYER_IN_FLIGHT) ? player.aircraftName : null
      unitId = (unitId != "dummy_plane" && unitId != "") ? unitId : null
      player.aircraftName = unitId || ""
      player.canBeSwitchedTo = unitId ? player.canBeSwitchedTo : false
      player.isLocal = spectatorWatchedHero.id == player.id
      player.isInHeroSquad = ::SessionLobby.isEqualSquadId(spectatorWatchedHero.squadId, player?.squadId)
    }
    tbl.sort(funcSortPlayersSpectator)
    return tbl
  }

  function mpstatSortSpectator(a, b)
  {
    return b.isActing <=> a.isActing
      || (!a.isActing && funcSortPlayersDefault(a, b))
      || a.isBot <=> b.isBot
      || a.id <=> b.id
  }

  function getTeamClanTag(players)
  {
    let clanTag = players?[0]?.clanTag ?? ""
    if (players.len() < 2 || clanTag == "")
      return ""
    foreach (p in players)
      if (p.clanTag != clanTag)
        return ""
    return clanTag
  }

  function getPlayersData()
  {
    let _teams = array(2, null)
    let isMpMode = !!(gameType & ::GT_VERSUS) || !!(gameType & ::GT_COOPERATIVE)
    let isPvP = !!(gameType & ::GT_VERSUS)
    let isTeamplay = isPvP && ::is_mode_with_teams(gameType)

    if (isTeamplay || !canSeeOppositeTeam)
    {
      let localTeam = ::get_mp_local_team() != 2 ? 1 : 2
      let isMyTeamFriendly = localTeam == ::get_player_army_for_hud()

      for (local i = 0; i < 2; i++)
      {
        let teamId = ((i == 0) == (localTeam == 1)) ? Team.A : Team.B
        let color = ((i == 0) == isMyTeamFriendly)? "blue" : "red"
        let players = getTeamPlayers(teamId)

        _teams[i] = {
          active = true
          index = i
          teamId = teamId
          players = players
          color = color
          clanTag = getTeamClanTag(players)
        }
      }
    }
    else if (isMpMode)
    {
      let teamId = isTeamplay ? ::get_mp_local_team() : ::GET_MPLAYERS_LIST
      let color  = isTeamplay ? "blue" : "red"
      let players = getTeamPlayers(teamId)

      _teams[0] = {
        active = true
        index = 0
        teamId = teamId
        players = players
        color = color
        clanTag = isTeamplay ? getTeamClanTag(players) : ""
      }
      _teams[1] = {
        active = false
        index = 1
        teamId = 0
        players = []
        color = ""
        clanTag = ""
      }
    }
    else
    {
      let teamId = 0
      let color = "blue"
      let players = getTeamPlayers(teamId)

      _teams[0] = {
        active = false
        index = 0
        teamId = teamId
        players = players
        color = color
        clanTag = ""
      }
      _teams[1] = {
        active = false
        index = 1
        teamId = 0
        players = []
        color = ""
        clanTag = ""
      }
    }

    local length = 0
    foreach (info in _teams)
      length = max(length, info.players.len())
    let maxNoScroll = ::global_max_players_versus / 2
    statNumRows = min(maxNoScroll, length)
    return _teams
  }

  function updateStats()
  {
    let _teams = getPlayersData()
    foreach (idx, info in _teams)
    {
      let tblObj = getTableObj(info.index)
      if (tblObj)
      {
        let infoPrev = ::getTblValue(idx, teams)
        if (info.active)
          statTblUpdateInfo(tblObj, info, infoPrev)
        if (info.active != ::getTblValue("active", infoPrev, true))
        {
          tblObj.getParent().getParent().show(info.active)
          scene.findObject("btnToggleStats" + (idx + 1)).show(info.active)
        }
      }
    }
    teams = _teams
  }

  function addPlayerRows(objTbl, teamInfo)
  {
    let totalRows = objTbl.childrenCount()
    let newRows = teamInfo.players.len() - totalRows
    if (newRows <= 0)
      return totalRows

    let view = { rows = array(newRows, 1)
                   iconLeft = teamInfo.index == 0
                 }
    let data = ::handyman.renderCached(("%gui/hud/spectatorTeamRow"), view)
    guiScene.appendWithBlk(objTbl, data, this)
    return totalRows
  }

  function isPlayerChanged(p1, p2)
  {
    if (debugMode)
      return true
    if (!p1 != !p2)
      return true
    if (!p1)
      return false
    foreach(param in scanPlayerParams)
      if (::getTblValue(param, p1) != ::getTblValue(param, p2))
        return true
    return false
  }

  function statTblUpdateInfo(objTbl, teamInfo, infoPrev = null)
  {
    let players = ::getTblValue("players", teamInfo)
    if (!::checkObj(objTbl) || !players)
      return

    guiScene.setUpdatesEnabled(false, false)

    let prevPlayers = ::getTblValue("players", infoPrev)
    let wasRows = addPlayerRows(objTbl, teamInfo)
    let totalRows = objTbl.childrenCount()

    let selPlayerId = getTblValue(teamInfo.index, statSelPlayerId)
    local selIndex = null

    let needClanTags = (teamInfo?.clanTag ?? "") == ""

    for(local i = 0; i < totalRows; i++)
    {
      let player = ::getTblValue(i, players)
      if (i < wasRows && !isPlayerChanged(player, ::getTblValue(i, prevPlayers)))
        continue

      let obj = objTbl.getChild(i)
      obj.show(player != null)
      if (!player)
        continue

      let nameObj = obj.findObject("name")
      if (!::checkObj(nameObj)) //some validation
        continue

      let playerName = getPlayerNick(player)
      let playerNameShort = needClanTags ? playerName : getPlayerNick(player, false, false)
      nameObj.setValue(playerNameShort)

      let unitId = player.aircraftName != "" ? player.aircraftName : null
      let iconImg = !player.ingame ? "#ui/gameuiskin#player_not_ready.svg"
        : unitId ? ::getUnitClassIco(unitId)
        : "#ui/gameuiskin#dead.svg"
      let iconType = unitId ? getUnitRole(unitId) : ""
      let stateDesc = getPlayerStateDesc(player)
      let malfunctionDesc = getUnitMalfunctionDesc(player)

      obj.hero = player.isLocal ? "yes" : "no"
      obj.squad = player.isInHeroSquad ? "yes" : "no"
      obj.dead = player.canBeSwitchedTo ? "no" : "yes"
      obj.isBot = player.isBot ? "yes" : "no"
      obj.findObject("unit").setValue(getUnitName(unitId || "dummy_plane"))
      obj.tooltip = playerName + (unitId ? ::loc("ui/parentheses/space", {text = ::getUnitName(unitId, false)}) : "")
        + (stateDesc != "" ? ("\n" + stateDesc) : "")
        + (malfunctionDesc != "" ? ("\n" + malfunctionDesc) : "")

      if (debugMode)
        obj.tooltip += "\n\n" + getPlayerDebugTooltipText(player)

      let unitIcoObj = obj.findObject("unit-ico")
      unitIcoObj["background-image"] = iconImg
      unitIcoObj.shopItemType = iconType

      let briefMalfunctionState = ::getTblValue("briefMalfunctionState", player, 0)
      let weaponIcons = (unitId && ("weapon" in player)) ? getWeaponTypeIcoByWeapon(unitId, player.weapon)
        : getWeaponTypeIcoByWeapon("", "")

      foreach (iconId, w in weaponIcons)
      {
        let weaponIcoObj = obj.findObject($"{iconId}-ico")
        if (!(weaponIcoObj?.isValid() ?? false))
          continue

        let isVisible = w.icon != ""
        weaponIcoObj.show(isVisible)
        if (!isVisible)
          continue

        let iconSize = $"{w.ratio}@tableIcoSize, @tableIcoSize"
        weaponIcoObj.size = iconSize
        weaponIcoObj["background-image"] = w.icon
        weaponIcoObj["background-svg-size"] = iconSize
        weaponIcoObj["reloading"] = (iconId in weaponIconsReloadBits)
          && (briefMalfunctionState & weaponIconsReloadBits[iconId]) != 0 ? "yes" : "no"
      }

      let battleStateIconClass =
        (!player.ingame || player.isDead)                     ? "" :
        ::getTblValue("isExtinguisherActive", player, false)  ? "ExtinguisherActive" :
        ::getTblValue("isBurning", player, false)             ? "IsBurning" :
        (briefMalfunctionState & ::BMS_ENGINE_BROKEN)         ? "BrokenEngine" :
        (briefMalfunctionState & ::BMS_MAIN_GUN_BROKEN)       ? "BrokenGun" :
        (briefMalfunctionState & ::BMS_TRACK_BROKEN)          ? "BrokenTrack" :
        (briefMalfunctionState & ::BMS_OUT_OF_AMMO)           ? "OutOfAmmo" :
                                                                ""
      obj.findObject("battle-state-ico")["class"] = battleStateIconClass

      if (player.id == selPlayerId)
        selIndex = i
    }

    if (selIndex != null && objTbl.getValue() != selIndex && objTbl.isFocused())
    {
      ignoreUiInput = true
      objTbl.setValue(selIndex)
      ignoreUiInput = false
    }

    if (objTbl.team != teamInfo.color)
      objTbl.team = teamInfo.color

    let headerObj = objTbl.getParent().getParent().findObject("header")
    if (::check_obj(headerObj))
      headerObj.setValue(teamInfo.clanTag)

    guiScene.setUpdatesEnabled(true, true)
  }

  function getPlayerDebugTooltipText(player)
  {
    if (!player)
      return ""
    let extra = []
    foreach (i, v in player)
    {
      if (i == "uid")
        continue
      let val = (i == "state") ? playerStateToString(v) : v
      extra.append(i + " = " + val)
    }
    extra.sort()
    return ::g_string.implode(extra, "\n")
  }

  function playerStateToString(state)
  {
    switch (state)
    {
      case ::PLAYER_NOT_EXISTS:                 return "PLAYER_NOT_EXISTS"
      case ::PLAYER_HAS_LEAVED_GAME:            return "PLAYER_HAS_LEAVED_GAME"
      case ::PLAYER_IN_LOBBY_NOT_READY:         return "PLAYER_IN_LOBBY_NOT_READY"
      case ::PLAYER_IN_LOADING:                 return "PLAYER_IN_LOADING"
      case ::PLAYER_IN_STATISTICS_BEFORE_LOBBY: return "PLAYER_IN_STATISTICS_BEFORE_LOBBY"
      case ::PLAYER_IN_LOBBY_READY:             return "PLAYER_IN_LOBBY_READY"
      case ::PLAYER_READY_TO_START:             return "PLAYER_READY_TO_START"
      case ::PLAYER_IN_FLIGHT:                  return "PLAYER_IN_FLIGHT"
      case ::PLAYER_IN_RESPAWN:                 return "PLAYER_IN_RESPAWN"
      default:                                  return "" + state
    }
  }

  function updateClientHudOffset()
  {
    guiScene.setUpdatesEnabled(true, true)
    let obj = scene.findObject("stats_left")
    ::spectator_air_hud_offset_x = (::checkObj(obj) && obj.isVisible()) ? obj.getPos()[0] + obj.getSize()[0] : 0
  }

  function onBtnLogTabSwitch(obj)
  {
    if (!::checkObj(obj))
      return

    let tabIdx = obj.getValue()
    if (tabIdx < 0 || tabIdx >= obj.childrenCount())
      return

    let tabObj = obj.getChild(tabIdx)
    let newTabId = tabObj?.id
    if (!newTabId || newTabId == curTabId)
      return

    foreach(tab in tabsList)
    {
      let objContainer = scene.findObject(tab.containerId)
      if (!::checkObj(objContainer))
        continue

      objContainer.show(tab.id == newTabId)
    }
    curTabId = newTabId
    tabObj.findObject("new_msgs").show(false)

    ::g_orders.showOrdersContainer(curTabId == SPECTATOR_CHAT_TAB.ORDERS)

    if (curTabId == SPECTATOR_CHAT_TAB.CHAT)
      loadGameChat()
    updateHistoryLog(true)
  }

  function updateNewMsgImg(tabId)
  {
    if (!scene.isValid() || tabId == curTabId)
      return
    let obj = scene.findObject(tabId)
    if (::checkObj(obj))
      obj.findObject("new_msgs").show(true)
  }

  function onEventMpChatLogUpdated(params)
  {
    updateNewMsgImg(SPECTATOR_CHAT_TAB.CHAT)
  }

  function onEventActiveOrderChanged(params)
  {
    updateNewMsgImg(SPECTATOR_CHAT_TAB.ORDERS)
  }

  function onEventMpChatInputRequested(params)
  {
    if (!::checkObj(scene))
      return
    if (!canSendChatMessages)
      return

    local obj = scene.findObject("btnToggleLog")
    if (::checkObj(obj) && obj?.toggled != "yes")
      onToggleButtonClick(obj)

    obj = scene.findObject("tabs")
    let chatTabId = SPECTATOR_CHAT_TAB.CHAT
    if (::checkObj(obj) && curTabId != chatTabId)
      obj.setValue(tabsList.findindex(@(t) t.id == chatTabId) ?? -1)

    if (::getTblValue("activate", params, false))
      ::game_chat_input_toggle_request(true)
  }

  function onEventHudActionbarResized(params)
  {
    recalculateLayout()
  }

  function onPlayerRequestedArtillery(userId)
  {
    let player = getPlayerByUserId(userId)
    let color = isPlayerFriendly(player) ? "hudColorDarkBlue" : "hudColorDarkRed"
    addHistroyLogMessage(::colorize(color, ::loc("artillery_strike/called_by_player", { player =  getPlayerNick(player, true) })))
  }

  function onHudMessage(msg)
  {
    if (!::isInArray(msg.type, supportedMsgTypes))
      return

    if (!("id" in msg))
      msg.id <- -1
    if (!("text" in msg))
      msg.text <- ""

    msg.time <- ::get_usefull_total_time()

    historyLog = historyLog || []
    if (msg.id != -1)
      foreach (m in historyLog)
        if (m.id == msg.id)
          return
    if (msg.id == -1 && msg.text != "")
    {
      let skipDupTime = msg.time - historySkipDuplicatesSec
      for (local i = historyLog.len() - 1; i >= 0; i--)
      {
        if (historyLog[i].time < skipDupTime && msg.type != ::HUD_MSG_DEATH_REASON)
          break
        if (historyLog[i].text == msg.text)
          return
      }
    }

    msg.message <- buildHistoryLogMessage(msg)
    if (msg.message == "")
      return

    if (historyLog.len() == historyMaxLen)
      historyLog.remove(0)
    historyLog.append(msg)

    updateHistoryLog()
  }

  function addHistroyLogMessage(text)
  {
    onHudMessage({
      id   = -1
      text = text
      type = historyLogCustomMsgType
    })
  }

  function clearHistoryLog()
  {
    if (!historyLog)
      return
    historyLog.clear()
    updateHistoryLog()
  }

  function updateHistoryLog(updateVisibility = false)
  {
    if (!::checkObj(scene))
      return

    let obj = scene.findObject("history_log")
    if (::checkObj(obj))
    {
      if (updateVisibility)
        guiScene.setUpdatesEnabled(true, true)
      historyLog = historyLog || []

      foreach (msg in historyLog)
        msg.message <- buildHistoryLogMessage(msg)

      let historyLogMessages = u.map(historyLog, @(msg) msg.message)
      obj.setValue(obj.isVisible() ? ::g_string.implode(historyLogMessages, "\n") : "")
    }
  }

  function buildHistoryLogMessage(msg)
  {
    let timestamp = time.secondsToString(msg.time, false) + " "
    switch (msg.type)
    {
      // All players messages
      case ::HUD_MSG_MULTIPLAYER_DMG: // Any player or ai unit damaged or destroyed
        let text = ::HudBattleLog.msgMultiplayerDmgToText(msg)
        let icon = ::HudBattleLog.getActionTextIconic(msg)
        return timestamp + ::colorize("userlogColoredText", $"{icon} {text}")
        break

      case ::HUD_MSG_STREAK_EX: // Any player got streak
        let text = ::HudBattleLog.msgStreakToText(msg, true)
        return timestamp + ::colorize("streakTextColor", ::loc("unlocks/streak") + ::loc("ui/colon") + text)
        break

      // Mission objectives
      case ::HUD_MSG_OBJECTIVE: // Hero team mission objective
        let text = ::HudBattleLog.msgEscapeCodesToCssColors(msg.text)
        return timestamp + ::colorize("white", ::loc("sm_objective") + ::loc("ui/colon") + text)
        break

      // Team progress
      case ::HUD_MSG_DIALOG: // Hero team base capture events
        let text = ::HudBattleLog.msgEscapeCodesToCssColors(msg.text)
        return timestamp + ::colorize("commonTextColor", text)
        break

      // Hero (spectated target) messages
      case ::HUD_MSG_DAMAGE: // Hero air unit damaged
      case ::HUD_MSG_ENEMY_DAMAGE: // Hero target air unit damaged
      case ::HUD_MSG_ENEMY_CRITICAL_DAMAGE: // Hero target air unit damaged
      case ::HUD_MSG_ENEMY_FATAL_DAMAGE: // Hero target air unit damaged
      case ::HUD_MSG_DEATH_REASON: // Hero unit destroyed, killer name
      case ::HUD_MSG_EVENT: // Hero tank unit damaged, and some system messages
      case historyLogCustomMsgType: // Custom messages sent by script
        let text = ::HudBattleLog.msgEscapeCodesToCssColors(msg.text)
        return timestamp + ::colorize("commonTextColor", text)
        break
      default:
        return ""
    }
  }

  function setHotkeysToObjTooltips(scanObj, objects)
  {
    if (::checkObj(scanObj))
      foreach (objId, keys in objects)
      {
        let obj = scanObj.findObject(objId)
        if (::checkObj(obj))
        {
          local hotkeys = ""
          if ("shortcuts" in keys)
          {
            let shortcuts = ::get_shortcuts(keys.shortcuts)
            let locNames = []
            foreach (idx, data in shortcuts)
            {
              let shortcutsText = ::get_shortcut_text({
                shortcuts = shortcuts,
                shortcutId = idx,
                strip_tags = true
              })
              if (shortcutsText != "")
                locNames.append(shortcutsText)
            }
            hotkeys = ::g_string.implode(locNames, ::loc("ui/comma"))
          }
          else if ("keys" in keys)
          {
            let keysLocalized = u.map(keys.keys, ::loc)
            hotkeys = ::g_string.implode(keysLocalized, ::loc("ui/comma"))
          }

          if (hotkeys != "")
          {
            let tooltip = obj?.tooltip ?? ""
            let add = "<color=@hotkeyColor>" + ::loc("ui/parentheses/space", {text = hotkeys}) + "</color>"
            obj.tooltip = tooltip + add
          }
        }
      }
  }

  function recalculateLayout()
  {
    let staticBoxes = []
    foreach (objId in staticWidgets)
    {
      let obj = scene.findObject(objId)
      if (!::checkObj(obj))
        continue
      if (obj.isVisible())
        staticBoxes.append(::GuiBox().setFromDaguiObj(obj))
    }

    foreach (objId, positions in movingWidgets)
    {
      let obj = scene.findObject(objId)
      if (!::checkObj(obj))
        continue

      if (!positions.len())
      {
        local idx = 1
        while (obj?["pos" + idx])
          positions.append(obj["pos" + idx++])
      }

      local posStr = "0, 0"
      let size = obj.getSize()
      foreach (p in positions)
      {
        posStr = p
        let pos = split_by_chars(posStr, ",")
        if (pos.len() != 2)
          break
        foreach (i, v in pos)
          pos[i] = guiScene.calcString(v, obj)
        let b1 = ::GuiBox(pos[0], pos[1], pos[0] + size[0], pos[1] + size[1])
        local fits = true
        foreach(b2 in staticBoxes)
        {
          if (b1.isIntersect(b2))
          {
            fits = false
            break
          }
        }
        if (fits)
          break
      }
      if (obj?.pos != posStr)
        obj.pos = posStr
    }
  }

  function getCurAnchorIdx(anchors) {
    let count = anchors.len()
    if (count == 0)
      return -1

    let replayCurTime = ::get_usefull_total_time() * 1000
    return (anchors.findindex(@(v) v > replayCurTime) ?? count) - 1
  }

  function moveToNextAnchor(directionIdx) {
    let anchors = get_replay_anchors()
    let nextIdx = getCurAnchorIdx(anchors) + directionIdx
    if (nextIdx < 0 || nextIdx >= anchors.len())
      return
    move_to_anchor(nextIdx)
  }

  onBtnBackward = @() moveToNextAnchor(-1)
  onBtnForward  = @() moveToNextAnchor(1)
  onAnchorMarkerClick = @(obj) move_to_anchor(obj.id.tointeger())

  function fillAnchorsMarkers() {
    if (!canControlTimeline || !::has_feature("replayRewind"))
      return
    let anchors = get_replay_anchors()
    if (anchors.len() == 0 || replayTimeTotal <= 0)
      return

    let timeTotal = replayTimeTotal
    let data = ::handyman.renderCached("%gui/replays/replayAnchorMark", {
      anchors = anchors.map(function(v, idx) {
        let anchorTimeS = v/1000.0
        return {
          idx
          posX = $"{anchorTimeS/timeTotal}pw - 2@dp"
          tooltip = ::loc("replay/move_to_time", {
            time = time.preciseSecondsToString(anchorTimeS) })
        }
      })
    })
    guiScene.replaceContentFromText(scene.findObject("timeline_progress"),
      data, data.len(), this)
  }
}

::spectator_debug_mode <- function spectator_debug_mode()
{
  let handler = ::is_dev_version && ::handlersManager.findHandlerClassInScene(::Spectator)
  if (!handler)
    return null
  handler.debugMode = !handler.debugMode
  return handler.debugMode
}

::isPlayerDedicatedSpectator <- function isPlayerDedicatedSpectator(name = null)
{
  if (name)
  {
    let member = ::SessionLobby.isInRoom() ? ::SessionLobby.getMemberByName(name) : null
    return member ? !!::SessionLobby.getMemberPublicParam(member, "spectator") : false
  }
  return !!::getTblValue("spectator", ::get_local_mplayer() || {}, 0)
}
::cross_call_api.isPlayerDedicatedSpectator <- ::isPlayerDedicatedSpectator

::spectator_air_hud_offset_x <- 0
::get_spectator_air_hud_offset_x <- function get_spectator_air_hud_offset_x() // called from client
{
  return ::spectator_air_hud_offset_x
}

::on_player_requested_artillery <- function on_player_requested_artillery(userId) // called from client
{
  let handler = ::handlersManager.findHandlerClassInScene(::Spectator)
  if (handler)
    handler.onPlayerRequestedArtillery(userId)
}

::on_spectator_tactical_map_request <- function on_spectator_tactical_map_request() // called from client
{
  let handler = ::handlersManager.findHandlerClassInScene(::Spectator)
  if (handler)
    handler.onMapClick()
}