from "%scripts/dagui_natives.nut" import get_player_army_for_hud
from "%scripts/dagui_library.nut" import *
from "hudMessages" import *
from "%scripts/teamsConsts.nut" import Team
from "%scripts/utils_sa.nut" import is_mode_with_teams, get_team_color, get_mplayer_color, is_team_friendly

let { g_hud_event_manager } = require("%scripts/hud/hudEventManager.nut")
let { format, split_by_chars } = require("string")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let regexp2 = require("regexp2")
let time = require("%scripts/time.nut")
let spectatorWatchedHero = require("%scripts/replays/spectatorWatchedHero.nut")
let { is_replay_playing } = require("replays")
let { eventbus_send } = require("eventbus")
let { get_mission_time, get_mplayer_by_id, get_local_mplayer } = require("mission")
let { OPTIONS_MODE_GAMEPLAY, USEROPT_HUD_SHOW_NAMES_IN_KILLLOG,
  USEROPT_HUD_SHOW_AMMO_TYPE_IN_KILLLOG, USEROPT_HUD_SHOW_SQUADRON_NAMES_IN_KILLLOG,
  USEROPT_HUD_SHOW_DEATH_REASON_IN_SHIP_KILLLOG
} = require("%scripts/options/optionsExtNames.nut")
let { userName, userIdInt64 } = require("%scripts/user/profileStates.nut")
let { isShipBattle } = require("%scripts/missions/missionType.nut")
let { getOwnerUnitName } = require("hudActionBar")
let { getLocForStreak } = require("%scripts/streaks.nut")
let { get_gui_option_in_mode } = require("%scripts/options/options.nut")
let { isEqualSquadId } = require("%scripts/squads/squadState.nut")
let { buildMplayerName } = require("%scripts/statistics/mplayersList.nut")
let { getProjectileNameLoc } = require("%scripts/weaponry/bulletsInfo.nut")

let getOwnerUnit = @() getAircraftByName(getOwnerUnitName())

enum BATTLE_LOG_FILTER {
  HERO      = 0x0001
  SQUADMATE = 0x0002
  ALLY      = 0x0004
  ENEMY     = 0x0008
  OTHER     = 0x0010

  SQUAD     = 0x0003
  ALL       = 0x001F
}

let iconByDeathReason = {
  [DR_SHIP_CREW_DEATH] = "◙",
  [DR_AMMO_EXPLOSION] = "◚",
  [DR_AMMO_FIRE] = "◛",
  [DR_SHIP_BURN] = "◜",
  [DR_DROWN] = "◝",
  [DR_SHIP_HULL_DESTRUCTION] = "◞",
  [DR_SHIP_TORPEDO_HIT] = "◟",
  [DR_SHIP_MINE_HIT] = "◠",
  [DR_UNKNOWN] = "⋙",
}

function getActionColor(isKill, isLoss) {
  if (isKill)
    return isLoss ? "hudColorDeathAlly" : "hudColorDeathEnemy"
  return isLoss ? "hudColorDarkRed" : "hudColorDarkBlue"
}

let supportedMsgTypes = {
  [HUD_MSG_MULTIPLAYER_DMG] = true,
  [HUD_MSG_STREAK_EX] = true,
}

let battleLog = persist("battleLog", @() [])

