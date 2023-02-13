from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { format } = require("string")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")

let u = require("%sqStdLibs/helpers/u.nut")
let time = require("%scripts/time.nut")
let spectatorWatchedHero = require("%scripts/replays/spectatorWatchedHero.nut")
let replayMetadata = require("%scripts/replays/replayMetadata.nut")
let { getUnitRole } = require("%scripts/unit/unitInfoTexts.nut")
let { getPlayerName } = require("%scripts/clientState/platform.nut")
let { useTouchscreen } = require("%scripts/clientState/touchScreen.nut")
let { toggleShortcut } = require("%globalScripts/controls/shortcutActions.nut")
let { getHudUnitType } = require("hudState")
let { guiStartMPStatScreen, getWeaponTypeIcoByWeapon
} = require("%scripts/statistics/mpStatisticsUtil.nut")
let { onSpectatorMode, switchSpectatorTargetById,
  getSpectatorTargetId = @() ::get_spectator_target_id(), // compatibility with 2.15.1.X
  getSpectatorTargetName = @() ::get_spectator_target_name() // compatibility with 2.15.1.X
} = require("guiSpectator")
let { get_time_speeds_list, get_time_speed, is_replay_playing, get_replay_anchors,
  get_replay_info, get_replay_props, move_to_anchor, cancel_loading = @() null } = require("replays")
