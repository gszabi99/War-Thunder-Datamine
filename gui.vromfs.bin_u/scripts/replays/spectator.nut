import "%sqStdLibs/helpers/u.nut" as u
import "DataBlock" as DataBlock
from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler
from "%scripts/baseGuiHandlerWT.nut" import BaseGuiHandlerWT
from "%scripts/sqDagui/framework/handlerType.nut" import handlerType
from "%scripts/replays/replayMetadata.nut" import restoreReplayScriptCommentsBlk
from "%scripts/unit/unitInfoRoles.nut" import getUnitClassColor
from "%scripts/user/remapNick.nut" import getPlayerName
from "%appGlobals/clientState/touchScreen.nut" import useTouchscreen
from "%scripts/statistics/mpStatisticsUtil.nut" import guiStartMPStatScreen, getSpectatorTeammateStatIds, getSpectatorTeammateStats
from "%scripts/statistics/mpStatisticsInfo.nut" import getWeaponTypeIcoByWeapon
from "%appGlobals/debugTools/dbgEnum.nut" import getEnumValName
from "%scripts/hud/hudUnitType.nut" import HUD_UNIT_TYPE
from "%scripts/clientState/clientStates.nut" import getFromSettingsBlk
from "%scripts/unit/unitInfo.nut" import getUnitName
from "%scripts/hud/hudActionBar.nut" import ActionBar, mkActionBarAir
from "%scripts/hud/dargHudLayers.nut" import getDargLayerWidgets, mkMpScoreWidget
from "%scripts/hud/actionBarState.nut" import updateActionBar
from "%scripts/mainmenu/guiStartMainmenu.nut" import gui_start_mainmenu
from "%scripts/tacticalMap.nut" import gui_start_tactical_map
from "%scripts/chat/mpChatModel.nut" import getLogForBanhammer
from "%scripts/replays/replaySystemWindow.nut" import replaySystemWindowOpen, replaySystemWindowClose
from "%scripts/unit/unitInfoTexts.nut" import getUnitClassIco
from "%scripts/contacts/contactsInfo.nut" import getPlayerFullName, colorizeWhitePsnIcon
from "%scripts/squads/squadState.nut" import isEqualSquadId
from "%scripts/controls/controlsCompatibility.nut" import getShortcuts
from "%scripts/user/playerContextMenu.nut" import showSessionPlayerRClickMenu
from "%scripts/controls/controlsVisual.nut" import getShortcutText
from "%scripts/replays/replayScreen.nut" import backToReplays
from "%scripts/options/consoleMode.nut" import getIsConsoleModeEnabled
from "%scripts/statistics/squadIcon.nut" import initListLabelsSquad
from "%scripts/matchingRooms/sessionLobbyState.nut" import resetSessionLobbyPlayersInfo
from "%scripts/replays/backFromReplaysFn.nut" import getBackFromReplaysFn, setBackFromReplaysFn, isBackToReplays
from "%scripts/missions/missionsUtils.nut" import getLevelMapBackgroundColors
from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent
from "matching.errors" import INVALID_SQUAD_ID
from "hudState" import getHudUnitType
from "guiSpectator" import onSpectatorMode, switchSpectatorTargetById, isArbiterMode, getSpectatorTargetId, getSpectatorTargetName
from "replays" import get_time_speeds_list, is_replay_playing, get_replay_info, get_replay_props
from "eventbus" import eventbus_subscribe
from "mission" import get_game_type, get_mplayers_list, GET_MPLAYERS_LIST, get_local_mplayer, get_mp_local_team
from "gameplayBinding" import isInFlight
from "console" import register_command
from "scriptRespondent" import registerRespondent
from "guiMission" import get_current_mission_desc, get_player_army_for_hud
from "%globalScripts/gameTypeConsts.nut" import *
from "%scripts/dagui_natives.nut" import mpstat_get_sort_func
from "%scripts/dagui_library.nut" import *
from "%globalScripts/battleMetaConsts.nut" import *
from "%globalScripts/playerStateConsts.nut" import *
from "hudMessages" import *
from "%scripts/teamsConsts.nut" import Team
from "%appGlobals/missions/missionStateShared.nut" import isModeWithTeams
from "%appGlobals/hud/spectatorState.nut" import spectatorSession, spectatorCameraTarget, isReplaySystemWindowOpened,
  spectatorToolbarShortcuts, spectatorTeams, spectatorAirHudOffsetX

