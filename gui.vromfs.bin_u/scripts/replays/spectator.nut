from "%scripts/dagui_natives.nut" import is_replay_markers_enabled, get_player_army_for_hud, is_game_paused, mpstat_get_sort_func, is_spectator_rotation_forced
from "app" import is_dev_version
from "%scripts/dagui_library.nut" import *
from "hudMessages" import *
from "%scripts/teamsConsts.nut" import Team

let { g_hud_live_stats } = require("%scripts/hud/hudLiveStats.nut")
let { HudBattleLog } = require("%scripts/hud/hudBattleLog.nut")
let { g_hud_event_manager } = require("%scripts/hud/hudEventManager.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { isSensorViewMode, setSensorViewFilter, getSensorViewFilter,
  SVF_HERO, SVF_SQUAD, SVF_ALLY, SVF_ENEMY, SVF_GROUND, SVF_AIR, SVF_WEAPON_OTHER, SVF_WEAPON_HERO, SVF_WEAPON_ATTACK_HERO,
  SVF_RKT_SPEED, SVF_RKT_LIFETIME, SVF_RKT_TRAVELED, SVF_RKT_OVERLOAD, SVF_RKT_AOA, SVF_DEAD,
  SVF_RKT_STATE, SVF_SENSOR_HERO, SVF_SENSOR_SQUAD, SVF_SENSOR_ALLY, SVF_SENSOR_ENEMY, SVF_SENSOR_TRACK, SVF_SENSOR_INTEREST
  /*MEASURE_UNIT_SPEED, MEASURE_UNIT_DIST, getSensorMeasures, setSensorMeasures*/
} = require("camera_control")
let { INVALID_SQUAD_ID } = require("matching.errors")
let { getObjValidIndex, enableObjsByTable } = require("%sqDagui/daguiUtil.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { registerPersistentData } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")
let { format } = require("string")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { move_mouse_on_child_by_value, handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { CHAT_MODE_ALL, chat_set_mode, toggle_ingame_chat } = require("chat")
let u = require("%sqStdLibs/helpers/u.nut")
let time = require("%scripts/time.nut")
let spectatorWatchedHero = require("%scripts/replays/spectatorWatchedHero.nut")
let replayMetadata = require("%scripts/replays/replayMetadata.nut")
let { getUnitRole } = require("%scripts/unit/unitInfoTexts.nut")
let { getPlayerName } = require("%scripts/user/remapNick.nut")
let { useTouchscreen } = require("%scripts/clientState/touchScreen.nut")
let { toggleShortcut } = require("%globalScripts/controls/shortcutActions.nut")
let { getHudUnitType } = require("hudState")
let { guiStartMPStatScreen, getWeaponTypeIcoByWeapon
} = require("%scripts/statistics/mpStatisticsUtil.nut")
let { onSpectatorMode, switchSpectatorTargetById,
  getSpectatorTargetId, getSpectatorTargetName
} = require("guiSpectator")
let { get_time_speeds_list, get_time_speed, is_replay_playing, get_replay_anchors,
  get_replay_info, get_replay_props, move_to_anchor, cancel_loading } = require("replays")
let { getEnumValName } = require("%scripts/debugTools/dbgEnum.nut")
let { HUD_UNIT_TYPE } = require("%scripts/hud/hudUnitType.nut")
let { eventbus_send, eventbus_subscribe } = require("eventbus")
let { get_game_type, get_mission_time, get_mplayers_list, get_local_mplayer, get_mp_local_team } = require("mission")
let { round_by_value } = require("%sqstd/math.nut")
let { getFromSettingsBlk } = require("%scripts/clientState/clientStates.nut")
let { getUnitName } = require("%scripts/unit/unitInfo.nut")
let { ActionBar } = require("%scripts/hud/hudActionBar.nut")
let { isInFlight } = require("gameplayBinding")
let { isInSessionRoom } = require("%scripts/matchingRooms/sessionLobbyState.nut")
let { updateActionBar } = require("%scripts/hud/actionBarState.nut")
let { gui_start_mainmenu } = require("%scripts/mainmenu/guiStartMainmenu.nut")
let { gui_start_tactical_map } = require("%scripts/tacticalMap.nut")
let { showOrdersContainer } = require("%scripts/items/orders.nut")
let { getLogForBanhammer } = require("%scripts/chat/mpChatModel.nut")
let { loadGameChatToObj } = require("%scripts/chat/mpChat.nut")

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

local spectator_air_hud_offset_x = 0
let playerStateToStringMap = {
  [PLAYER_NOT_EXISTS] = "PLAYER_NOT_EXISTS",
  [PLAYER_HAS_LEAVED_GAME] = "PLAYER_HAS_LEAVED_GAME",
  [PLAYER_IN_LOBBY_NOT_READY]  ="PLAYER_IN_LOBBY_NOT_READY",
  [PLAYER_IN_LOADING]  ="PLAYER_IN_LOADING",
  [PLAYER_IN_STATISTICS_BEFORE_LOBBY] = "PLAYER_IN_STATISTICS_BEFORE_LOBBY",
  [PLAYER_IN_LOBBY_READY] = "PLAYER_IN_LOBBY_READY",
  [PLAYER_READY_TO_START] = "PLAYER_READY_TO_START",
  [PLAYER_IN_FLIGHT] = "PLAYER_IN_FLIGHT",
  [PLAYER_IN_RESPAWN] = "PLAYER_IN_RESPAWN"
}

let hudHeroMessages = {
  [HUD_MSG_DAMAGE] = true, // Hero air unit damaged
  [HUD_MSG_ENEMY_DAMAGE] = true, // Hero target air unit damaged
  [HUD_MSG_ENEMY_CRITICAL_DAMAGE] = true, // Hero target air unit damaged
  [HUD_MSG_ENEMY_FATAL_DAMAGE] = true, // Hero target air unit damaged
  [HUD_MSG_DEATH_REASON] = true, // Hero unit destroyed, killer name
  [HUD_MSG_EVENT] = true, // Hero tank unit damaged, and some system messages
}

let supportedMsgTypes = {
  [HUD_MSG_MULTIPLAYER_DMG] = true,
  [HUD_MSG_STREAK_EX] = true,
  [HUD_MSG_STREAK] = true,
  [HUD_MSG_OBJECTIVE] = true,
  [HUD_MSG_DIALOG] = true,
  [HUD_MSG_DAMAGE] = true,
  [HUD_MSG_ENEMY_DAMAGE] = true,
  [HUD_MSG_ENEMY_CRITICAL_DAMAGE] = true,
  [HUD_MSG_ENEMY_FATAL_DAMAGE] = true,
  [HUD_MSG_DEATH_REASON] = true,
  [HUD_MSG_EVENT] = true,
  [-200] = true // historyLogCustomMsgType
}

let sensorFiltersTable = {
  items = [
    {iconText = "#icon/mpstats/raceLastCheckpoint", tooltip = "#sensorsFilters/unitMarkers", selected = "yes"}
    {imgBg = "#ui/gameuiskin#btn_autodetect_on.svg", tooltip = "#sensorsFilters/sensorMapping"}
    // uncomment when complete part in native code
    //{imgBg = "#ui/gameuiskin#icon_range.svg", tooltip = "#sensorsFilters/measurement"}
    {imgBg = "#ui/gameuiskin#icon_rocket_in_progress.svg", tooltip = "#sensorsFilters/rktFlyMarkers"}
  ]
  pages = [
    {
      id = "unitMarkers"
      label = "sensorsFilters/unitMarkers"
      options = [
        {optName = "#options/player", switchBox = { fid = SVF_HERO, makeValue = @()getSensorViewFilter(SVF_HERO) ? "yes" : "no" } }
        {optName = "#sensorsFilters/squad", switchBox = { fid = SVF_SQUAD, makeValue = @()getSensorViewFilter(SVF_SQUAD) ? "yes" : "no"  } }
        {optName = "#sensorsFilters/allyes", switchBox = { fid = SVF_ALLY, makeValue = @()getSensorViewFilter(SVF_ALLY) ? "yes" : "no"  } }
        {optName = "#sensorsFilters/enemyes", switchBox = { fid = SVF_ENEMY, makeValue = @()getSensorViewFilter(SVF_ENEMY) ? "yes" : "no"  } }
        {optName = "#ground_targets/name/short", switchBox = { fid = SVF_GROUND, makeValue = @()getSensorViewFilter(SVF_GROUND) ? "yes" : "no"  } }
        {optName = "#air_targets/name/short", switchBox = { fid = SVF_AIR, makeValue = @()getSensorViewFilter(SVF_AIR) ? "yes" : "no"  } }
        {optName = "#sensorsFilters/dead", switchBox = { fid = SVF_DEAD, makeValue = @()getSensorViewFilter(SVF_DEAD) ? "yes" : "no"  } }
        {optName = "#sensorsFilters/allWeapons", switchBox = { fid = SVF_WEAPON_OTHER, makeValue = @()getSensorViewFilter(SVF_WEAPON_OTHER) ? "yes" : "no"  } }
        {optName = "#sensorsFilters/playerWeapons", switchBox = { fid = SVF_WEAPON_HERO, makeValue = @()getSensorViewFilter(SVF_WEAPON_HERO) ? "yes" : "no"  } }
        {optName = "#sensorsFilters/enemyWeapons", switchBox = { fid = SVF_WEAPON_ATTACK_HERO, makeValue = @()getSensorViewFilter(SVF_WEAPON_ATTACK_HERO) ? "yes" : "no"  } }
      ]
    },
    {
      id = "sensorsWork"
      label = "sensorsFilters/sensorMapping"
      options = [
        {optName = "#options/player", switchBox = {fid = SVF_SENSOR_HERO, makeValue = @()getSensorViewFilter(SVF_SENSOR_HERO) ? "yes" : "no"  }}
        {optName = "#sensorsFilters/squad", switchBox = {fid = SVF_SENSOR_SQUAD, makeValue = @()getSensorViewFilter(SVF_SENSOR_SQUAD) ? "yes" : "no"  }}
        {optName = "#sensorsFilters/allyes", switchBox = {fid = SVF_SENSOR_ALLY, makeValue = @()getSensorViewFilter(SVF_SENSOR_ALLY) ? "yes" : "no"  }}
        {optName = "#sensorsFilters/enemyes", switchBox = {fid = SVF_SENSOR_ENEMY, makeValue = @()getSensorViewFilter(SVF_SENSOR_ENEMY) ? "yes" : "no"  }}
        {optName = "#sensorsFilters/track_sensor", switchBox = {fid = SVF_SENSOR_TRACK, makeValue = @()getSensorViewFilter(SVF_SENSOR_TRACK) ? "yes" : "no"  }}
        {optName = "#sensorsFilters/sensor_interest", switchBox = {fid = SVF_SENSOR_INTEREST, makeValue = @()getSensorViewFilter(SVF_SENSOR_INTEREST) ? "yes" : "no"  }}
      ]
    },
    // uncomment when complete part in native code
    /*
    {
      id = "sensorsMeasures"
      label = "sensorsFilters/measurement"
      options = [
        {
          optName = "#sensorsFilters/rangeDist",
          comboBox = {
            measureType = MEASURE_UNIT_DIST,
            makeValue = @() getSensorMeasures(SENSOR_MEASURES.UNIT_DIST),
            id = "distMeasures"
            measures = [
              {label = "#measureUnits/km_dist"},
              {label = "#measureUnits/meters_dist"},
              {label = "#measureUnits/mile_dist"},
              {label = "#measureUnits/yard_dist"},
              {label = "#measureUnits/feet_dist"}
            ]
          }
        },
        {
          optName = "#options/measure_units_speed",
          comboBox = {
            makeValue = @() getSensorMeasures(SENSOR_MEASURES.UNIT_SPEED),
            id = "speedMeasures"
            measureType = MEASURE_UNIT_SPEED,
            measures = [
              {label = "#measureUnits/kmh"},
              {label = "#measureUnits/metersPerSecond_climbSpeed"},
              {label = "#measureUnits/kt"},
            ]
          }
        }
      ]
    },*/
    {
      id = "rocketMarkers"
      label = "sensorsFilters/rktFlyMarkers"
      options = [
        {optName = "#options/measure_units_speed", switchBox = { fid = SVF_RKT_SPEED, makeValue = @()getSensorViewFilter(SVF_RKT_SPEED) ? "yes" : "no"  } }
        {optName = "#sensorsFilters/rktLifetime", switchBox = { fid = SVF_RKT_LIFETIME, makeValue = @()getSensorViewFilter(SVF_RKT_LIFETIME) ? "yes" : "no"  } }
        {optName = "#sensorsFilters/rktTraveled", switchBox = { fid = SVF_RKT_TRAVELED, makeValue = @()getSensorViewFilter(SVF_RKT_TRAVELED) ? "yes" : "no"  } }
        {optName = "#sensorsFilters/rktOverload", switchBox = { fid = SVF_RKT_OVERLOAD, makeValue = @()getSensorViewFilter(SVF_RKT_OVERLOAD) ? "yes" : "no"  } }
        {optName = "#sensorsFilters/rktAttackAngle", switchBox = { fid = SVF_RKT_AOA, makeValue = @()getSensorViewFilter(SVF_RKT_AOA) ? "yes" : "no"  } }
        {optName = "#sensorsFilters/rktStateOfSeeker", switchBox = { fid = SVF_RKT_STATE, makeValue = @()getSensorViewFilter(SVF_RKT_STATE) ? "yes" : "no"  } }
      ]
    }
  ]
}

let class Spectator (gui_handlers.BaseGuiHandlerWT) {
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

  isSensorViewModeEnabled = false
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

  widgetsList = [{
    widgetId = DargWidgets.DAMAGE_PANEL
  }]

  function initScreen() {
    registerPersistentData("Spectator", this, [ "debugMode" ])

    this.gameType = get_game_type()
    let mplayerTable = get_local_mplayer() || {}
    let isReplay = is_replay_playing()
    let replayProps = get_replay_props()

    if (isReplay) {
      // Trying to restore some missing data when replay is started via command-line or browser link
      ::back_from_replays = ::back_from_replays || gui_start_mainmenu
      ::current_replay = ::current_replay.len() ? ::current_replay : getFromSettingsBlk("viewReplay", "")

      // Trying to restore some SessionLobby data
      replayMetadata.restoreReplayScriptCommentsBlk(::current_replay)
    }

    this.gotRefereeRights = (mplayerTable?.spectator ?? 0) == 1
    this.mode = isReplay ? SPECTATOR_MODE.REPLAY : SPECTATOR_MODE.SKIRMISH
    this.isMultiplayer = !!(this.gameType & GT_VERSUS) || !!(this.gameType & GT_COOPERATIVE)
    this.canControlTimeline  = this.mode == SPECTATOR_MODE.REPLAY && (replayProps?.timeSpeedAllowed ?? false)
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
      showObjectsByTable(this.scene, {
          btn_tab_chat  = false
          target_stats  = false
      })

    let objReplayControls = this.scene.findObject("controls_div")
    showObjectsByTable(objReplayControls, {
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
        ID_REPLAY_TOGGLE_SENSOR_VIEW  = this.mode == SPECTATOR_MODE.REPLAY
        ID_REPLAY_SLOWER            = this.canControlTimeline
        ID_REPLAY_FASTER            = this.canControlTimeline
        ID_REPLAY_PAUSE             = this.canControlTimeline
        ID_REPLAY_BACKWARD          = canRewind
        ID_REPLAY_FORWARD           = canRewind
    })
    enableObjsByTable(objReplayControls, {
        ID_PREV_PLANE               = this.mode != SPECTATOR_MODE.REPLAY || this.isMultiplayer
        ID_NEXT_PLANE               = this.mode != SPECTATOR_MODE.REPLAY || this.isMultiplayer
        ID_REPLAY_BACKWARD          = curAnchorIdx >= 0
        ID_REPLAY_FORWARD           = anchors.len() > 0 && (curAnchorIdx + 1) < anchors.len()
    })
    foreach (id, show in {
          txt_replay_time_speed       = this.canControlTimeline
          controls_timeline           = this.canControlTimeline
          controls_timer              = this.canSeeMissionTimer
        })
      this.scene.findObject(id).show(show)

    for (local i = 0; i < objReplayControls.childrenCount(); i++) {
      let obj = objReplayControls.getChild(i)
      if (obj?.is_shortcut && obj?.id) {
        local hotkeys = ::get_shortcut_text({
          shortcuts = ::get_shortcuts([ obj.id ])
          shortcutId = 0
          cantBeEmpty = false
          strip_tags = true
        })
        if (hotkeys.len())
          hotkeys = "".concat("<color=@hotkeyColor>", loc("ui/parentheses/space", { text = hotkeys }), "</color>")
        obj.tooltip = "".concat(loc($"hotkeys/{obj.id}"), hotkeys)
      }
    }

    if (this.canControlCameras) {
      showObjectsByTable(this.scene, {
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

    if (this.mode == SPECTATOR_MODE.REPLAY) {
      let timeSpeeds = get_time_speeds_list()
      this.replayTimeSpeedMin = timeSpeeds[0]
      this.replayTimeSpeedMax = timeSpeeds[timeSpeeds.len() - 1]

      let info = ::current_replay.len() && get_replay_info(::current_replay)
      let comments = info?.comments
      if (comments) {
        this.replayAuthorUserId = comments?.authorUserId ?? this.replayAuthorUserId
        this.replayTimeTotal = comments?.timePlayed ?? this.replayTimeTotal
        this.scene.findObject("txt_replay_time_total").setValue(time.preciseSecondsToString(this.replayTimeTotal))
      }

      let replaySessionId = replayProps?.sessionId ?? ""
      this.scene.findObject("txt_replay_session_id").setValue(replaySessionId)
    }

    this.funcSortPlayersSpectator = this.mpstatSortSpectator.bindenv(this)
    this.funcSortPlayersDefault   = mpstat_get_sort_func(this.gameType)

    g_hud_live_stats.init(this.scene, "spectator_live_stats_nest", false)
    this.actionBar = ActionBar(this.scene.findObject("spectator_hud_action_bar"))
    this.actionBar.reinit()
    this.reinitDmgIndicator()

    g_hud_event_manager.subscribe("HudMessage", function(eventData) {
        this.onHudMessage(eventData)
      }, this)

    this.onUpdate()
    this.scene.findObject("update_timer").setUserData(this)

    this.updateClientHudOffset()
    this.fillAnchorsMarkers()

    let data = handyman.renderCached("%gui/replays/sensorFilterOptions.tpl", sensorFiltersTable)

    this.guiScene.replaceContentFromText(this.scene.findObject("sensorsFiltersNest"), data, data.len(), this)
    this.scene.findObject("filtersButtons")?.setValue(0)

    foreach (page in sensorFiltersTable.pages) {
      if (!page?.options)
        continue
      foreach ( option in page.options ) {
        if (option?.comboBox?.makeValue)
          this.scene.findObject(option.comboBox.id)?.setValue(option.comboBox.makeValue())
      }
    }
  }

  function onSensorFilterPageSelect(obj) {
    this.selectSensorFilterPageByIndex(obj.getValue())
  }

  function selectSensorFilterPageByIndex(selectIndex) {
    let pages = sensorFiltersTable.pages

    foreach (pageIndex, page in pages) {
       showObjById(page.id, selectIndex == pageIndex, this.scene)
       if (selectIndex == pageIndex)
         this.scene.findObject("sensorsFiltersLabel")?.setValue(loc(page.label))
    }
  }

  function doFilterChange(obj) {
    setSensorViewFilter( obj.filterId.tointeger(), obj.getValue())
  }

  // uncomment when complete part in native code
  /*
  function onSensorMeasureSelect(obj) {
    setSensorMeasures(obj.getValue(), obj?.measureType.tointeger())
  }
  */

  function reinitScreen() {
    this.updateHistoryLog(true)
    this.loadGameChat()

    g_hud_live_stats.update()
    this.actionBar.reinit()
    this.reinitDmgIndicator()
    this.updateTarget(true)
  }

  function fillTabs() {
    let view = {
      tabs = []
    }
    foreach (tab in this.tabsList)
      view.tabs.append({
        tabName = loc(tab.locId)
        id = tab.id
        alert = "no"
        cornerImg = "#ui/gameuiskin#new_icon.svg"
        cornerImgId = "new_msgs"
        cornerImgTiny = true
      })

    let tabsObj = showObjById("tabs", true, this.scene)
    let data = handyman.renderCached("%gui/frameHeaderTabs.tpl", view)
    this.guiScene.replaceContentFromText(tabsObj, data, data.len(), this)
    tabsObj.setValue(0)
  }

  function loadGameChat() {
    if (this.isMultiplayer) {
      this.chatData = loadGameChatToObj(this.scene.findObject("chat_container"), "%gui/chat/gameChatSpectator.blk", this,
                                     { selfHideInput = true, hiddenInput = !this.canSendChatMessages })

      let objGameChat = this.scene.findObject("gamechat")
      showObjectsByTable(objGameChat, {
          chat_input_div         = this.canSendChatMessages
          chat_input_placeholder = this.canSendChatMessages
      })
      let objChatLogDiv = objGameChat.findObject("chat_log_tdiv")
      objChatLogDiv.size = this.canSendChatMessages ? objChatLogDiv.sizeWithInput : objChatLogDiv.sizeWithoutInput

      if (this.mode == SPECTATOR_MODE.SKIRMISH || this.mode == SPECTATOR_MODE.SUPERVISOR)
        chat_set_mode(CHAT_MODE_ALL, "")
    }
  }

  function onShowHud(_show = true, _needApplyPending = false) {
  }

  function onUpdate(_obj = null, dt = 0.0) {
    if (!this.spectatorModeInited && isInFlight()) {
      if (!this.getTargetPlayer()) {
        this.spectatorModeInited = true
        onSpectatorMode(true)
        this.catchingFirstTarget = this.isMultiplayer && this.gotRefereeRights
        log($"Spectator: init {getEnumValName("SPECTATOR_MODE", SPECTATOR_MODE, this.mode)}")
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

    let friendlyTeam = get_player_army_for_hud()
    let friendlyTeamSwitched = friendlyTeam != this.lastFriendlyTeam
    this.lastFriendlyTeam = friendlyTeam

    if (isUpdateByCooldown) {
      this.updateStats()
    }

    if (isTargetSwitched || friendlyTeamSwitched) {
      this.updateTarget(isTargetSwitched)
    }

    if (friendlyTeamSwitched || isTargetSwitched) {
      g_hud_live_stats.show(this.isMultiplayer, null, spectatorWatchedHero.id)
      broadcastEvent("WatchedHeroSwitched")
      this.updateHistoryLog()
    }

    this.updateControls(isTargetSwitched)

    if (isUpdateByCooldown) {
      this.updateCooldown = 0.5

      // Forced switching target to catch the first target
      if (this.spectatorModeInited && this.catchingFirstTarget) {
        if (this.getTargetPlayer())
          this.catchingFirstTarget = false
        else {
          foreach (info in this.teams)
            foreach (p in info.players)
              if (p.state == PLAYER_IN_FLIGHT && !p.isDead) {
                this.switchTargetPlayer(p.id)
                break
              }
        }
      }
    }
  }

  function isPlayerFriendly(player) {
    return player != null && player.team == get_player_army_for_hud()
  }

  function getPlayerNick(player, needColored = false, needClanTag = true) {
    if (player == null)
      return  ""
    local name = ::g_contacts.getPlayerFullName(
      getPlayerName(player.name), // can add platform icon
      needClanTag && !player.isBot ? player.clanTag : "")
    if (this.mode == SPECTATOR_MODE.REPLAY && player?.realName != "")
      name = $"{name} ({player.realName})"
    return needColored ? colorize(this.getPlayerColor(player), name) : name
  }

  function getPlayerColor(player) {
    return player.isLocal ? "hudColorHero"
    : player.isInHeroSquad ? "hudColorSquad"
    : player.team == get_player_army_for_hud() ? "hudColorBlue"
    : "hudColorRed"
  }

  function getPlayerStateDesc(player) {
    return !player ? "" :
      !player.ingame ? loc(player.deaths ? "spectator/player_quit" : "multiplayer/state/player_not_in_game") :
      player.isDead ? loc(player.deaths ? "spectator/player_vehicle_lost" : "spectator/player_connecting") :
      !player.canBeSwitchedTo ? loc("multiplayer/state/player_in_game/location_unknown") : ""
  }

  function getUnitMalfunctionDesc(player) {
    if (!player || !player.ingame || player.isDead)
      return ""
    let briefMalfunctionState = player?.briefMalfunctionState ?? 0
    let list = []
    if (player?.isExtinguisherActive ?? false)
      list.append(loc("fire_extinguished"))
    else if (player?.isBurning ?? false)
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
    local desc = loc("ui/semicolon").join(list, true)
    if (desc.len())
      desc = colorize("warningTextColor", desc)
    return desc
  }

  function getPlayer(id) {
    foreach (info in this.teams)
      foreach (p in info.players)
        if (p.id == id)
          return p
    return null
  }

  function getPlayerByUserId(userId) {
    foreach (info in this.teams)
      foreach (p in info.players)
        if (p.userId == userId.tostring())
          return p
    return null
  }

  function getTargetPlayer() {
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

  function setTargetInfo(player) {
    let infoObj = this.scene.findObject("target_info")
    let waitingObj = this.scene.findObject("waiting_for_target_spawn")
    if (!checkObj(infoObj) || !checkObj(waitingObj))
      return

    infoObj.show(player != null && this.isMultiplayer)
    waitingObj.show(player == null && this.catchingFirstTarget)

    if (!player || !this.isMultiplayer)
      return

    this.guiScene.setUpdatesEnabled(false, false)

    if (this.isMultiplayer) {
      let statusObj = infoObj.findObject("target_state")
      statusObj.setValue(this.getPlayerStateDesc(player))
    }

    this.guiScene.setUpdatesEnabled(true, true)
  }

  function updateTarget(targetSwitched = false, needFocusTargetTable = false) {
    let player = this.getTargetPlayer()

    if (targetSwitched) {
      spectatorWatchedHero.id      = player?.id ?? -1
      spectatorWatchedHero.squadId = player?.squadId ?? INVALID_SQUAD_ID
      spectatorWatchedHero.name    = player?.name ?? ""
    }

    local isFocused = false
    if (needFocusTargetTable)
      isFocused = this.selectTargetTeamBlock()

    g_hud_live_stats.show(this.isMultiplayer, null, spectatorWatchedHero.id)
    updateActionBar()
    this.reinitDmgIndicator()

    this.setTargetInfo(player)
    return isFocused
  }

  function updateControls(targetSwitched = false) {
    if (this.canControlTimeline) {
      if (is_game_paused() != this.replayPaused) {
        this.replayPaused = is_game_paused()
        this.scene.findObject("ID_REPLAY_PAUSE").findObject("icon")["background-image"] = this.replayPaused ? "#ui/gameuiskin#replay_play.svg" : "#ui/gameuiskin#replay_pause.svg"
      }
      if (get_time_speed() != this.replayTimeSpeed) {
        this.replayTimeSpeed = get_time_speed()
        this.scene.findObject("txt_replay_time_speed").setValue(format("%.3fx", this.replayTimeSpeed))
        this.scene.findObject("ID_REPLAY_SLOWER").enable(this.replayTimeSpeed > this.replayTimeSpeedMin)
        this.scene.findObject("ID_REPLAY_FASTER").enable(this.replayTimeSpeed < this.replayTimeSpeedMax)
      }
      if (is_replay_markers_enabled() != this.replayMarkersEnabled) {
        this.replayMarkersEnabled = is_replay_markers_enabled()
        this.scene.findObject("ID_REPLAY_SHOW_MARKERS").highlighted = this.replayMarkersEnabled ? "yes" : "no"
      }
      let replayTimeCurrent = get_mission_time()
      this.scene.findObject("txt_replay_time_current").setValue(time.preciseSecondsToString(replayTimeCurrent))
      let progress = (this.replayTimeTotal > 0) ? (1000 * replayTimeCurrent / this.replayTimeTotal).tointeger() : 0
      if (progress != this.replayTimeProgress) {
        this.replayTimeProgress = progress
        this.scene.findObject("timeline_progress").setValue(this.replayTimeProgress)
      }

      if (hasFeature("replayRewind")) {
        let anchors = get_replay_anchors()
        let curAnchorIdx = this.getCurAnchorIdx(anchors)
        this.scene.findObject("ID_REPLAY_BACKWARD").enable(curAnchorIdx >= 0)
        this.scene.findObject("ID_REPLAY_FORWARD").enable(anchors.len() > 0 && (curAnchorIdx + 1) < anchors.len())
      }
    }

    if (isSensorViewMode() != this.isSensorViewModeEnabled) {
      this.isSensorViewModeEnabled = isSensorViewMode()
      this.scene.findObject("ID_REPLAY_TOGGLE_SENSOR_VIEW").highlighted = this.isSensorViewModeEnabled ? "yes" : "no"
      showObjById("sensorFilters", this.isSensorViewModeEnabled, this.scene)
    }

    if (this.canSeeMissionTimer) {
      this.scene.findObject("txt_mission_timer").setValue(time.secondsToString(get_mission_time(), false))
    }

    if (is_spectator_rotation_forced() != this.cameraRotationByMouse) {
      this.cameraRotationByMouse = is_spectator_rotation_forced()
      this.scene.findObject("ID_TOGGLE_FORCE_SPECTATOR_CAM_ROT").highlighted = this.cameraRotationByMouse ? "yes" : "no"
    }

    if (this.canControlCameras && targetSwitched) {
      let player = this.getTargetPlayer()
      let isValid = player != null
      let isPlayer = player ? !player.isBot : false
      let userId   = player?.userId ?? 0
      let isAuthor = userId == this.replayAuthorUserId
      let isAuthorUnknown = this.replayAuthorUserId == -1
      let isAircraft = isInArray(this.lastHudUnitType,
        [HUD_UNIT_TYPE.AIRCRAFT, HUD_UNIT_TYPE.HELICOPTER])

      enableObjsByTable(this.scene, {
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

  function reinitDmgIndicator() {
    let obj = this.scene.findObject("spectator_hud_damage")
    if (obj?.isValid())
      eventbus_send("updateDmgIndicatorStates", {
        isVisible = this.getTargetPlayer() != null && hasFeature("SpectatorUnitDmgIndicator")
        size = obj.getSize()
        pos = obj.getPosRC()
      })
  }

  function statTblGetSelectedPlayer(obj) {
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

  function onPlayerClick(obj) {
    if (this.ignoreUiInput)
      return

    this.selectPlayer(this.statTblGetSelectedPlayer(obj), obj)
  }

  function selectPlayer(player, _tableObj) {
    if (!player)
      return

    this.statSelPlayerId[this.teamIdToIndex(player.team)] = player.id
    this.switchTargetPlayer(player.id)
  }

  function onPlayerRClick(obj) {
    let player = this.statTblGetSelectedPlayer(obj)
    if (player)
      ::session_player_rmenu(
        this,
        player,
        getLogForBanhammer()
      )
  }

  function switchTargetPlayer(id) {
    if (id >= 0)
      switchSpectatorTargetById(id)
  }

  function saveLastTargetPlayerData(player) {
    this.lastTargetData.team = this.teamIdToIndex(player.team)
    this.lastTargetData.id = player.id
  }

  function selectTargetTeamBlock() {
    let player = this.getTargetPlayer()
    if (!player)
      return false

    this.saveLastTargetPlayerData(player)
    this.statSelPlayerId[this.lastTargetData.team] = player.id

    let tblObj = this.getTeamTableObj(player.team)
    if (!tblObj)
      return false
    move_mouse_on_child_by_value(tblObj)
    return true
  }

  function selectControlsBlock(_obj) {
    if (::get_is_console_mode_enabled())
      this.selectTargetTeamBlock()
  }

  function onSelectPlayer(obj) {
    if (this.ignoreUiInput)
      return

    let player = this.statTblGetSelectedPlayer(obj)
    if (!player)
      return

    let curPlayer = this.getTargetPlayer()
    if (::get_is_console_mode_enabled() && u.isEqual(curPlayer, player)) {
      let selIndex = getObjValidIndex(obj)
      let selectedPlayerBlock = obj.getChild(selIndex >= 0 ? selIndex : 0)
      ::session_player_rmenu(
        this,
        player,
        getLogForBanhammer(),
        [
          selectedPlayerBlock.getPosRC()[0] + selectedPlayerBlock.getSize()[0] / 2,
          selectedPlayerBlock.getPosRC()[1]
        ]
      )
      return
    }

    this.saveLastTargetPlayerData(player)
    this.selectPlayer(player, obj)
  }

  function onChangeFocusTable(obj) {
    this.lastSelectedTableId = obj.id
  }

  function onBtnMpStatScreen(_obj) {
    if (this.isMultiplayer)
      guiStartMPStatScreen()
    else
      gui_start_tactical_map()
  }

  function onBtnShortcut(obj) {
    let id = checkObj(obj) ? (obj?.id ?? "") : ""
    if (id.len() > 3 && id.slice(0, 3) == "ID_")
      toggleShortcut(id)
  }

  function onBtnCancelReplayDownload() {
    cancel_loading()
    this.scene.findObject("replay_paused_block").show(false)
  }

  function onMapClick(_obj = null) {
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

  function onToggleButtonClick(obj) {
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

  function teamIdToIndex(teamId) {
    foreach (info in this.teams)
      if (info.teamId == teamId)
        return info.index
    return 0
  }

  function getTableObj(index) {
    let obj = this.scene.findObject($"table_team{index + 1}")
    return checkObj(obj) ? obj : null
  }

  function getTeamTableObj(teamId) {
    return this.getTableObj(this.teamIdToIndex(teamId))
  }

  function getTeamPlayers(teamId) {
    let tbl = (teamId != 0) ? get_mplayers_list(teamId, true) : [ get_local_mplayer() ]
    for (local i = tbl.len() - 1; i >= 0; i--) {
      let player = tbl[i]
      if (player.spectator
        || (this.mode == SPECTATOR_MODE.SKIRMISH
          && (player.state != PLAYER_IN_FLIGHT || player.isDead) && !player.deaths)) {
        tbl.remove(i)
        continue
      }

      player.team = teamId
      player.ingame <- player.state == PLAYER_IN_FLIGHT || player.state == PLAYER_IN_RESPAWN
      player.isActing <- player.ingame
        && (!(this.gameType & GT_RACE) || player.raceFinishTime < 0)
        && (!(this.gameType & GT_LAST_MAN_STANDING) || player.deaths == 0)
      if (this.mode == SPECTATOR_MODE.REPLAY && !player.isBot)
        player.isBot = player.userId == "0" || player?.invitedName != null
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

  function mpstatSortSpectator(a, b) {
    return b.isActing <=> a.isActing
      || (!a.isActing && this.funcSortPlayersDefault(a, b))
      || a.isBot <=> b.isBot
      || a.id <=> b.id
  }

  function getTeamClanTag(players) {
    let clanTag = players?[0]?.clanTag ?? ""
    if (players.len() < 2 || clanTag == "")
      return ""
    foreach (p in players)
      if (p.clanTag != clanTag)
        return ""
    return clanTag
  }

  function getPlayersData() {
    let _teams = array(2, null)
    let isMpMode = !!(this.gameType & GT_VERSUS) || !!(this.gameType & GT_COOPERATIVE)
    let isPvP = !!(this.gameType & GT_VERSUS)
    let isTeamplay = isPvP && ::is_mode_with_teams(this.gameType)

    if (isTeamplay || !this.canSeeOppositeTeam) {
      let localTeam = get_mp_local_team() != 2 ? 1 : 2
      let isMyTeamFriendly = localTeam == get_player_army_for_hud()

      for (local i = 0; i < 2; i++) {
        let teamId = ((i == 0) == (localTeam == 1)) ? Team.A : Team.B
        let color = ((i == 0) == isMyTeamFriendly) ? "blue" : "red"
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
    else if (isMpMode) {
      let teamId = isTeamplay ? get_mp_local_team() : GET_MPLAYERS_LIST
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
    else {
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

  function updateStats() {
    let _teams = this.getPlayersData()
    foreach (idx, info in _teams) {
      let tblObj = this.getTableObj(info.index)
      if (tblObj) {
        let infoPrev = this.teams?[idx]
        if (info.active)
          this.statTblUpdateInfo(tblObj, info, infoPrev)
        if (info.active != (infoPrev?.active ?? true)) {
          tblObj.getParent().getParent().show(info.active)
          this.scene.findObject($"btnToggleStats{idx + 1}").show(info.active)
        }
      }
    }
    this.teams = _teams
  }

  function addPlayerRows(objTbl, teamInfo) {
    let totalRows = objTbl.childrenCount()
    let newRows = teamInfo.players.len() - totalRows
    if (newRows <= 0)
      return totalRows

    let view = { rows = array(newRows, 1)
                   iconLeft = teamInfo.index == 0
                 }
    let data = handyman.renderCached(("%gui/hud/spectatorTeamRow.tpl"), view)
    this.guiScene.appendWithBlk(objTbl, data, this)
    return totalRows
  }

  function isPlayerChanged(p1, p2) {
    if (this.debugMode)
      return true
    if (!p1 != !p2)
      return true
    if (!p1)
      return false
    foreach (param in this.scanPlayerParams)
      if (p1?[param] != p2?[param])
        return true
    return false
  }

  function statTblUpdateInfo(objTbl, teamInfo, infoPrev = null) {
    let players = teamInfo?.players
    if (!(objTbl?.isValid() ?? false) || !players)
      return

    this.guiScene.setUpdatesEnabled(false, false)

    let prevPlayers = infoPrev?.players
    let wasRows = this.addPlayerRows(objTbl, teamInfo)
    let totalRows = objTbl.childrenCount()

    let selPlayerId = this.statSelPlayerId?[teamInfo.index]
    local selIndex = null

    let needClanTags = (teamInfo?.clanTag ?? "") == ""

    for (local i = 0; i < totalRows; i++) {
      let player = players?[i]
      if (i < wasRows && !this.isPlayerChanged(player, prevPlayers?[i]))
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
      obj.findObject("unit").setValue(getUnitName(unitId || "dummy_plane"))
      obj.tooltip = "".concat(playerName, unitId ? loc("ui/parentheses/space", { text = getUnitName(unitId, false) }) : "",
        stateDesc != "" ? $"\n{stateDesc}" : "", malfunctionDesc != "" ? $"\n{malfunctionDesc}" : "")

      if (this.debugMode)
        obj.tooltip = "\n\n".concat(obj.tooltip, this.getPlayerDebugTooltipText(player))

      let unitIcoObj = obj.findObject("unit-ico")
      unitIcoObj["background-image"] = iconImg
      unitIcoObj.shopItemType = iconType

      let briefMalfunctionState = player?.briefMalfunctionState ?? 0
      let weaponIcons = (unitId && ("weapon" in player)) ? getWeaponTypeIcoByWeapon(unitId, player.weapon)
        : getWeaponTypeIcoByWeapon("", "")

      foreach (iconId, w in weaponIcons) {
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
        (!player.ingame || player.isDead)                   ? "" :
        (player?.isExtinguisherActive ?? false)             ? "ExtinguisherActive" :
        (player?.isBurning ?? false)                        ? "IsBurning" :
        (briefMalfunctionState & BMS_ENGINE_BROKEN)         ? "BrokenEngine" :
        (briefMalfunctionState & BMS_MAIN_GUN_BROKEN)       ? "BrokenGun" :
        (briefMalfunctionState & BMS_TRACK_BROKEN)          ? "BrokenTrack" :
        (briefMalfunctionState & BMS_OUT_OF_AMMO)           ? "OutOfAmmo" :
                                                                ""
      obj.findObject("battle-state-ico")["class"] = battleStateIconClass

      if (player.id == selPlayerId)
        selIndex = i
    }

    if (selIndex != null && objTbl.getValue() != selIndex && objTbl.isFocused()) {
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

  function getPlayerDebugTooltipText(player) {
    if (!player)
      return ""
    let extra = []
    foreach (i, v in player) {
      if (i == "uid")
        continue
      let val = (i == "state") ? this.playerStateToString(v) : v
      extra.append($"{i} = {val}")
    }
    extra.sort()
    return "\n".join(extra, true)
  }

  function playerStateToString(state) {
    return playerStateToStringMap?[state] ?? $"{state}"
  }

  function updateClientHudOffset() {
    this.guiScene.setUpdatesEnabled(true, true)
    let obj = this.scene.findObject("stats_left")
    spectator_air_hud_offset_x = (checkObj(obj) && obj.isVisible()) ? obj.getPos()[0] + obj.getSize()[0] : 0
  }

  function onBtnLogTabSwitch(obj) {
    if (!checkObj(obj))
      return

    let tabIdx = obj.getValue()
    if (tabIdx < 0 || tabIdx >= obj.childrenCount())
      return

    let tabObj = obj.getChild(tabIdx)
    let newTabId = tabObj?.id
    if (!newTabId || newTabId == this.curTabId)
      return

    foreach (tab in this.tabsList) {
      let objContainer = this.scene.findObject(tab.containerId)
      if (!checkObj(objContainer))
        continue

      objContainer.show(tab.id == newTabId)
    }
    this.curTabId = newTabId
    tabObj.findObject("new_msgs").show(false)

    showOrdersContainer(this.curTabId == SPECTATOR_CHAT_TAB.ORDERS)

    if (this.curTabId == SPECTATOR_CHAT_TAB.CHAT)
      this.loadGameChat()
    this.updateHistoryLog(true)
  }

  function updateNewMsgImg(tabId) {
    if (!this.scene.isValid() || tabId == this.curTabId)
      return
    let obj = this.scene.findObject(tabId)
    if (checkObj(obj))
      obj.findObject("new_msgs").show(true)
  }

  function onEventMpChatLogUpdated(_params) {
    this.updateNewMsgImg(SPECTATOR_CHAT_TAB.CHAT)
  }

  function onEventActiveOrderChanged(_params) {
    this.updateNewMsgImg(SPECTATOR_CHAT_TAB.ORDERS)
  }

  function onEventMpChatInputRequested(params) {
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

    if (params?.activate ?? false)
      toggle_ingame_chat(true)
  }

  function onEventReplayWait(event) {
    let replayPausedBlockObj = this.scene.findObject("replay_paused_block")
    if (!replayPausedBlockObj?.isValid())
      return

    replayPausedBlockObj.show(event.isShow)

    let hasDownloadStatus = "dlCur" in event && "dlTotal" in event && "dlPercent" in event
    let downloadStatusString = event.isShow && hasDownloadStatus
      ? loc(
          "hints/replay_download_status",
          {
            downloadedMB = round_by_value(event.dlCur, 0.1),
            totalMB = round_by_value(event.dlTotal, 0.1),
            downloadedPercent = round_by_value(event.dlPercent, 0.1)
          }
        )
      : ""

    this.scene.findObject("replay_download_status").setValue(downloadStatusString)
  }

  function onPlayerRequestedArtillery(userId) {
    let player = this.getPlayerByUserId(userId)
    let color = this.isPlayerFriendly(player) ? "hudColorDarkBlue" : "hudColorDarkRed"
    this.addHistroyLogMessage(colorize(color, loc("artillery_strike/called_by_player", { player =  this.getPlayerNick(player, true) })))
  }

  function onHudMessage(msg) {
    if (msg.type not in supportedMsgTypes)
      return

    if (!("id" in msg))
      msg.id <- -1
    if (!("text" in msg))
      msg.text <- ""

    msg.time <- get_mission_time()

    this.historyLog = this.historyLog ?? []
    if (msg.id != -1)
      foreach (m in this.historyLog)
        if (m.id == msg.id)
          return
    if (msg.id == -1 && msg.text != "") {
      let skipDupTime = msg.time - this.historySkipDuplicatesSec
      for (local i = this.historyLog.len() - 1; i >= 0; i--) {
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

  function addHistroyLogMessage(text) {
    this.onHudMessage({
      id   = -1
      text = text
      type = this.historyLogCustomMsgType
    })
  }

  function clearHistoryLog() {
    if (!this.historyLog)
      return
    this.historyLog.clear()
    this.updateHistoryLog()
  }

  function updateHistoryLog(updateVisibility = false) {
    if (!(this.scene?.isValid() ?? false))
      return

    let obj = this.scene.findObject("history_log")
    if (!(obj?.isValid() ?? false))
      return

    if (updateVisibility)
      this.guiScene.setUpdatesEnabled(true, true)

    this.historyLog = this.historyLog ?? []
    if (!obj.isVisible() || this.historyLog.len() == 0) {
      obj.setValue("")
      return
    }

    let historyLogMessages = this.historyLog.map(@(msg) msg.message)
    obj.setValue("\n".join(historyLogMessages, true))
  }

  function buildHistoryLogMessage(msg) {
    let timestamp = "".concat(time.secondsToString(msg.time, false), " ")
    // All players messages
    if (msg.type == HUD_MSG_MULTIPLAYER_DMG) { // Any player or ai unit damaged or destroyed
      let text = HudBattleLog.msgMultiplayerDmgToText(msg)
      let icon = HudBattleLog.getActionTextIconic(msg)
      return "".concat(timestamp, colorize("userlogColoredText", $"{icon} {text}"))
    }

    if (msg.type == HUD_MSG_STREAK_EX) { // Any player got streak
      let text = HudBattleLog.msgStreakToText(msg, true)
      return "".concat(timestamp, colorize("streakTextColor", loc("ui/colon").concat(loc("unlocks/streak"), text)))
    }

    // Mission objectives
    if (msg.type == HUD_MSG_OBJECTIVE) { // Hero team mission objective
      let text = HudBattleLog.msgEscapeCodesToCssColors(msg.text)
      return "".concat(timestamp, colorize("white", loc("ui/colon").concat(loc("sm_objective"), text)))
    }

    // Team progress
    if (msg.type == HUD_MSG_DIALOG) { // Hero team base capture events
      let text = HudBattleLog.msgEscapeCodesToCssColors(msg.text)
      return "".concat(timestamp, colorize("commonTextColor", text))
    }

    // Hero (spectated target) messages
    if (msg.type in hudHeroMessages || msg.type == this.historyLogCustomMsgType) { // Custom messages sent by script
      let text = HudBattleLog.msgEscapeCodesToCssColors(msg.text)
      return "".concat(timestamp, colorize("commonTextColor", text))
    }
    return ""
  }

  function setHotkeysToObjTooltips(scanObj, objects) {
    if (checkObj(scanObj))
      foreach (objId, keys in objects) {
        let obj = scanObj.findObject(objId)
        if (checkObj(obj)) {
          local hotkeys = ""
          if ("shortcuts" in keys) {
            let shortcuts = ::get_shortcuts(keys.shortcuts)
            let locNames = []
            foreach (idx, _data in shortcuts) {
              let shortcutsText = ::get_shortcut_text({
                shortcuts = shortcuts,
                shortcutId = idx,
                strip_tags = true
              })
              if (shortcutsText != "")
                locNames.append(shortcutsText)
            }
            hotkeys = loc("ui/comma").join(locNames, true)
          }
          else if ("keys" in keys) {
            let keysLocalized = keys.keys.map(loc)
            hotkeys = loc("ui/comma").join(keysLocalized, true)
          }

          if (hotkeys != "") {
            let tooltip = obj?.tooltip ?? ""
            let add = "".concat("<color=@hotkeyColor>", loc("ui/parentheses/space", { text = hotkeys }), "</color>")
            obj.tooltip = $"{tooltip}{add}"
          }
        }
      }
  }

  function getCurAnchorIdx(anchors) {
    let count = anchors.len()
    if (count == 0)
      return -1

    let replayCurTime = get_mission_time() * 1000
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
    let data = handyman.renderCached("%gui/replays/replayAnchorMark.tpl", {
      anchors = anchors.map(function(v, idx) {
        let anchorTimeS = v / 1000.0
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

gui_handlers.Spectator <- Spectator

::spectator_debug_mode <- function spectator_debug_mode() {
  let handler = is_dev_version() && handlersManager.findHandlerClassInScene(gui_handlers.Spectator)
  if (!handler)
    return null
  handler.debugMode = !handler.debugMode
  return handler.debugMode
}

::isPlayerDedicatedSpectator <- function isPlayerDedicatedSpectator(name = null) {
  if (name) {
    let member = isInSessionRoom.get() ? ::SessionLobby.getMemberByName(name) : null
    return member ? !!::SessionLobby.getMemberPublicParam(member, "spectator") : false
  }
  return !!((get_local_mplayer() ?? {})?.spectator ?? 0)
}
::cross_call_api.isPlayerDedicatedSpectator <- ::isPlayerDedicatedSpectator

::get_spectator_air_hud_offset_x <- function get_spectator_air_hud_offset_x() { // called from client
  return spectator_air_hud_offset_x
}

function on_player_requested_artillery(data) { // called from client
  let { userId } = data
  let handler = handlersManager.findHandlerClassInScene(gui_handlers.Spectator)
  if (handler)
    handler.onPlayerRequestedArtillery(userId)
}

function on_spectator_tactical_map_request() { // called from client
  let handler = handlersManager.findHandlerClassInScene(gui_handlers.Spectator)
  if (handler)
    handler.onMapClick()
}

eventbus_subscribe("on_player_requested_artillery", @(p) on_player_requested_artillery(p))
eventbus_subscribe("on_spectator_tactical_map_request", @(_p) on_spectator_tactical_map_request())

eventbus_subscribe("replayWait", function (event) {
  broadcastEvent("ReplayWait", event)
})