let HudBattleLog = {

  battleLog

  logMaxLen = 2000
  skipDuplicatesSec = 10

  unitTypeSuffix = {
    [ES_UNIT_TYPE_AIRCRAFT] = "_a",
    [ES_UNIT_TYPE_TANK]     = "_t",
    [ES_UNIT_TYPE_BOAT]     = "_s",
    [ES_UNIT_TYPE_SHIP]     = "_s",
    [ES_UNIT_TYPE_HELICOPTER] = "_a",
  }

  actionVerbs = {
    kill = {
      [ES_UNIT_TYPE_AIRCRAFT]   = "NET_UNIT_KILLED_FM",
      [ES_UNIT_TYPE_TANK]       = "NET_UNIT_KILLED_GM",
      [ES_UNIT_TYPE_BOAT]       = "NET_UNIT_KILLED_GM",
      [ES_UNIT_TYPE_SHIP]       = "NET_UNIT_KILLED_GM",
      [ES_UNIT_TYPE_HELICOPTER] = "NET_UNIT_KILLED_FM",
    }
    bomb = {
      [ES_UNIT_TYPE_AIRCRAFT]   = "NET_UNIT_KILLED_FM",
      [ES_UNIT_TYPE_TANK]       = "NET_UNIT_KILLED_GM",
      [ES_UNIT_TYPE_BOAT]       = "NET_UNIT_KILLED_GM",
      [ES_UNIT_TYPE_SHIP]       = "NET_UNIT_KILLED_GM",
      [ES_UNIT_TYPE_HELICOPTER] = "NET_UNIT_KILLED_FM",
      [ES_UNIT_TYPE_INVALID]    = "NET_UNIT_KILLED_GM",
    }
    bullet = {
      [ES_UNIT_TYPE_AIRCRAFT]   = "NET_UNIT_KILLED_FM",
      [ES_UNIT_TYPE_TANK]       = "NET_UNIT_KILLED_GM",
      [ES_UNIT_TYPE_BOAT]       = "NET_UNIT_KILLED_GM",
      [ES_UNIT_TYPE_SHIP]       = "NET_UNIT_KILLED_GM",
      [ES_UNIT_TYPE_HELICOPTER] = "NET_UNIT_KILLED_FM",
      [ES_UNIT_TYPE_INVALID]    = "NET_UNIT_KILLED_GM",
    }
    shell = {
      [ES_UNIT_TYPE_AIRCRAFT]   = "NET_UNIT_KILLED_FM",
      [ES_UNIT_TYPE_TANK]       = "NET_UNIT_KILLED_GM",
      [ES_UNIT_TYPE_BOAT]       = "NET_UNIT_KILLED_GM",
      [ES_UNIT_TYPE_SHIP]       = "NET_UNIT_KILLED_GM",
      [ES_UNIT_TYPE_HELICOPTER] = "NET_UNIT_KILLED_FM",
      [ES_UNIT_TYPE_INVALID]    = "NET_UNIT_KILLED_GM",
    }
    crash = {
      [ES_UNIT_TYPE_AIRCRAFT]   = "NET_PLAYER_HAS_CRASHED",
      [ES_UNIT_TYPE_TANK]       = "NET_PLAYER_GM_HAS_DESTROYED",
      [ES_UNIT_TYPE_BOAT]       = "NET_PLAYER_GM_HAS_DESTROYED",
      [ES_UNIT_TYPE_SHIP]       = "NET_PLAYER_GM_HAS_DESTROYED",
      [ES_UNIT_TYPE_HELICOPTER] = "NET_PLAYER_HAS_CRASHED",
    }
    severe_damage = {
      [ES_UNIT_TYPE_AIRCRAFT]   = "NET_UNIT_SEVERE_DAMAGE",
      [ES_UNIT_TYPE_TANK]       = "NET_UNIT_SEVERE_DAMAGE",
      [ES_UNIT_TYPE_BOAT]       = "NET_UNIT_SEVERE_DAMAGE",
      [ES_UNIT_TYPE_SHIP]       = "NET_UNIT_SEVERE_DAMAGE",
      [ES_UNIT_TYPE_HELICOPTER] = "NET_UNIT_SEVERE_DAMAGE",
    }
    crit = {
      [ES_UNIT_TYPE_AIRCRAFT]   = "NET_UNIT_CRITICAL_HIT",
      [ES_UNIT_TYPE_TANK]       = "NET_UNIT_CRITICAL_HIT",
      [ES_UNIT_TYPE_BOAT]       = "NET_UNIT_CRITICAL_HIT",
      [ES_UNIT_TYPE_SHIP]       = "NET_UNIT_CRITICAL_HIT",
      [ES_UNIT_TYPE_HELICOPTER] = "NET_UNIT_CRITICAL_HIT",
    }
    burn = {
      [ES_UNIT_TYPE_AIRCRAFT]   = "NET_UNIT_CRITICAL_HIT_BURN",
      [ES_UNIT_TYPE_TANK]       = "NET_UNIT_CRITICAL_HIT_BURN",
      [ES_UNIT_TYPE_BOAT]       = "NET_UNIT_CRITICAL_HIT_BURN",
      [ES_UNIT_TYPE_SHIP]       = "NET_UNIT_CRITICAL_HIT_BURN",
      [ES_UNIT_TYPE_HELICOPTER] = "NET_UNIT_CRITICAL_HIT_BURN",
    }
    rocket = {
      [ES_UNIT_TYPE_AIRCRAFT]   = "NET_UNIT_KILLED_FM",
      [ES_UNIT_TYPE_TANK]       = "NET_UNIT_KILLED_GM",
      [ES_UNIT_TYPE_BOAT]       = "NET_UNIT_KILLED_GM",
      [ES_UNIT_TYPE_SHIP]       = "NET_UNIT_KILLED_GM",
      [ES_UNIT_TYPE_HELICOPTER] = "NET_UNIT_KILLED_FM",
    }
    torpedo = {
      [ES_UNIT_TYPE_AIRCRAFT]   = "NET_UNIT_KILLED_FM",
      [ES_UNIT_TYPE_TANK]       = "NET_UNIT_KILLED_GM",
      [ES_UNIT_TYPE_BOAT]       = "NET_UNIT_KILLED_GM",
      [ES_UNIT_TYPE_SHIP]       = "NET_UNIT_KILLED_GM",
      [ES_UNIT_TYPE_HELICOPTER] = "NET_UNIT_KILLED_FM",
    }
    artillery = {
      [ES_UNIT_TYPE_AIRCRAFT]   = "NET_UNIT_KILLED_FM",
      [ES_UNIT_TYPE_TANK]       = "NET_UNIT_KILLED_GM",
      [ES_UNIT_TYPE_BOAT]       = "NET_UNIT_KILLED_GM",
      [ES_UNIT_TYPE_SHIP]       = "NET_UNIT_KILLED_GM",
      [ES_UNIT_TYPE_HELICOPTER] = "NET_UNIT_KILLED_FM",
    }
    depth_bomb = {
      [ES_UNIT_TYPE_AIRCRAFT]   = "NET_UNIT_KILLED_FM",
      [ES_UNIT_TYPE_TANK]       = "NET_UNIT_KILLED_GM",
      [ES_UNIT_TYPE_BOAT]       = "NET_UNIT_KILLED_GM",
      [ES_UNIT_TYPE_SHIP]       = "NET_UNIT_KILLED_GM",
      [ES_UNIT_TYPE_HELICOPTER] = "NET_UNIT_KILLED_FM",
    }
    mine = {
      [ES_UNIT_TYPE_AIRCRAFT]   = "NET_UNIT_KILLED_FM",
      [ES_UNIT_TYPE_TANK]       = "NET_UNIT_KILLED_GM",
      [ES_UNIT_TYPE_BOAT]       = "NET_UNIT_KILLED_GM",
      [ES_UNIT_TYPE_SHIP]       = "NET_UNIT_KILLED_GM",
      [ES_UNIT_TYPE_HELICOPTER] = "NET_UNIT_KILLED_FM",
    }
    exit = {
      [ES_UNIT_TYPE_AIRCRAFT]   = "NET_PLAYER_EXITED",
      [ES_UNIT_TYPE_TANK]       = "NET_PLAYER_EXITED",
      [ES_UNIT_TYPE_BOAT]       = "NET_PLAYER_EXITED",
      [ES_UNIT_TYPE_SHIP]       = "NET_PLAYER_EXITED",
      [ES_UNIT_TYPE_HELICOPTER] = "NET_PLAYER_EXITED",
    }
    air_defense = {
      [ES_UNIT_TYPE_AIRCRAFT]   = "NET_PLAYER_SHOT_BY_AIR_DEFENCE",
      [ES_UNIT_TYPE_TANK]       = "NET_PLAYER_SHOT_BY_AIR_DEFENCE",
      [ES_UNIT_TYPE_BOAT]       = "NET_PLAYER_SHOT_BY_AIR_DEFENCE",
      [ES_UNIT_TYPE_SHIP]       = "NET_PLAYER_SHOT_BY_AIR_DEFENCE",
      [ES_UNIT_TYPE_HELICOPTER] = "NET_PLAYER_SHOT_BY_AIR_DEFENCE",
    }
  }

  utToEsUnitType = { 
    [UT_Airplane]      = ES_UNIT_TYPE_AIRCRAFT,
    [UT_Balloon]       = ES_UNIT_TYPE_AIRCRAFT,
    [UT_Artillery]     = ES_UNIT_TYPE_TANK,
    [UT_HeavyVehicle]  = ES_UNIT_TYPE_TANK,
    [UT_LightVehicle]  = ES_UNIT_TYPE_TANK,
    [UT_Ship]          = ES_UNIT_TYPE_SHIP,
    [UT_WarObj]        = ES_UNIT_TYPE_TANK,
    [UT_InfTroop]      = ES_UNIT_TYPE_TANK,
    [UT_Fortification] = ES_UNIT_TYPE_TANK,
    [UT_AirWing]       = ES_UNIT_TYPE_AIRCRAFT,
    [UT_AirSquadron]   = ES_UNIT_TYPE_AIRCRAFT,
    


  }

  rePatternNumeric = regexp2("^\\d+$")

  
  escapeCodeToCssColor = [
    null                  
    "hudColorDarkRed"     
    null                  
    null                  
    "hudColorDarkBlue"    
    null                  
    null                  
    null                  
    null                  
    "hudColorRed"         
    "hudColorSquad"       
    "hudColorHero"        
    "hudColorBlue"        
    null                  
    null                  
    null                  
    "hudColorDeathAlly"   
    null                  
    null                  
    "hudColorDeathEnemy"  
    null                  
    null                  
  ]

  function init() {
    this.reset(true)

    g_hud_event_manager.subscribe("HudMessage", function(msg) {
        this.onHudMessage(msg)
      }, this)
  }

  function reset(safe = false) {
    if (safe && this.battleLog.len() && this.battleLog[this.battleLog.len() - 1].time < get_mission_time())
      return
    this.battleLog = []
    eventbus_send("clearBattleLog", {})
  }

  function onHudMessage(msg) {
    if (msg.type not in supportedMsgTypes)
      return

    if (!("id" in msg))
      msg.id <- -1
    if (!("text" in msg))
      msg.text <- ""

    let now = get_mission_time()
    if (msg.id != -1)
      foreach (logEntry in this.battleLog)
        if (logEntry.msg.id == msg.id)
          return
    if (msg.id == -1 && msg.text != "") {
      let skipDupTime = now - this.skipDuplicatesSec
      for (local i = this.battleLog.len() - 1; i >= 0; i--) {
        if (this.battleLog[i].time < skipDupTime)
          break
        if (this.battleLog[i].msg.text == msg.text)
          return
      }
    }

    let timestamp = $"{time.secondsToString(now, false)} "
    local message = ""
    local filters = 0
    if (msg.type == HUD_MSG_MULTIPLAYER_DMG) { 
      let p1 = get_mplayer_by_id(msg?.playerId ?? userIdInt64.value)
      let p2 = get_mplayer_by_id(msg?.victimPlayerId ?? userIdInt64.value)
      let t1Friendly = is_team_friendly(msg?.team ?? Team.A)
      let t2Friendly = is_team_friendly(msg?.victimTeam ?? Team.B)

      if (p1?.isLocal || p2?.isLocal)
        filters = filters | BATTLE_LOG_FILTER.HERO
      if (p1?.isInHeroSquad || p2?.isInHeroSquad)
        filters = filters | BATTLE_LOG_FILTER.SQUADMATE
      if (t1Friendly || t2Friendly)
        filters = filters | BATTLE_LOG_FILTER.ALLY
      if (!t1Friendly || !t2Friendly)
        filters = filters | BATTLE_LOG_FILTER.ENEMY
      if (filters == 0)
        filters = filters | BATTLE_LOG_FILTER.OTHER

      let text = this.msgMultiplayerDmgToText(msg, false, p1, p2)
      message = $"{timestamp}{colorize("userlogColoredText", text)}"
    }
    else {
      let player = get_mplayer_by_id(msg?.playerId ?? userIdInt64.value)
      let localPlayer = get_local_mplayer()
      if (msg.text.indexof("\x1B011") != null || player?.isLocal)
        filters = filters | BATTLE_LOG_FILTER.HERO
      if (msg.text.indexof("\x1B010") != null || player?.isInHeroSquad)
        filters = filters | BATTLE_LOG_FILTER.SQUADMATE
      if (msg.text.indexof("\x1B012") != null || (player?.team == localPlayer?.team))
        filters = filters | BATTLE_LOG_FILTER.ALLY
      if (msg.text.indexof("\x1B009") != null || (player?.team != localPlayer?.team))
        filters = filters | BATTLE_LOG_FILTER.ENEMY
      if (filters == 0)
        filters = filters | BATTLE_LOG_FILTER.OTHER

      if (msg.type == HUD_MSG_STREAK_EX) { 
        let text = this.msgStreakToText(msg)
        message = "".concat(timestamp,
          colorize("streakTextColor", "".concat(loc("unlocks/streak"), loc("ui/colon"), text)))
      }
    }

    let logEntry = {
      msg = msg
      time = now
      message = message
      filters = filters
    }

    if (this.battleLog.len() == this.logMaxLen)
      this.battleLog.remove(0)
    this.battleLog.append(logEntry)
    eventbus_send("pushBattleLogEntry", logEntry)
    broadcastEvent("BattleLogMessage", logEntry)
  }

  function getFilters() {
    return [
      { id = BATTLE_LOG_FILTER.ALL,   title = "chat/all" },
      { id = BATTLE_LOG_FILTER.SQUAD, title = "chat/squad" },
      { id = BATTLE_LOG_FILTER.HERO,  title = "debriefing/battle_log/filter/local_player" },
    ]
  }

  function getLength() {
    return this.battleLog.len()
  }

  function getText(filter = BATTLE_LOG_FILTER.ALL, limit = 0) {
    filter = filter || BATTLE_LOG_FILTER.ALL
    let lines = []
    for (local i = this.battleLog.len() - 1; i >= 0 ; i--)
      if (this.battleLog[i].filters & filter) {
        lines.insert(0, this.battleLog[i].message)
        if (limit && lines.len() == limit)
          break
      }
    return "\n".join(lines, true)
  }

  function buildPlayerUnitName(player, unitNameLoc = "") {
    if (unitNameLoc == "") {
      let unitId = player.aircraftName
      if (unitId != "")
        unitNameLoc = loc($"{unitId}_1")
    }
    return colorize(get_mplayer_color(player), unitNameLoc)
  }

  function getUnitNameEx(playerId, unitNameLoc = "", teamId = 0, player = null, withPlayerName = true) {
    player = player ?? get_mplayer_by_id(playerId)
    if(player == null)
      return colorize(get_team_color(teamId), unitNameLoc)

    if (is_replay_playing()) {
      player.isLocal = spectatorWatchedHero.id == player.id
      player.isInHeroSquad = isEqualSquadId(spectatorWatchedHero.squadId, player?.squadId)
    }

    let showNamesInKilllog = get_gui_option_in_mode(USEROPT_HUD_SHOW_NAMES_IN_KILLLOG, OPTIONS_MODE_GAMEPLAY, true)
    if(showNamesInKilllog && withPlayerName) {
      let showClan = get_gui_option_in_mode(USEROPT_HUD_SHOW_SQUADRON_NAMES_IN_KILLLOG, OPTIONS_MODE_GAMEPLAY, true)
      return buildMplayerName(player, true, showClan, true, unitNameLoc)
    }

    return this.buildPlayerUnitName(player, unitNameLoc)
  }

  function getUnitTypeEx(msg, isVictim = false) {
    let uType = getTblValue(isVictim ? "victimUnitType" : "unitType", msg)

    local res = getTblValue(uType, this.utToEsUnitType, ES_UNIT_TYPE_INVALID)
    if (res == ES_UNIT_TYPE_INVALID) { 
      let unit = getAircraftByName(msg[isVictim ? "victimUnitName" : "unitName"])
      if (unit)
        res = unit.esUnitType
    }

    return res
  }

  function getUnitTypeSuffix(unitType) {
    return getTblValue(unitType, this.unitTypeSuffix, this.unitTypeSuffix[ES_UNIT_TYPE_TANK])
  }

  function getActionTextIconic(msg) {
    let actionColor = (msg?.isKill ?? true) ? "userlogColoredText" : "silver"
    if((isShipBattle() || (getOwnerUnit()?.isShipOrBoat() ?? false))
        && get_gui_option_in_mode(USEROPT_HUD_SHOW_DEATH_REASON_IN_SHIP_KILLLOG, OPTIONS_MODE_GAMEPLAY, true)) {
      let deathReasonIcon = iconByDeathReason?[msg?.deathReason ?? DR_UNKNOWN] ?? iconByDeathReason[DR_UNKNOWN]
      return colorize(actionColor, deathReasonIcon)
    }

    let msgAction = msg?.action ?? "kill"
    local iconId = msgAction
    if (msgAction == "kill")
      iconId = "".concat(iconId, this.getUnitTypeSuffix(this.getUnitTypeEx(msg, false)))
    if (msgAction == "kill" || msgAction == "crash")
      iconId = "".concat(iconId, this.getUnitTypeSuffix(this.getUnitTypeEx(msg, true)))
    let icon = loc($"icon/hud_msg_mp_dmg/{iconId}")

    let killerProjectileKey = msg?.killerProjectileName ?? ""
    if (killerProjectileKey == "")
      return colorize(actionColor, icon)

    if(!get_gui_option_in_mode(USEROPT_HUD_SHOW_AMMO_TYPE_IN_KILLLOG, OPTIONS_MODE_GAMEPLAY, true))
      return colorize(actionColor, icon)

    let killerProjectileName = getProjectileNameLoc(killerProjectileKey)
    return colorize(actionColor, $"{icon}{killerProjectileName}")
  }

  function getActionTextVerbal(msg) {
    let victimUnitType = this.getUnitTypeEx(msg, true)
    let msgAction = msg?.action ?? "kill"
    let verb = getTblValue(victimUnitType, getTblValue(msgAction, this.actionVerbs, {}), msgAction)
    let isLoss = (msg?.victimTeam ?? get_player_army_for_hud()) == get_player_army_for_hud()
    return colorize(getActionColor(msg?.isKill ?? true, isLoss), loc(verb))
  }

  function msgMultiplayerDmgToText(msg, iconic = false, player = null, victimPlayer = null) {
    let what = iconic ? this.getActionTextIconic(msg) : this.getActionTextVerbal(msg)
    let who = this.getUnitNameEx(msg?.playerId ?? userIdInt64.value, msg?.unitNameLoc ?? userName.value, msg?.team ?? Team.A, player)
    let whom = this.getUnitNameEx(msg?.victimPlayerId ?? userIdInt64.value,
      msg?.victimUnitNameLoc ?? userName.value, msg?.victimTeam ?? Team.B, victimPlayer, msg?.withVictimPlayerName ?? true)

    let msgAction = msg?.action ?? "kill"
    let isCrash = msgAction == "crash" || msgAction == "exit" || msgAction == "air_defense"
    let sequence = isCrash ? [whom, what] : [who, what, whom]
    return " ".join(sequence, true)
  }

  function msgStreakToText(msg, forceThirdPerson = false) {
    let playerId = msg?.playerId ?? -1
    let localPlayerId = is_replay_playing() ? spectatorWatchedHero.id : get_local_mplayer().id
    let isLocal = !forceThirdPerson && playerId == localPlayerId
    let streakNameType = isLocal ? SNT_MY_STREAK_HEADER : SNT_OTHER_STREAK_TEXT
    let what = getLocForStreak(streakNameType, msg?.unlockId ?? "", msg?.stage ?? 0)
    return isLocal ? what : format("%s %s", this.getUnitNameEx(playerId), what)
  }

  function msgEscapeCodesToCssColors(sequence) {
    local ret = ""
    foreach (w in split_by_chars(sequence, "\x1B")) {
      if (w.len() >= 3 && this.rePatternNumeric.match(w.slice(0, 3))) {
        let color = getTblValue(w.slice(0, 3).tointeger(), this.escapeCodeToCssColor)
        let value = w.slice(3)
        ret = "".concat(ret, color ? colorize(color, value) : value)
      }
      else
        ret = "".concat(ret, w)
    }
    return ret
  }
}

return {
  HudBattleLog
}