let { g_hud_live_stats } = require("%scripts/hud/hudLiveStats.nut")
let { HudBattleLog } = require("%scripts/hud/hudBattleLog.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let spectatorWatchedHero = require("%scripts/replays/spectatorWatchedHero.nut")
let { currentReplay } = require("%scripts/replays/replayScreen.nut")

const AUTHOR_USER_ID_UNKNOWN = -1
const REPLAY_TIME_TOTAL_ZERO = 0.0

enum SPECTATOR_MODE {
  RESPAWN     
  SKIRMISH    
  SUPERVISOR  
  REPLAY      
}

let airHudUnitTypes = [
  HUD_UNIT_TYPE.HUMAN_DRONE_HELI,
  HUD_UNIT_TYPE.HUMAN_DRONE,
  HUD_UNIT_TYPE.HELICOPTER,
  HUD_UNIT_TYPE.AIRCRAFT
]

let weaponIconsReloadBits = {
  bomb = BMS_OUT_OF_BOMBS
  rocket = BMS_OUT_OF_ROCKETS
  torpedo = BMS_OUT_OF_TORPEDOES
}

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

local debugMode = false

class Spectator (BaseGuiHandlerWT) {
  scene  = null
  sceneBlkName = "%gui/spectator.blk"
  wndType      = handlerType.CUSTOM

  spectatorModeInited = false
  catchingFirstTarget = false

  mode = SPECTATOR_MODE.SKIRMISH
  gameType            = 0
  gotRefereeRights    = false
  isMultiplayer       = false
  canControlTimeline  = false
  canControlCameras   = false
  canSeeMissionTimer  = false
  canSeeOppositeTeam  = false
  isServerReplay      = false

  replayAuthorUserId = AUTHOR_USER_ID_UNKNOWN
  replayTimeTotal = REPLAY_TIME_TOTAL_ZERO

  updateCooldown = 0.0
  teams = [ { players = [] }, { players = [] } ]
  teammateStatIds = null
  lastTargetNick = ""
  lastTargetData = {
    id   = -1
  }
  lastHudUnitType = ""
  lastFriendlyTeam = 0

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

  actionBarWeak = null

  function getWidgetsList() {
    let res = getDargLayerWidgets(this)
      .append(mkMpScoreWidget("1@bhHud + 2@spectatorToolbarPadding + 1@spectatorToolbarBtnSize + 0.02@scrn_tgt"))
    let transform = this.getWidgetParams("spectator_root")
    if (transform != null)
      res.append({ widgetId = DargWidgets.SCREEN, screen = "hud.spectator", transform })
    return res
  }

  function initScreen() {
    this.gameType = get_game_type()
    let mplayerTable = get_local_mplayer() ?? {}
    let isReplay = is_replay_playing()
    let replayProps = get_replay_props()

    if (isReplay) {
      initListLabelsSquad()
      
      let isToReplays = isBackToReplays()
      let backFn = getBackFromReplaysFn() ?? (isToReplays ? backToReplays : function() {
        resetSessionLobbyPlayersInfo()
        gui_start_mainmenu()
      })
      setBackFromReplaysFn(backFn, isToReplays)
      currentReplay.path = currentReplay.path.len() ? currentReplay.path : getFromSettingsBlk("viewReplay", "")

      
      restoreReplayScriptCommentsBlk(currentReplay.path)
    }

    this.gotRefereeRights = (mplayerTable?.spectator ?? 0) == 1
    this.mode = isReplay ? SPECTATOR_MODE.REPLAY : SPECTATOR_MODE.SKIRMISH
    this.isMultiplayer = !!(this.gameType & GT_VERSUS) || !!(this.gameType & GT_COOPERATIVE)
    this.isServerReplay      = replayProps?.isServerReplay ?? false
    this.canControlTimeline  = this.mode == SPECTATOR_MODE.REPLAY && (replayProps?.timeSpeedAllowed ?? false)
    this.canControlCameras   = this.mode == SPECTATOR_MODE.REPLAY || this.gotRefereeRights
    this.canSeeMissionTimer  = !this.canControlTimeline && this.mode == SPECTATOR_MODE.SKIRMISH
    this.canSeeOppositeTeam  = this.mode != SPECTATOR_MODE.RESPAWN

    if (!this.isMultiplayer)
      showObjectsByTable(this.scene, {
          btn_tab_chat  = false
          target_stats  = false
      })

    if (this.mode == SPECTATOR_MODE.REPLAY) {
      let info = currentReplay.path.len() && get_replay_info(currentReplay.path)
      this.replayAuthorUserId = info?.comments.authorUserId ?? AUTHOR_USER_ID_UNKNOWN
      this.replayTimeTotal = info?.comments.timePlayed ?? REPLAY_TIME_TOTAL_ZERO
    }
    this.publishSession(replayProps?.sessionId ?? "")
    spectatorCameraTarget.set(null)
    isReplaySystemWindowOpened.set(false)

    this.funcSortPlayersSpectator = this.mpstatSortSpectator.bindenv(this)
    this.funcSortPlayersDefault   = mpstat_get_sort_func(this.gameType)
    this.teammateStatIds = getSpectatorTeammateStatIds()
    spectatorTeams.set(null)

    g_hud_live_stats.init(this.scene, "spectator_live_stats_nest", false)

    this.onUpdate()
    this.scene.findObject("update_timer").setUserData(this)

    this.setTacticalMapBackgroundColors()
  }

  function publishSession(replaySessionId) {
    let isReplay = this.mode == SPECTATOR_MODE.REPLAY
    let timeSpeeds = isReplay ? get_time_speeds_list() : [1.0]
    let hotkeys = {}
    foreach (id in spectatorToolbarShortcuts)
      hotkeys[id] <- getShortcutText({
        shortcuts = getShortcuts([ id ])
        shortcutId = 0
        cantBeEmpty = false
        strip_tags = true
      })
    spectatorSession.set({
      isReplay
      isReplayCamera = isReplay && !this.gotRefereeRights
      canSwitchPlane = !isReplay || this.isMultiplayer
      isTouch = useTouchscreen
      canControlTimeline = this.canControlTimeline
      canControlCameras = this.canControlCameras
      canSeeMissionTimer = this.canSeeMissionTimer
      canRewind = this.canControlTimeline && hasFeature("replayRewind")
      hasSystemWindow = isReplay && hasFeature("ReplaySystemWindow")
      timeSpeedMin = timeSpeeds[0]
      timeSpeedMax = timeSpeeds.top()
      timeTotal = this.replayTimeTotal
      sessionId = isReplay ? replaySessionId : ""
      hotkeys
    })
  }

  function setTacticalMapPosition(hudUnitType = null) {
    let player = this.getTargetPlayer()
    let hasHud = player == null ? false
      : [PLAYER_READY_TO_START, PLAYER_IN_FLIGHT, PLAYER_IN_RESPAWN].contains(player.state)
    let stickTo = (hasHud && hudUnitType == HUD_UNIT_TYPE.HUMAN) ? "left" : "right"
    this.scene.findObject("map_div")["stickTo"] = stickTo

    let toggleMapObj = this.scene.findObject("btnToggleMap")
    toggleMapObj["stickTo"] = stickTo
    toggleMapObj["attachSide"] = stickTo
  }

  function setTacticalMapBackgroundColors() {
    let misBlk = DataBlock()
    get_current_mission_desc(misBlk)
    let { customMapBackColor } = getLevelMapBackgroundColors(misBlk?.level ?? "")
    
    let tacticalMapBgObj = this.scene.findObject("map_div_bg")
    tacticalMapBgObj.bgcolor = customMapBackColor
    
    let tacticalMapLargeBgObj = this.scene.findObject("tactical_map_large_bg")
    tacticalMapLargeBgObj.bgcolor = customMapBackColor
  }

  function onDestroy() {
    this.funcSortPlayersSpectator = null
    this.teams = [ { players = [] }, { players = [] } ]
    spectatorTeams.set(null)
  }

  function reinitScreen() {
    g_hud_live_stats.update()
    if (this.isNeedRecreateActionBar())
      this.recreateActionBar()
    else
      this.actionBarWeak?.reinit()
    this.updateTarget(true)
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
    let friendlyTeam = get_player_army_for_hud()
    let friendlyTeamSwitched = friendlyTeam != this.lastFriendlyTeam
    this.lastFriendlyTeam = friendlyTeam

    if (isUpdateByCooldown) {
      this.updateStats()
    }

    if (isTargetSwitched || friendlyTeamSwitched || isUpdateByCooldown) {
      if (this.isNeedRecreateActionBar())
        this.recreateActionBar()
      this.updateTarget(isTargetSwitched)
    }

    if (friendlyTeamSwitched || isTargetSwitched) {
      g_hud_live_stats.show(this.isMultiplayer, null, spectatorWatchedHero.id)
      broadcastEvent("WatchedHeroSwitched")
    }

    this.updateControls(isTargetSwitched)

    if (isUpdateByCooldown) {
      this.updateCooldown = 0.5

      
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

  function getPlayerNick(player, needColored = false, needClanTag = true, needPsnIconTags = true) {
    if (player == null)
      return  ""
    let { name, realName = "", isBot, clanTag } = player
    let nick = getPlayerName(name) 
    local fullName = getPlayerFullName(needPsnIconTags ? colorizeWhitePsnIcon(nick) : nick,
      needClanTag && !isBot ? clanTag : "")
    if (this.mode == SPECTATOR_MODE.REPLAY && realName != "" && name != realName)
      fullName = $"{fullName} ({realName})"
    return needColored ? colorize(this.getPlayerColor(player), fullName) : fullName
  }

  function getPlayerColor(player) {
    return player.isLocal ? "hudColorHero"
    : player.isInHeroSquad ? "hudColorSquad"
    : player.team == get_player_army_for_hud() ? "hudColorBlue"
    : "hudColorRed"
  }

  function getPlayerStateDesc(player) {
    return !player ? ""
      : !player.ingame ? loc(player.deaths ? "spectator/player_quit"
        : "multiplayer/state/player_not_in_game")
      : player.isDead
        ? loc(!player.deaths ? "spectator/player_connecting"
          : this.lastHudUnitType == HUD_UNIT_TYPE.HUMAN ? "spectator/player_control_lost"
          : "spectator/player_vehicle_lost")
      : !player.canBeSwitchedTo ? loc("multiplayer/state/player_in_game/location_unknown")
      : ""
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

  function recreateActionBar() {
    let hudUnitType = getHudUnitType()
    let isAircraftHud = airHudUnitTypes.contains(hudUnitType)
    let nest = this.scene.findObject("spectator_hud_action_bar")
    let actionBar = isAircraftHud
      ? mkActionBarAir(nest)
      : ActionBar(nest)
    if (this.actionBarWeak?.scene)
      this.actionBarWeak.scene = null
    this.actionBarWeak = actionBar.weakref()
    this.actionBarWeak?.reinit()
  }

  function isNeedRecreateActionBar() {
    let hudUnitType = getHudUnitType()
    if (((hudUnitType == this.lastHudUnitType) && this.actionBarWeak)
      || (hudUnitType == ""))
      return false

    if (this.lastHudUnitType == "")
      return true

    let nowIsAircraftHud = airHudUnitTypes.contains(hudUnitType)
    let prevIsAircraftHud = airHudUnitTypes.contains(this.lastHudUnitType)
    return (this.actionBarWeak == null) || (nowIsAircraftHud != prevIsAircraftHud)
  }

  function updateTarget(targetSwitched = false) {
    let player = this.getTargetPlayer()
    this.lastHudUnitType = getHudUnitType()
    if (targetSwitched) {
      spectatorWatchedHero.id      = player?.id ?? -1
      spectatorWatchedHero.squadId = player?.squadId ?? INVALID_SQUAD_ID
      spectatorWatchedHero.name    = player?.name ?? ""
    }
    this.setTacticalMapPosition(this.lastHudUnitType)

    g_hud_live_stats.show(this.isMultiplayer, null, spectatorWatchedHero.id)
    updateActionBar()

    this.setTargetInfo(player)
  }

  function updateControls(targetSwitched = false) {
    if (this.canControlCameras && targetSwitched) {
      let player = this.getTargetPlayer()
      let isValid = player != null
      let isPlayer = player ? !player.isBot : false
      let userId   = player?.userId ?? 0
      let isAuthor = userId == this.replayAuthorUserId
      let isAuthorUnknown = this.replayAuthorUserId == AUTHOR_USER_ID_UNKNOWN
      let isAircraft = isInArray(this.lastHudUnitType,
        [HUD_UNIT_TYPE.AIRCRAFT, HUD_UNIT_TYPE.HELICOPTER,
          HUD_UNIT_TYPE.HUMAN_DRONE, HUD_UNIT_TYPE.HUMAN_DRONE_HELI
        ])
      let isFollowActive = isValid && isPlayer &&
        (this.gotRefereeRights || this.isServerReplay || isAuthor || isAuthorUnknown)
      spectatorCameraTarget.set({ isValid, isFollowActive, isAircraft })
    }
  }

  function openPlayerMenu(id, menuPos = null) {
    let player = this.getPlayer(id)
    if (player)
      showSessionPlayerRClickMenu(this, player, getLogForBanhammer(), menuPos)
  }

  function switchTargetPlayer(id) {
    if (id < 0)
      return
    switchSpectatorTargetById(id)
    if (this.isNeedRecreateActionBar())
      this.recreateActionBar()
    this.updateTarget(true)
  }

  function onPlayerActivate(id, menuPos) {
    let player = this.getPlayer(id)
    if (!player)
      return
    if (getIsConsoleModeEnabled() && u.isEqual(this.getTargetPlayer(), player)) {
      this.openPlayerMenu(id, menuPos)
      return
    }
    this.switchTargetPlayer(player.id)
  }

  function openMpStatScreen() {
    if (this.isMultiplayer)
      guiStartMPStatScreen()
    else
      gui_start_tactical_map()
  }

  function onMapClick(_obj = null) {
    let mapLargePanelObj = this.scene.findObject("map_large_div")
    if (!mapLargePanelObj?.isValid())
      return

    let tacticalMapObj = mapLargePanelObj.findObject("tactical_map")
    let toggle = !mapLargePanelObj.isVisible()
    mapLargePanelObj.show(toggle)
    tacticalMapObj.enable(toggle)
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
      player.aircraftName = unitId ?? ""
      player.canBeSwitchedTo = unitId ? player.canBeSwitchedTo : false
      player.isLocal = spectatorWatchedHero.id == player.id
      player.isInHeroSquad = isEqualSquadId(spectatorWatchedHero.squadId, player?.squadId)
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
    let isTeamplay = isPvP && isModeWithTeams(this.gameType)

    if (isTeamplay || !this.canSeeOppositeTeam) {
      let isArbiter = isArbiterMode()
      let localTeam = isArbiter
        ? Team.A
        : get_mp_local_team() != Team.B ? Team.A : Team.B
      let isMyTeamFriendly = localTeam == get_player_army_for_hud()

      for (local i = 0; i < 2; i++) {
        let teamId = ((i == 0) == (localTeam == 1)) ? Team.A : Team.B
        local color = ((i == 0) == isMyTeamFriendly) ? "blue" : "red"
        if (isArbiter)
          color = (i == 0) ? "blue" : "red"

        let players = this.getTeamPlayers(teamId)

        _teams[i] = {
          active = true
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
        players = players
        color = color
        clanTag = isTeamplay ? this.getTeamClanTag(players) : ""
      }
      _teams[1] = {
        active = false
        players = []
        color = ""
        clanTag = ""
      }
    }
    else {
      let color = "blue"
      let players = this.getTeamPlayers(0)

      _teams[0] = {
        active = false
        players = players
        color = color
        clanTag = ""
      }
      _teams[1] = {
        active = false
        players = []
        color = ""
        clanTag = ""
      }
    }
    return _teams
  }

  function updateStats() {
    let _teams = this.getPlayersData()
    let prevViews = spectatorTeams.get()
    let views = []
    foreach (idx, info in _teams)
      views.append(this.mkTeamView(info, this.teams?[idx], prevViews?[idx]))
    if (!u.isEqual(views, prevViews))
      spectatorTeams.set(views)
    this.teams = _teams
  }

  function mkTeamView(teamInfo, infoPrev, viewPrev) {
    let { active, players, color, clanTag } = teamInfo
    if (!active)
      return { isActive = false }
    let prevPlayers = infoPrev?.players
    let prevRows = viewPrev?.rows
    let needClanTags = clanTag == ""
    let rows = []
    foreach (i, player in players)
      rows.append(prevRows?[i] != null && !this.isPlayerChanged(player, prevPlayers?[i])
        ? prevRows[i]
        : this.mkPlayerRow(player, needClanTags))
    let view = { isActive = true, color, clanTag, statIds = this.teammateStatIds, rows }
    return u.isEqual(view, viewPrev) ? viewPrev : view
  }

  function isPlayerChanged(p1, p2) {
    if (debugMode)
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

  function mkPlayerRow(player, needClanTags) {
    
    let playerName = this.getPlayerNick(player, false, true, false)
    let unitId = player.aircraftName != "" ? player.aircraftName : null
    let stateDesc = this.getPlayerStateDesc(player)
    let malfunctionDesc = this.getUnitMalfunctionDesc(player)
    local tooltip = "".concat(playerName, unitId ? loc("ui/parentheses/space", { text = getUnitName(unitId, false) }) : "",
      stateDesc != "" ? $"\n{stateDesc}" : "", malfunctionDesc != "" ? $"\n{malfunctionDesc}" : "")
    if (debugMode)
      tooltip = "\n\n".concat(tooltip, this.getPlayerDebugTooltipText(player))

    let briefMalfunctionState = player?.briefMalfunctionState ?? 0
    let weaponIcons = (unitId && ("weapon" in player)) ? getWeaponTypeIcoByWeapon(unitId, player.weapon)
      : getWeaponTypeIcoByWeapon("", "")
    let weapons = {}
    foreach (iconId, w in weaponIcons)
      if (w.icon != "")
        weapons[iconId] <- {
          icon = w.icon
          ratio = w.ratio
          isReloading = (iconId in weaponIconsReloadBits) && (briefMalfunctionState & weaponIconsReloadBits[iconId]) != 0
        }

    let battleState =
      (!player.ingame || player.isDead)                   ? "" :
      (player?.isExtinguisherActive ?? false)             ? "ExtinguisherActive" :
      (player?.isBurning ?? false)                        ? "IsBurning" :
      (briefMalfunctionState & BMS_ENGINE_BROKEN)         ? "BrokenEngine" :
      (briefMalfunctionState & BMS_MAIN_GUN_BROKEN)       ? "BrokenGun" :
      (briefMalfunctionState & BMS_TRACK_BROKEN)          ? "BrokenTrack" :
      (briefMalfunctionState & BMS_OUT_OF_AMMO)           ? "OutOfAmmo" :
                                                              ""

    return {
      id = player.id
      name = needClanTags ? playerName : this.getPlayerNick(player, false, false, false)
      unitName = getUnitName(unitId ?? "dummy_plane")
      tooltip
      unitIcon = !player.ingame ? "#ui/gameuiskin#player_not_ready.svg"
        : unitId ? getUnitClassIco(unitId)
        : "#ui/gameuiskin#dead.svg"
      unitColor = unitId ? getUnitClassColor(unitId) : "white"
      weapons
      battleState
      isHero = player.isLocal
      isBot = player.isBot
      isSquad = player.isInHeroSquad
      isDead = !player.canBeSwitchedTo
      stats = getSpectatorTeammateStats(player)
    }
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

  function onPlayerRequestedArtillery(userId) {
    let player = this.getPlayerByUserId(userId)
    let color = this.isPlayerFriendly(player) ? "hudColorDarkBlue" : "hudColorDarkRed"
    this.addHistroyLogMessage(colorize(color, loc("artillery_strike/called_by_player", { player =  this.getPlayerNick(player, true) })))
  }

  function addHistroyLogMessage(text) {
    HudBattleLog.onHudMessage({
      id   = -1
      text = text
      type = HudBattleLog.historyLogCustomMsgType
    })
  }

  function setHotkeysToObjTooltips(scanObj, objects) {
    if (checkObj(scanObj))
      foreach (objId, keys in objects) {
        let obj = scanObj.findObject(objId)
        if (checkObj(obj)) {
          local hotkeys = ""
          if ("shortcuts" in keys) {
            let shortcuts = getShortcuts(keys.shortcuts)
            let locNames = []
            foreach (idx, _data in shortcuts) {
              let shortcutsText = getShortcutText({
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
}

register_gui_handler("Spectator", Spectator)

function spectatorDebugMode() {
  debugMode = !debugMode
  return debugMode
}

register_command(spectatorDebugMode, "debug.spectatorDebugMode")

function on_player_requested_artillery(data) { 
  let { userId } = data
  let handler = handlersManager.findHandlerClassInScene(Spectator)
  if (handler)
    handler.onPlayerRequestedArtillery(userId)
}

function on_spectator_tactical_map_request() { 
  let handler = handlersManager.findHandlerClassInScene(Spectator)
  if (handler)
    handler.onMapClick()
}

function on_open_replay_system_window() {
  if (!hasFeature("ReplaySystemWindow"))
    return

  if (handlersManager.findHandlerClassInScene(Spectator) == null)
    return
  isReplaySystemWindowOpened.set(!isReplaySystemWindowOpened.get())
  if (isReplaySystemWindowOpened.get())
    replaySystemWindowOpen()
  else
    replaySystemWindowClose()
}

eventbus_subscribe("on_player_requested_artillery", @(p) on_player_requested_artillery(p))
eventbus_subscribe("on_spectator_tactical_map_request", @(_p) on_spectator_tactical_map_request())
eventbus_subscribe("on_open_replay_system_window", @(_p) on_open_replay_system_window())
eventbus_subscribe("spectatorOpenMpStats", @(_) handlersManager.findHandlerClassInScene(Spectator)?.openMpStatScreen())
eventbus_subscribe("spectatorActivatePlayer",
  @(p) handlersManager.findHandlerClassInScene(Spectator)?.onPlayerActivate(p.id, p?.menuPos))
eventbus_subscribe("spectatorPlayerMenu", @(p) handlersManager.findHandlerClassInScene(Spectator)?.openPlayerMenu(p.id))

eventbus_subscribe("replayCommentsReady", @(_) restoreReplayScriptCommentsBlk("", true))

registerRespondent("onGetSpectatorAirHudOffsetX", @() spectatorAirHudOffsetX.get())

return freeze({ Spectator })