let { getEnumValName } = require("%scripts/debugTools/dbgEnum.nut")
let { HUD_UNIT_TYPE } = require("%scripts/hud/hudUnitType.nut")
let { subscribe } = require("eventbus")

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
  bomb = BMS_OUT_OF_BOMBS
  rocket = BMS_OUT_OF_ROCKETS
  torpedo = BMS_OUT_OF_TORPEDOES
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
  lastHudUnitType = ""
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

  supportedMsgTypes = [
    HUD_MSG_MULTIPLAYER_DMG,
    HUD_MSG_STREAK_EX,
    HUD_MSG_STREAK,
    HUD_MSG_OBJECTIVE,
    HUD_MSG_DIALOG,
    HUD_MSG_DAMAGE,
    HUD_MSG_ENEMY_DAMAGE,
    HUD_MSG_ENEMY_CRITICAL_DAMAGE,
    HUD_MSG_ENEMY_FATAL_DAMAGE,
    HUD_MSG_DEATH_REASON,
    HUD_MSG_EVENT,
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

    this.gameType = ::get_game_type()
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

    this.gotRefereeRights = getTblValue("spectator", mplayerTable, 0) == 1
    this.mode = isReplay ? SPECTATOR_MODE.REPLAY : SPECTATOR_MODE.SKIRMISH
    this.isMultiplayer = !!(this.gameType & GT_VERSUS) || !!(this.gameType & GT_COOPERATIVE)
    this.canControlTimeline  = this.mode == SPECTATOR_MODE.REPLAY && getTblValue("timeSpeedAllowed", replayProps, false)
    this.canControlCameras   = this.mode == SPECTATOR_MODE.REPLAY || this.gotRefereeRights
    this.canSeeMissionTimer  = !this.canControlTimeline && this.mode == SPECTATOR_MODE.SKIRMISH
    this.canSeeOppositeTeam  = this.mode != SPECTATOR_MODE.RESPAWN
    this.canSendChatMessages = this.mode != SPECTATOR_MODE.REPLAY
    let canRewind = this.canControlTimeline && hasFeature("replayRewind")
    let anchors = get_replay_anchors()
    let curAnchorIdx = this.getCurAnchorIdx(anchors)

    this.fillTabs()
    this.historyLog = []

    this.loadGameChat()
    if (!this.isMultiplayer)
      ::showBtnTable(this.scene, {
          btn_tab_chat  = false
          target_stats  = false
      })

    let objReplayControls = this.scene.findObject("controls_div")
    ::showBtnTable(objReplayControls, {
        ID_FLIGHTMENU               = useTouchscreen
        ID_MPSTATSCREEN             = this.mode != SPECTATOR_MODE.REPLAY
        controls_mpstats_replays    = this.mode == SPECTATOR_MODE.REPLAY
        ID_PREV_PLANE               = true
        ID_NEXT_PLANE               = true
        controls_cameras_icon       = this.canControlCameras
        ID_CAMERA_DEFAULT           = this.canControlCameras
        ID_TOGGLE_FOLLOWING_CAMERA  = this.canControlCameras
        ID_REPLAY_CAMERA_OPERATOR   = this.canControlCameras
        ID_REPLAY_CAMERA_FLYBY      = this.canControlCameras
        ID_REPLAY_CAMERA_WING       = this.canControlCameras
        ID_REPLAY_CAMERA_GUN        = this.canControlCameras
        ID_REPLAY_CAMERA_RANDOMIZE  = this.canControlCameras
        ID_REPLAY_CAMERA_FREE       = this.canControlCameras
        ID_REPLAY_CAMERA_FREE_PARENTED = this.canControlCameras
        ID_REPLAY_CAMERA_FREE_ATTACHED = this.canControlCameras
        ID_REPLAY_CAMERA_HOVER      = this.canControlCameras
        ID_TOGGLE_FORCE_SPECTATOR_CAM_ROT = true
        ID_REPLAY_SHOW_MARKERS      = this.mode == SPECTATOR_MODE.REPLAY
        ID_REPLAY_SLOWER            = this.canControlTimeline
        ID_REPLAY_FASTER            = this.canControlTimeline
        ID_REPLAY_PAUSE             = this.canControlTimeline
        ID_REPLAY_BACKWARD          = canRewind
        ID_REPLAY_FORWARD           = canRewind
    })
    ::enableBtnTable(objReplayControls, {
        ID_PREV_PLANE               = this.mode != SPECTATOR_MODE.REPLAY || this.isMultiplayer
        ID_NEXT_PLANE               = this.mode != SPECTATOR_MODE.REPLAY || this.isMultiplayer
        ID_REPLAY_BACKWARD          = curAnchorIdx >= 0
        ID_REPLAY_FORWARD           = anchors.len() > 0 && (curAnchorIdx + 1) < anchors.len()
    })
    foreach(id, show in {
          txt_replay_time_speed       = this.canControlTimeline
          controls_timeline           = this.canControlTimeline
          controls_timer              = this.canSeeMissionTimer
        })
      this.scene.findObject(id).show(show)

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
          hotkeys = "<color=@hotkeyColor>" + loc("ui/parentheses/space", {text = hotkeys}) + "</color>"
        obj.tooltip = loc("hotkeys/" + obj.id) + hotkeys
      }
    }

    if (this.canControlCameras)
    {
      ::showBtnTable(this.scene, {
          ID_CAMERA_DEFAULT           = this.mode == SPECTATOR_MODE.REPLAY || this.gotRefereeRights
          ID_TOGGLE_FOLLOWING_CAMERA  = this.mode == SPECTATOR_MODE.REPLAY || this.gotRefereeRights
          ID_REPLAY_CAMERA_OPERATOR   = this.mode == SPECTATOR_MODE.REPLAY && !this.gotRefereeRights
          ID_REPLAY_CAMERA_FLYBY      = this.mode == SPECTATOR_MODE.REPLAY && !this.gotRefereeRights
          ID_REPLAY_CAMERA_WING       = this.mode == SPECTATOR_MODE.REPLAY && !this.gotRefereeRights
          ID_REPLAY_CAMERA_GUN        = this.mode == SPECTATOR_MODE.REPLAY && !this.gotRefereeRights
          ID_REPLAY_CAMERA_RANDOMIZE  = this.mode == SPECTATOR_MODE.REPLAY && !this.gotRefereeRights
          ID_REPLAY_CAMERA_FREE       = this.mode == SPECTATOR_MODE.REPLAY && !this.gotRefereeRights
          ID_REPLAY_CAMERA_FREE_PARENTED = this.mode == SPECTATOR_MODE.REPLAY && !this.gotRefereeRights
          ID_REPLAY_CAMERA_FREE_ATTACHED = this.mode == SPECTATOR_MODE.REPLAY && !this.gotRefereeRights
      })
    }

    if (this.mode == SPECTATOR_MODE.REPLAY)
    {
      let timeSpeeds = get_time_speeds_list()
      this.replayTimeSpeedMin = timeSpeeds[0]
      this.replayTimeSpeedMax = timeSpeeds[timeSpeeds.len() - 1]

      let info = ::current_replay.len() && get_replay_info(::current_replay)
      let comments = info && getTblValue("comments", info)
      if (comments)
      {
        this.replayAuthorUserId = getTblValue("authorUserId", comments, this.replayAuthorUserId)
        this.replayTimeTotal = getTblValue("timePlayed", comments, this.replayTimeTotal)
        this.scene.findObject("txt_replay_time_total").setValue(time.preciseSecondsToString(this.replayTimeTotal))
      }

      let replaySessionId = getTblValue("sessionId", replayProps, "")
      this.scene.findObject("txt_replay_session_id").setValue(replaySessionId)
    }

    this.funcSortPlayersSpectator = this.mpstatSortSpectator.bindenv(this)
    this.funcSortPlayersDefault   = ::mpstat_get_sort_func(this.gameType)

    ::g_hud_live_stats.init(this.scene, "spectator_live_stats_nest", false)
    this.actionBar = ::ActionBar(this.scene.findObject("spectator_hud_action_bar"))
    this.actionBar.reinit()
    if (!hasFeature("SpectatorUnitDmgIndicator"))
      this.scene.findObject("xray_render_dmg_indicator_spectator").show(false)
    this.reinitDmgIndicator()

    ::g_hud_event_manager.subscribe("HudMessage", function(eventData)
      {
        this.onHudMessage(eventData)
      }, this)

    this.onUpdate()
    this.scene.findObject("update_timer").setUserData(this)

    this.updateClientHudOffset()
    this.fillAnchorsMarkers()
  }

  function reinitScreen()
  {
    this.updateHistoryLog(true)
    this.loadGameChat()

    ::g_hud_live_stats.update()
    this.actionBar.reinit()
    this.reinitDmgIndicator()
    this.updateTarget(true)
  }

  function fillTabs()
  {
    let view = {
      tabs = []
    }
    foreach(tab in this.tabsList)
      view.tabs.append({
        tabName = loc(tab.locId)
        id = tab.id
        alert = "no"
        cornerImg = "#ui/gameuiskin#new_icon.svg"
        cornerImgId = "new_msgs"
        cornerImgTiny = true
      })

    let tabsObj = this.showSceneBtn("tabs", true)
    let data = ::handyman.renderCached("%gui/frameHeaderTabs.tpl", view)
    this.guiScene.replaceContentFromText(tabsObj, data, data.len(), this)
    tabsObj.setValue(0)
  }

  function loadGameChat()
  {
    if (this.isMultiplayer)
    {
      this.chatData = ::loadGameChatToObj(this.scene.findObject("chat_container"), "%gui/chat/gameChatSpectator.blk", this,
                                     {selfHideInput = true, hiddenInput = !this.canSendChatMessages })

      let objGameChat = this.scene.findObject("gamechat")
      ::showBtnTable(objGameChat, {
          chat_input_div         = this.canSendChatMessages
          chat_input_placeholder = this.canSendChatMessages
      })
      let objChatLogDiv = objGameChat.findObject("chat_log_tdiv")
      objChatLogDiv.size = this.canSendChatMessages ? objChatLogDiv.sizeWithInput : objChatLogDiv.sizeWithoutInput

      if (this.mode == SPECTATOR_MODE.SKIRMISH || this.mode == SPECTATOR_MODE.SUPERVISOR)
        ::chat_set_mode(CHAT_MODE_ALL, "")
    }
  }

  function onShowHud(_show = true, _needApplyPending = false)
  {
  }

  function onUpdate(_obj=null, dt=0.0)
  {
    if (!this.spectatorModeInited && ::is_in_flight())
    {
      if (!this.getTargetPlayer())
      {
        this.spectatorModeInited = true
        onSpectatorMode(true)
        this.catchingFirstTarget = this.isMultiplayer && this.gotRefereeRights
        log($"Spectator: init {getEnumValName("SPECTATOR_MODE", this.mode)}")
      }
      this.updateCooldown = 0.0
    }

    if (!checkObj(this.scene))
      return

    this.updateCooldown -= dt
    let isUpdateByCooldown = this.updateCooldown <= 0.0

    let targetNick  = getSpectatorTargetName()
    let hudUnitType = getHudUnitType()
    let isTargetSwitched = targetNick != this.lastTargetNick || hudUnitType != this.lastHudUnitType
    this.lastTargetNick  = targetNick
    this.lastHudUnitType = hudUnitType

    let friendlyTeam = ::get_player_army_for_hud()
    let friendlyTeamSwitched = friendlyTeam != this.lastFriendlyTeam
    this.lastFriendlyTeam = friendlyTeam

    if (isUpdateByCooldown || isTargetSwitched || friendlyTeamSwitched)
    {
      this.updateTarget(isTargetSwitched)
      this.updateStats()
    }

    if (friendlyTeamSwitched || isTargetSwitched)
    {
      ::g_hud_live_stats.show(this.isMultiplayer, null, spectatorWatchedHero.id)
      ::broadcastEvent("WatchedHeroSwitched")
      this.updateHistoryLog()
    }

    this.updateControls(isTargetSwitched)

    if (isUpdateByCooldown)
    {
      this.updateCooldown = 0.5

      // Forced switching target to catch the first target
      if (this.spectatorModeInited && this.catchingFirstTarget)
      {
        if (this.getTargetPlayer())
          this.catchingFirstTarget = false
        else
        {
          foreach (info in this.teams)
            foreach (p in info.players)
              if (p.state == PLAYER_IN_FLIGHT && !p.isDead)
              {
                this.switchTargetPlayer(p.id)
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
    if (this.mode == SPECTATOR_MODE.REPLAY && player?.realName != "")
      name = $"{name} ({player.realName})"
    return needColored ? colorize(this.getPlayerColor(player), name) : name
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
      !player.ingame ? loc(player.deaths ? "spectator/player_quit" : "multiplayer/state/player_not_in_game") :
      player.isDead ? loc(player.deaths ? "spectator/player_vehicle_lost" : "spectator/player_connecting") :
      !player.canBeSwitchedTo ? loc("multiplayer/state/player_in_game/location_unknown") : ""
  }

  function getUnitMalfunctionDesc(player)
  {
    if (!player || !player.ingame || player.isDead)
      return ""
    let briefMalfunctionState = getTblValue("briefMalfunctionState", player, 0)
    let list = []
    if (getTblValue("isExtinguisherActive", player, false))
      list.append(loc("fire_extinguished"))
    else if (getTblValue("isBurning", player, false))
      list.append(loc("fire_in_unit"))
    if (briefMalfunctionState & BMS_ENGINE_BROKEN)
      list.append(loc("my_dmg_msg/tank_engine"))
    if (briefMalfunctionState & BMS_MAIN_GUN_BROKEN)
      list.append(loc("my_dmg_msg/tank_gun_barrel"))
    if (briefMalfunctionState & BMS_TRACK_BROKEN)
      list.append(loc("my_dmg_msg/tank_track"))
    if (briefMalfunctionState & BMS_OUT_OF_AMMO)
      list.append(loc("controls/no_bullets_left"))
    if (briefMalfunctionState & BMS_OUT_OF_BOMBS)
      list.append(loc("controls/no_bombs_left"))
    if (briefMalfunctionState & BMS_OUT_OF_ROCKETS)
      list.append(loc("controls/no_rockets_left"))
    if (briefMalfunctionState & BMS_OUT_OF_TORPEDOES)
      list.append(loc("controls/no_torpedoes_left"))
    local desc = ::g_string.implode(list, loc("ui/semicolon"))
    if (desc.len())
      desc = colorize("warningTextColor", desc)
    return desc
  }

  function getPlayer(id)
  {
    foreach (info in this.teams)
      foreach (p in info.players)
        if (p.id == id)
          return p
    return null
  }

  function getPlayerByUserId(userId)
  {
    foreach (info in this.teams)
      foreach (p in info.players)
        if (p.userId == userId.tostring())
          return p
    return null
  }

  function getTargetPlayer()
  {
    if (!this.isMultiplayer)
      return (getSpectatorTargetName().len() && this.teams.len() && this.teams[0].players.len())
        ? this.teams[0].players[0]
        : null

    let targetId = getSpectatorTargetId()
    if (targetId >= 0)
      return this.getPlayer(targetId)

    return (this.mode == SPECTATOR_MODE.RESPAWN && this.lastTargetData.id >= 0)
      ? this.getPlayer(this.lastTargetData.id)
      : null
  }

  function setTargetInfo(player)
  {
    let infoObj = this.scene.findObject("target_info")
    let waitingObj = this.scene.findObject("waiting_for_target_spawn")
    if (!checkObj(infoObj) || !checkObj(waitingObj))
      return

    infoObj.show(player != null && this.isMultiplayer)
    waitingObj.show(player == null && this.catchingFirstTarget)

    if (!player || !this.isMultiplayer)
      return

    this.guiScene.setUpdatesEnabled(false, false)

    if (this.isMultiplayer)
    {
      let statusObj = infoObj.findObject("target_state")
      statusObj.setValue(this.getPlayerStateDesc(player))
    }

    this.guiScene.setUpdatesEnabled(true, true)
  }

  function updateTarget(targetSwitched = false, needFocusTargetTable = false)
  {
    let player = this.getTargetPlayer()

    if (targetSwitched)
    {
      spectatorWatchedHero.id      = player?.id ?? -1
      spectatorWatchedHero.squadId = player?.squadId ?? INVALID_SQUAD_ID
      spectatorWatchedHero.name    = player?.name ?? ""
    }

    local isFocused = false
    if (needFocusTargetTable)
      isFocused = this.selectTargetTeamBlock()

    ::g_hud_live_stats.show(this.isMultiplayer, null, spectatorWatchedHero.id)
    this.actionBar.reinit()
    this.reinitDmgIndicator()

    this.setTargetInfo(player)
    return isFocused
  }

  function updateControls(targetSwitched = false)
  {
    if (this.canControlTimeline)
    {
      if (::is_game_paused() != this.replayPaused)
      {
        this.replayPaused = ::is_game_paused()
        this.scene.findObject("ID_REPLAY_PAUSE").findObject("icon")["background-image"] = this.replayPaused ? "#ui/gameuiskin#replay_play.svg" : "#ui/gameuiskin#replay_pause.svg"
      }
      if (get_time_speed() != this.replayTimeSpeed)
      {
        this.replayTimeSpeed = get_time_speed()
        this.scene.findObject("txt_replay_time_speed").setValue(format("%.3fx", this.replayTimeSpeed))
        this.scene.findObject("ID_REPLAY_SLOWER").enable(this.replayTimeSpeed > this.replayTimeSpeedMin)
        this.scene.findObject("ID_REPLAY_FASTER").enable(this.replayTimeSpeed < this.replayTimeSpeedMax)
      }
      if (::is_replay_markers_enabled() != this.replayMarkersEnabled)
      {
        this.replayMarkersEnabled = ::is_replay_markers_enabled()
        this.scene.findObject("ID_REPLAY_SHOW_MARKERS").highlighted = this.replayMarkersEnabled ? "yes" : "no"
      }
      let replayTimeCurrent = ::get_usefull_total_time()
      this.scene.findObject("txt_replay_time_current").setValue(time.preciseSecondsToString(replayTimeCurrent))
      let progress = (this.replayTimeTotal > 0) ? (1000 * replayTimeCurrent / this.replayTimeTotal).tointeger() : 0
      if (progress != this.replayTimeProgress)
      {
        this.replayTimeProgress = progress
        this.scene.findObject("timeline_progress").setValue(this.replayTimeProgress)
      }

      if (hasFeature("replayRewind")) {
        let anchors = get_replay_anchors()
        let curAnchorIdx = this.getCurAnchorIdx(anchors)
        ::enableBtnTable(this.scene, {
          ID_REPLAY_BACKWARD          = curAnchorIdx >= 0
          ID_REPLAY_FORWARD           = anchors.len() > 0 && (curAnchorIdx + 1) < anchors.len()
        })
      }
    }

    if (this.canSeeMissionTimer)
    {
      this.scene.findObject("txt_mission_timer").setValue(time.secondsToString(::get_usefull_total_time(), false))
    }

    if (::is_spectator_rotation_forced() != this.cameraRotationByMouse)
    {
      this.cameraRotationByMouse = ::is_spectator_rotation_forced()
      this.scene.findObject("ID_TOGGLE_FORCE_SPECTATOR_CAM_ROT").highlighted = this.cameraRotationByMouse ? "yes" : "no"
    }

    if (this.canControlCameras && targetSwitched)
    {
      let player = this.getTargetPlayer()
      let isValid = player != null
      let isPlayer = player ? !player.isBot : false
      let userId   = player ? getTblValue("userId", player, 0) : 0
      let isAuthor = userId == this.replayAuthorUserId
      let isAuthorUnknown = this.replayAuthorUserId == -1
      let isAircraft = isInArray(this.lastHudUnitType,
        [HUD_UNIT_TYPE.AIRCRAFT, HUD_UNIT_TYPE.HELICOPTER])

      ::enableBtnTable(this.scene, {
          ID_CAMERA_DEFAULT           = isValid
          ID_TOGGLE_FOLLOWING_CAMERA  = isValid && isPlayer && (this.gotRefereeRights || isAuthor || isAuthorUnknown)
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
    let obj = this.scene.findObject("spectator_hud_damage")
    if (checkObj(obj))
      obj.show(this.getTargetPlayer() != null)
  }

  function statTblGetSelectedPlayer(obj)
  {
    let teamNum = ::getObjIdByPrefix(obj, "table_team")
    if (!teamNum || (teamNum != "1" && teamNum != "2"))
      return null
    let teamIndex = teamNum.tointeger() - 1
    let players =  this.teams[teamIndex].players
    let value = obj.getValue()
    if (value < 0 || value >= players.len())
      return null

    return players[value]
  }

  function onPlayerClick(obj)
  {
    if (this.ignoreUiInput)
      return

    this.selectPlayer(this.statTblGetSelectedPlayer(obj), obj)
  }

  function selectPlayer(player, _tableObj)
  {
    if (!player)
      return

    this.statSelPlayerId[this.teamIdToIndex(player.team)] = player.id
    this.switchTargetPlayer(player.id)
  }

  function onPlayerRClick(obj)
  {
    let player = this.statTblGetSelectedPlayer(obj)
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
    this.lastTargetData.team = this.teamIdToIndex(player.team)
    this.lastTargetData.id = player.id
  }

  function selectTargetTeamBlock()
  {
    let player = this.getTargetPlayer()
    if (!player)
      return false

    this.saveLastTargetPlayerData(player)
    this.statSelPlayerId[this.lastTargetData.team] = player.id

    let tblObj = this.getTeamTableObj(player.team)
    if (!tblObj)
      return false
    ::move_mouse_on_child_by_value(tblObj)
    return true
  }

  function selectControlsBlock(_obj)
  {
    if (::get_is_console_mode_enabled())
      this.selectTargetTeamBlock()
  }

  function onSelectPlayer(obj)
  {
    if (this.ignoreUiInput)
      return

    let player = this.statTblGetSelectedPlayer(obj)
    if (!player)
      return

    let curPlayer = this.getTargetPlayer()
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

    this.saveLastTargetPlayerData(player)
    this.selectPlayer(player, obj)
  }

  function onChangeFocusTable(obj)
  {
    this.lastSelectedTableId = obj.id
  }

  function onBtnMpStatScreen(_obj)
  {
    if (this.isMultiplayer)
      guiStartMPStatScreen()
    else
      ::gui_start_tactical_map()
  }

  function onBtnShortcut(obj)
  {
    let id = checkObj(obj) ? (obj?.id ?? "") : ""
    if (id.len() > 3 && id.slice(0, 3) == "ID_")
      toggleShortcut(id)
  }

  function onBtnCancelReplayDownload()
  {
    cancel_loading()
    this.scene.findObject("replay_paused_block").show(false)
  }

  function onMapClick(_obj = null)
  {
    let mapLargePanelObj = this.scene.findObject("map_large_div")
    if (!checkObj(mapLargePanelObj))
      return
    let mapLargeObj = mapLargePanelObj.findObject("tactical_map")
    if (!checkObj(mapLargeObj))
      return

    let toggle = !mapLargePanelObj.isVisible()
    mapLargePanelObj.show(toggle)
    mapLargeObj.show(toggle)
    mapLargeObj.enable(toggle)
  }

  function onToggleButtonClick(obj)
  {
    if (!checkObj(obj) || !("toggleObj" in obj))
      return
    let toggleObj = this.scene.findObject(obj?.toggleObj)
    if (!checkObj(toggleObj))
      return

    let toggle = !toggleObj.isVisible()
    toggleObj.show(toggle)
    obj.toggled = toggle ? "yes" : "no"

    this.updateHistoryLog(true)
    this.updateClientHudOffset()
  }

  function teamIdToIndex(teamId)
  {
    foreach (info in this.teams)
      if (info.teamId == teamId)
        return info.index
    return 0
  }

  function getTableObj(index)
  {
    let obj = this.scene.findObject($"table_team{index + 1}")
    return checkObj(obj) ? obj : null
  }

  function getTeamTableObj(teamId)
  {
    return this.getTableObj(this.teamIdToIndex(teamId))
  }

  function getTeamPlayers(teamId)
  {
    let tbl = (teamId != 0) ? ::get_mplayers_list(teamId, true) : [ ::get_local_mplayer() ]
    for (local i = tbl.len() - 1; i >= 0; i--)
    {
      let player = tbl[i]
      if (player.spectator
        || (this.mode == SPECTATOR_MODE.SKIRMISH
          && (player.state != PLAYER_IN_FLIGHT || player.isDead) && !player.deaths))
      {
        tbl.remove(i)
        continue
      }

      player.team = teamId
      player.ingame <- player.state == PLAYER_IN_FLIGHT || player.state == PLAYER_IN_RESPAWN
      player.isActing <- player.ingame
        && (!(this.gameType & GT_RACE) || player.raceFinishTime < 0)
        && (!(this.gameType & GT_LAST_MAN_STANDING) || player.deaths == 0)
      if (this.mode == SPECTATOR_MODE.REPLAY && !player.isBot)
        player.isBot = player.userId == "0" || getTblValue("invitedName", player) != null
      local unitId = (!player.isDead && player.state == PLAYER_IN_FLIGHT) ? player.aircraftName : null
      unitId = (unitId != "dummy_plane" && unitId != "") ? unitId : null
      player.aircraftName = unitId || ""
      player.canBeSwitchedTo = unitId ? player.canBeSwitchedTo : false
      player.isLocal = spectatorWatchedHero.id == player.id
      player.isInHeroSquad = ::SessionLobby.isEqualSquadId(spectatorWatchedHero.squadId, player?.squadId)
    }
    tbl.sort(this.funcSortPlayersSpectator)
    return tbl
  }

  function mpstatSortSpectator(a, b)
  {
    return b.isActing <=> a.isActing
      || (!a.isActing && this.funcSortPlayersDefault(a, b))
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
    let isMpMode = !!(this.gameType & GT_VERSUS) || !!(this.gameType & GT_COOPERATIVE)
    let isPvP = !!(this.gameType & GT_VERSUS)
    let isTeamplay = isPvP && ::is_mode_with_teams(this.gameType)

    if (isTeamplay || !this.canSeeOppositeTeam)
    {
      let localTeam = ::get_mp_local_team() != 2 ? 1 : 2
      let isMyTeamFriendly = localTeam == ::get_player_army_for_hud()

      for (local i = 0; i < 2; i++)
      {
        let teamId = ((i == 0) == (localTeam == 1)) ? Team.A : Team.B
        let color = ((i == 0) == isMyTeamFriendly)? "blue" : "red"
        let players = this.getTeamPlayers(teamId)

        _teams[i] = {
          active = true
          index = i
          teamId = teamId
          players = players
          color = color
          clanTag = this.getTeamClanTag(players)
        }
      }
    }
    else if (isMpMode)
    {
      let teamId = isTeamplay ? ::get_mp_local_team() : GET_MPLAYERS_LIST
      let color  = isTeamplay ? "blue" : "red"
      let players = this.getTeamPlayers(teamId)

      _teams[0] = {
        active = true
        index = 0
        teamId = teamId
        players = players
        color = color
        clanTag = isTeamplay ? this.getTeamClanTag(players) : ""
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
      let players = this.getTeamPlayers(teamId)

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
    this.statNumRows = min(maxNoScroll, length)
    return _teams
  }

  function updateStats()
  {
    let _teams = this.getPlayersData()
    foreach (idx, info in _teams)
    {
      let tblObj = this.getTableObj(info.index)
      if (tblObj)
      {
        let infoPrev = getTblValue(idx, this.teams)
        if (info.active)
          this.statTblUpdateInfo(tblObj, info, infoPrev)
        if (info.active != getTblValue("active", infoPrev, true))
        {
          tblObj.getParent().getParent().show(info.active)
          this.scene.findObject("btnToggleStats" + (idx + 1)).show(info.active)
        }
      }
    }
    this.teams = _teams
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
    let data = ::handyman.renderCached(("%gui/hud/spectatorTeamRow.tpl"), view)
    this.guiScene.appendWithBlk(objTbl, data, this)
    return totalRows
  }

  function isPlayerChanged(p1, p2)
  {
    if (this.debugMode)
      return true
    if (!p1 != !p2)
      return true
    if (!p1)
      return false
    foreach(param in this.scanPlayerParams)
      if (getTblValue(param, p1) != getTblValue(param, p2))
        return true
    return false
  }

  function statTblUpdateInfo(objTbl, teamInfo, infoPrev = null)
  {
    let players = getTblValue("players", teamInfo)
    if (!checkObj(objTbl) || !players)
      return

    this.guiScene.setUpdatesEnabled(false, false)

    let prevPlayers = getTblValue("players", infoPrev)
    let wasRows = this.addPlayerRows(objTbl, teamInfo)
    let totalRows = objTbl.childrenCount()

    let selPlayerId = getTblValue(teamInfo.index, this.statSelPlayerId)
    local selIndex = null

    let needClanTags = (teamInfo?.clanTag ?? "") == ""

    for(local i = 0; i < totalRows; i++)
    {
      let player = getTblValue(i, players)
      if (i < wasRows && !this.isPlayerChanged(player, getTblValue(i, prevPlayers)))
        continue

      let obj = objTbl.getChild(i)
      obj.show(player != null)
      if (!player)
        continue

      let nameObj = obj.findObject("name")
      if (!checkObj(nameObj)) //some validation
        continue

      let playerName = this.getPlayerNick(player)
      let playerNameShort = needClanTags ? playerName : this.getPlayerNick(player, false, false)
      nameObj.setValue(playerNameShort)

      let unitId = player.aircraftName != "" ? player.aircraftName : null
      let iconImg = !player.ingame ? "#ui/gameuiskin#player_not_ready.svg"
        : unitId ? ::getUnitClassIco(unitId)
        : "#ui/gameuiskin#dead.svg"
      let iconType = unitId ? getUnitRole(unitId) : ""
      let stateDesc = this.getPlayerStateDesc(player)
      let malfunctionDesc = this.getUnitMalfunctionDesc(player)

      obj.hero = player.isLocal ? "yes" : "no"
      obj.squad = player.isInHeroSquad ? "yes" : "no"
      obj.dead = player.canBeSwitchedTo ? "no" : "yes"
      obj.isBot = player.isBot ? "yes" : "no"
      obj.findObject("unit").setValue(::getUnitName(unitId || "dummy_plane"))
      obj.tooltip = playerName + (unitId ? loc("ui/parentheses/space", {text = ::getUnitName(unitId, false)}) : "")
        + (stateDesc != "" ? ("\n" + stateDesc) : "")
        + (malfunctionDesc != "" ? ("\n" + malfunctionDesc) : "")

      if (this.debugMode)
        obj.tooltip += "\n\n" + this.getPlayerDebugTooltipText(player)

      let unitIcoObj = obj.findObject("unit-ico")
      unitIcoObj["background-image"] = iconImg
      unitIcoObj.shopItemType = iconType

      let briefMalfunctionState = getTblValue("briefMalfunctionState", player, 0)
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
        getTblValue("isExtinguisherActive", player, false)  ? "ExtinguisherActive" :
        getTblValue("isBurning", player, false)             ? "IsBurning" :
        (briefMalfunctionState & BMS_ENGINE_BROKEN)         ? "BrokenEngine" :
        (briefMalfunctionState & BMS_MAIN_GUN_BROKEN)       ? "BrokenGun" :
        (briefMalfunctionState & BMS_TRACK_BROKEN)          ? "BrokenTrack" :
        (briefMalfunctionState & BMS_OUT_OF_AMMO)           ? "OutOfAmmo" :
                                                                ""
      obj.findObject("battle-state-ico")["class"] = battleStateIconClass

      if (player.id == selPlayerId)
        selIndex = i
    }

    if (selIndex != null && objTbl.getValue() != selIndex && objTbl.isFocused())
    {
      this.ignoreUiInput = true
      objTbl.setValue(selIndex)
      this.ignoreUiInput = false
    }

    if (objTbl.team != teamInfo.color)
      objTbl.team = teamInfo.color

    let headerObj = objTbl.getParent().getParent().findObject("header")
    if (checkObj(headerObj))
      headerObj.setValue(teamInfo.clanTag)

    this.guiScene.setUpdatesEnabled(true, true)
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
      let val = (i == "state") ? this.playerStateToString(v) : v
      extra.append(i + " = " + val)
    }
    extra.sort()
    return ::g_string.implode(extra, "\n")
  }

  function playerStateToString(state)
  {
    switch (state)
    {
      case PLAYER_NOT_EXISTS:                 return "PLAYER_NOT_EXISTS"
      case PLAYER_HAS_LEAVED_GAME:            return "PLAYER_HAS_LEAVED_GAME"
      case PLAYER_IN_LOBBY_NOT_READY:         return "PLAYER_IN_LOBBY_NOT_READY"
      case PLAYER_IN_LOADING:                 return "PLAYER_IN_LOADING"
      case PLAYER_IN_STATISTICS_BEFORE_LOBBY: return "PLAYER_IN_STATISTICS_BEFORE_LOBBY"
      case PLAYER_IN_LOBBY_READY:             return "PLAYER_IN_LOBBY_READY"
      case PLAYER_READY_TO_START:             return "PLAYER_READY_TO_START"
      case PLAYER_IN_FLIGHT:                  return "PLAYER_IN_FLIGHT"
      case PLAYER_IN_RESPAWN:                 return "PLAYER_IN_RESPAWN"
      default:                                  return "" + state
    }
  }

  function updateClientHudOffset()
  {
    this.guiScene.setUpdatesEnabled(true, true)
    let obj = this.scene.findObject("stats_left")
    ::spectator_air_hud_offset_x = (checkObj(obj) && obj.isVisible()) ? obj.getPos()[0] + obj.getSize()[0] : 0
  }

  function onBtnLogTabSwitch(obj)
  {
    if (!checkObj(obj))
      return

    let tabIdx = obj.getValue()
    if (tabIdx < 0 || tabIdx >= obj.childrenCount())
      return

    let tabObj = obj.getChild(tabIdx)
    let newTabId = tabObj?.id
    if (!newTabId || newTabId == this.curTabId)
      return

    foreach(tab in this.tabsList)
    {
      let objContainer = this.scene.findObject(tab.containerId)
      if (!checkObj(objContainer))
        continue

      objContainer.show(tab.id == newTabId)
    }
    this.curTabId = newTabId
    tabObj.findObject("new_msgs").show(false)

    ::g_orders.showOrdersContainer(this.curTabId == SPECTATOR_CHAT_TAB.ORDERS)

    if (this.curTabId == SPECTATOR_CHAT_TAB.CHAT)
      this.loadGameChat()
    this.updateHistoryLog(true)
  }

  function updateNewMsgImg(tabId)
  {
    if (!this.scene.isValid() || tabId == this.curTabId)
      return
    let obj = this.scene.findObject(tabId)
    if (checkObj(obj))
      obj.findObject("new_msgs").show(true)
  }

  function onEventMpChatLogUpdated(_params)
  {
    this.updateNewMsgImg(SPECTATOR_CHAT_TAB.CHAT)
  }

  function onEventActiveOrderChanged(_params)
  {
    this.updateNewMsgImg(SPECTATOR_CHAT_TAB.ORDERS)
  }

  function onEventMpChatInputRequested(params)
  {
    if (!checkObj(this.scene))
      return
    if (!this.canSendChatMessages)
      return

    local obj = this.scene.findObject("btnToggleLog")
    if (checkObj(obj) && obj?.toggled != "yes")
      this.onToggleButtonClick(obj)

    obj = this.scene.findObject("tabs")
    let chatTabId = SPECTATOR_CHAT_TAB.CHAT
    if (checkObj(obj) && this.curTabId != chatTabId)
      obj.setValue(this.tabsList.findindex(@(t) t.id == chatTabId) ?? -1)

    if (getTblValue("activate", params, false))
      ::game_chat_input_toggle_request(true)
  }

  function onEventReplayWait(event)
  {
    this.scene.findObject("replay_paused_block").show(event.isShow)

    let hasDownloadStatus = "dlCur" in event && "dlTotal" in event && "dlPercent" in event
    let downloadStatusString = event.isShow && hasDownloadStatus
      ? loc(
          "hints/replay_download_status",
          { downloadedMB = event.dlCur, totalMB = event.dlTotal, downloadedPercent = event.dlPercent }
        )
      : ""

    this.scene.findObject("replay_download_status").setValue(downloadStatusString)
  }

  function onPlayerRequestedArtillery(userId)
  {
    let player = this.getPlayerByUserId(userId)
    let color = this.isPlayerFriendly(player) ? "hudColorDarkBlue" : "hudColorDarkRed"
    this.addHistroyLogMessage(colorize(color, loc("artillery_strike/called_by_player", { player =  this.getPlayerNick(player, true) })))
  }

  function onHudMessage(msg)
  {
    if (!isInArray(msg.type, this.supportedMsgTypes))
      return

    if (!("id" in msg))
      msg.id <- -1
    if (!("text" in msg))
      msg.text <- ""

    msg.time <- ::get_usefull_total_time()

    this.historyLog = this.historyLog || []
    if (msg.id != -1)
      foreach (m in this.historyLog)
        if (m.id == msg.id)
          return
    if (msg.id == -1 && msg.text != "")
    {
      let skipDupTime = msg.time - this.historySkipDuplicatesSec
      for (local i = this.historyLog.len() - 1; i >= 0; i--)
      {
        if (this.historyLog[i].time < skipDupTime && msg.type != HUD_MSG_DEATH_REASON)
          break
        if (this.historyLog[i].text == msg.text)
          return
      }
    }

    msg.message <- this.buildHistoryLogMessage(msg)
    if (msg.message == "")
      return

    if (this.historyLog.len() == this.historyMaxLen)
      this.historyLog.remove(0)
    this.historyLog.append(msg)

    this.updateHistoryLog()
  }

  function addHistroyLogMessage(text)
  {
    this.onHudMessage({
      id   = -1
      text = text
      type = this.historyLogCustomMsgType
    })
  }

  function clearHistoryLog()
  {
    if (!this.historyLog)
      return
    this.historyLog.clear()
    this.updateHistoryLog()
  }

  function updateHistoryLog(updateVisibility = false)
  {
    if (!checkObj(this.scene))
      return

    let obj = this.scene.findObject("history_log")
    if (checkObj(obj))
    {
      if (updateVisibility)
        this.guiScene.setUpdatesEnabled(true, true)
      this.historyLog = this.historyLog || []

      foreach (msg in this.historyLog)
        msg.message <- this.buildHistoryLogMessage(msg)

      let historyLogMessages = u.map(this.historyLog, @(msg) msg.message)
      obj.setValue(obj.isVisible() ? ::g_string.implode(historyLogMessages, "\n") : "")
    }
  }

  function buildHistoryLogMessage(msg)
  {
    let timestamp = time.secondsToString(msg.time, false) + " "
    switch (msg.type)
    {
      // All players messages
      case HUD_MSG_MULTIPLAYER_DMG: // Any player or ai unit damaged or destroyed
        let text = ::HudBattleLog.msgMultiplayerDmgToText(msg)
        let icon = ::HudBattleLog.getActionTextIconic(msg)
        return timestamp + colorize("userlogColoredText", $"{icon} {text}")
        break

      case HUD_MSG_STREAK_EX: // Any player got streak
        let text = ::HudBattleLog.msgStreakToText(msg, true)
        return timestamp + colorize("streakTextColor", loc("unlocks/streak") + loc("ui/colon") + text)
        break

      // Mission objectives
      case HUD_MSG_OBJECTIVE: // Hero team mission objective
        let text = ::HudBattleLog.msgEscapeCodesToCssColors(msg.text)
        return timestamp + colorize("white", loc("sm_objective") + loc("ui/colon") + text)
        break

      // Team progress
      case HUD_MSG_DIALOG: // Hero team base capture events
        let text = ::HudBattleLog.msgEscapeCodesToCssColors(msg.text)
        return timestamp + colorize("commonTextColor", text)
        break

      // Hero (spectated target) messages
      case HUD_MSG_DAMAGE: // Hero air unit damaged
      case HUD_MSG_ENEMY_DAMAGE: // Hero target air unit damaged
      case HUD_MSG_ENEMY_CRITICAL_DAMAGE: // Hero target air unit damaged
      case HUD_MSG_ENEMY_FATAL_DAMAGE: // Hero target air unit damaged
      case HUD_MSG_DEATH_REASON: // Hero unit destroyed, killer name
      case HUD_MSG_EVENT: // Hero tank unit damaged, and some system messages
      case this.historyLogCustomMsgType: // Custom messages sent by script
        let text = ::HudBattleLog.msgEscapeCodesToCssColors(msg.text)
        return timestamp + colorize("commonTextColor", text)
        break
      default:
        return ""
    }
  }

  function setHotkeysToObjTooltips(scanObj, objects)
  {
    if (checkObj(scanObj))
      foreach (objId, keys in objects)
      {
        let obj = scanObj.findObject(objId)
        if (checkObj(obj))
        {
          local hotkeys = ""
          if ("shortcuts" in keys)
          {
            let shortcuts = ::get_shortcuts(keys.shortcuts)
            let locNames = []
            foreach (idx, _data in shortcuts)
            {
              let shortcutsText = ::get_shortcut_text({
                shortcuts = shortcuts,
                shortcutId = idx,
                strip_tags = true
              })
              if (shortcutsText != "")
                locNames.append(shortcutsText)
            }
            hotkeys = ::g_string.implode(locNames, loc("ui/comma"))
          }
          else if ("keys" in keys)
          {
            let keysLocalized = u.map(keys.keys, loc)
            hotkeys = ::g_string.implode(keysLocalized, loc("ui/comma"))
          }

          if (hotkeys != "")
          {
            let tooltip = obj?.tooltip ?? ""
            let add = "<color=@hotkeyColor>" + loc("ui/parentheses/space", {text = hotkeys}) + "</color>"
            obj.tooltip = tooltip + add
          }
        }
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
    let nextIdx = this.getCurAnchorIdx(anchors) + directionIdx
    if (nextIdx < 0 || nextIdx >= anchors.len())
      return
    move_to_anchor(nextIdx)
  }

  onBtnBackward = @() this.moveToNextAnchor(-1)
  onBtnForward  = @() this.moveToNextAnchor(1)
  onAnchorMarkerClick = @(obj) move_to_anchor(obj.id.tointeger())

  function fillAnchorsMarkers() {
    if (!this.canControlTimeline || !hasFeature("replayRewind"))
      return
    let anchors = get_replay_anchors()
    if (anchors.len() == 0 || this.replayTimeTotal <= 0)
      return

    let timeTotal = this.replayTimeTotal
    let data = ::handyman.renderCached("%gui/replays/replayAnchorMark.tpl", {
      anchors = anchors.map(function(v, idx) {
        let anchorTimeS = v/1000.0
        return {
          idx
          posX = $"{anchorTimeS/timeTotal}pw - 2@dp"
          tooltip = loc("replay/move_to_time", {
            time = time.preciseSecondsToString(anchorTimeS) })
        }
      })
    })
    this.guiScene.replaceContentFromText(this.scene.findObject("timeline_progress"),
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
  return !!getTblValue("spectator", ::get_local_mplayer() || {}, 0)
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

subscribe("replayWait", function (event) {
  ::broadcastEvent("ReplayWait", event)
})