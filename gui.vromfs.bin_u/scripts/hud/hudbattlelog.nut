//-file:plus-string
from "%scripts/dagui_library.nut" import *
from "hudMessages" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { format, split_by_chars } = require("string")
let regexp2 = require("regexp2")
let time = require("%scripts/time.nut")
let spectatorWatchedHero = require("%scripts/replays/spectatorWatchedHero.nut")
let { is_replay_playing } = require("replays")
let { PERSISTENT_DATA_PARAMS } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")
let { send } = require("eventbus")
let { doesLocTextExist } = require("dagor.localize")

enum BATTLE_LOG_FILTER {
  HERO      = 0x0001
  SQUADMATE = 0x0002
  ALLY      = 0x0004
  ENEMY     = 0x0008
  OTHER     = 0x0010

  SQUAD     = 0x0003
  ALL       = 0x001F
}

::HudBattleLog <- {
  [PERSISTENT_DATA_PARAMS] = ["battleLog"]

  battleLog = []

  logMaxLen = 2000
  skipDuplicatesSec = 10

  supportedMsgTypes = [
    HUD_MSG_MULTIPLAYER_DMG
    HUD_MSG_STREAK_EX
    HUD_MSG_STREAK
  ]

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
    bullet = {
      [ES_UNIT_TYPE_AIRCRAFT]   = "NET_UNIT_KILLED_FM",
      [ES_UNIT_TYPE_TANK]       = "NET_UNIT_KILLED_GM",
      [ES_UNIT_TYPE_BOAT]       = "NET_UNIT_KILLED_GM",
      [ES_UNIT_TYPE_SHIP]       = "NET_UNIT_KILLED_GM",
      [ES_UNIT_TYPE_HELICOPTER] = "NET_UNIT_KILLED_FM",
    }
    shell = {
      [ES_UNIT_TYPE_AIRCRAFT]   = "NET_UNIT_KILLED_FM",
      [ES_UNIT_TYPE_TANK]       = "NET_UNIT_KILLED_GM",
      [ES_UNIT_TYPE_BOAT]       = "NET_UNIT_KILLED_GM",
      [ES_UNIT_TYPE_SHIP]       = "NET_UNIT_KILLED_GM",
      [ES_UNIT_TYPE_HELICOPTER] = "NET_UNIT_KILLED_FM",
    }
    crash = {
      [ES_UNIT_TYPE_AIRCRAFT]   = "NET_PLAYER_HAS_CRASHED",
      [ES_UNIT_TYPE_TANK]       = "NET_PLAYER_GM_HAS_DESTROYED",
      [ES_UNIT_TYPE_BOAT]       = "NET_PLAYER_GM_HAS_DESTROYED",
      [ES_UNIT_TYPE_SHIP]       = "NET_PLAYER_GM_HAS_DESTROYED",
      [ES_UNIT_TYPE_HELICOPTER] = "NET_PLAYER_HAS_CRASHED",
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
  }

  utToEsUnitType = { //!!FIX ME: better to set different icons fot each unitType
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
    //


  }

  rePatternNumeric = regexp2("^\\d+$")

  // http://en.wikipedia.org/wiki/ANSI_escape_code#Colors
  escapeCodeToCssColor = [
    null                  //  0   ECT_BLACK
    "hudColorDarkRed"     //  1   ECT_DARK_RED        HC_DARK_RED
    null                  //  2   ECT_DARK_GREEN
    null                  //  3   ECT_DARK_YELLOW
    "hudColorDarkBlue"    //  4   ECT_DARK_BLUE       HC_DARK_BLUE
    null                  //  5   ECT_DARK_MAGENTA
    null                  //  6   ECT_DARK_CYAN
    null                  //  7   ECT_GREY
    null                  //  8   ECT_DARK_GREY
    "hudColorRed"         //  9   ECT_RED             HC_RED
    "hudColorSquad"       // 10   ECT_GREEN           HC_SQUAD
    "hudColorHero"        // 11   ECT_YELLOW          HC_HERO
    "hudColorBlue"        // 12   ECT_BLUE            HC_BLUE
    null                  // 13   ECT_MAGENTA
    null                  // 14   ECT_CYAN
    null                  // 15   ECT_WHITE
    "hudColorDeathAlly"   // 16   ECT_LIGHT_RED       HC_DEATH_ALLY
    null                  // 17   ECT_LIGHT_GREEN
    null                  // 18   ECT_LIGHT_YELLOW
    "hudColorDeathEnemy"  // 19   ECT_LIGHT_BLUE      HC_DEATH_ENEMY
    null                  // 20   ECT_LIGHT_MAGENTA
    null                  // 21   ECT_LIGHT_CYAN
  ]

  function init() {
    this.reset(true)

    ::g_hud_event_manager.subscribe("HudMessage", function(msg) {
        this.onHudMessage(msg)
      }, this)
  }

  function reset(safe = false) {
    if (safe && this.battleLog.len() && this.battleLog[this.battleLog.len() - 1].time < ::get_usefull_total_time())
      return
    this.battleLog = []
    send("clearBattleLog", {})
  }

  function onHudMessage(msg) {
    if (!isInArray(msg.type, this.supportedMsgTypes))
      return

    if (!("id" in msg))
      msg.id <- -1
    if (!("text" in msg))
      msg.text <- ""

    let now = ::get_usefull_total_time()
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

    local filters = 0
    if (msg.type == HUD_MSG_MULTIPLAYER_DMG) {
      let p1 = ::get_mplayer_by_id(msg?.playerId ?? ::my_user_id_int64)
      let p2 = ::get_mplayer_by_id(msg?.victimPlayerId ?? ::my_user_id_int64)
      let t1Friendly = ::is_team_friendly(msg?.team ?? Team.A)
      let t2Friendly = ::is_team_friendly(msg?.victimTeam ?? Team.B)

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
    }
    else {
      let player = ::get_mplayer_by_id(msg?.playerId ?? ::my_user_id_int64)
      let localPlayer = ::get_local_mplayer()
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
    }

    let timestamp = time.secondsToString(now, false) + " "
    local message = ""
    switch (msg.type) {
      // All players messages
      case HUD_MSG_MULTIPLAYER_DMG: // Any player unit damaged or destroyed
        let text = this.msgMultiplayerDmgToText(msg)
        message = timestamp + colorize("userlogColoredText", text)
        break
      case HUD_MSG_STREAK_EX: // Any player got streak
        let text = this.msgStreakToText(msg)
        message = timestamp + colorize("streakTextColor", loc("unlocks/streak") + loc("ui/colon") + text)
        break
      default:
        return
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
    send("pushBattleLogEntry", logEntry)
    ::broadcastEvent("BattleLogMessage", logEntry)
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
    return ::g_string.implode(lines, "\n")
  }

  function getUnitNameEx(playerId, unitNameLoc = "", teamId = 0) {
    let player = ::get_mplayer_by_id(playerId)
    if (player && is_replay_playing()) {
      player.isLocal = spectatorWatchedHero.id == player.id
      player.isInHeroSquad = ::SessionLobby.isEqualSquadId(spectatorWatchedHero.squadId, player?.squadId)
    }
    return player ? ::build_mplayer_name(player, true, true, true, unitNameLoc) : // Player
      colorize(::get_team_color(teamId), unitNameLoc) // AI
  }

  function getUnitTypeEx(msg, isVictim = false) {
    let uType = getTblValue(isVictim ? "victimUnitType" : "unitType", msg)

    local res = getTblValue(uType, this.utToEsUnitType, ES_UNIT_TYPE_INVALID)
    if (res == ES_UNIT_TYPE_INVALID) { //we do not receive unitType for player killer unit, but can easy get it by unitName
      let unit = ::getAircraftByName(msg[isVictim ? "victimUnitName" : "unitName"])
      if (unit)
        res = unit.esUnitType
    }

    return res
  }

  function getUnitTypeSuffix(unitType) {
    return getTblValue(unitType, this.unitTypeSuffix, this.unitTypeSuffix[ES_UNIT_TYPE_TANK])
  }

  function getActionTextIconic(msg) {
    let msgAction = msg?.action ?? "kill"
    local iconId = msgAction
    if (msgAction == "kill")
      iconId += this.getUnitTypeSuffix(this.getUnitTypeEx(msg, false))
    if (msgAction == "kill" || msgAction == "crash")
      iconId += this.getUnitTypeSuffix(this.getUnitTypeEx(msg, true))
    let icon = loc($"icon/hud_msg_mp_dmg/{iconId}")
    let actionColor = msg?.isKill ?? true ? "userlogColoredText" : "silver"

    let killerProjectileKey = msg?.killerProjectileName ?? ""
    if (killerProjectileKey == "")
      return colorize(actionColor, icon)

    let killerProjectileName = doesLocTextExist(killerProjectileKey)
      ? loc(killerProjectileKey)
      : loc($"weapons/{killerProjectileKey}/short", "")

    return colorize(actionColor, $"{icon}{killerProjectileName}")
  }

  function getActionTextVerbal(msg) {
    let victimUnitType = this.getUnitTypeEx(msg, true)
    let msgAction = msg?.action ?? "kill"
    let verb = getTblValue(victimUnitType, getTblValue(msgAction, this.actionVerbs, {}), msgAction)
    let isLoss = (msg?.victimTeam ?? ::get_player_army_for_hud()) == ::get_player_army_for_hud()
    let color = "hudColor" + (msg?.isKill ?? true ? (isLoss ? "DeathAlly" : "DeathEnemy") : (isLoss ? "DarkRed" : "DarkBlue"))
    return colorize(color, loc(verb))
  }

  function msgMultiplayerDmgToText(msg, iconic = false) {
    let what = iconic ? this.getActionTextIconic(msg) : this.getActionTextVerbal(msg)
    let who  = this.getUnitNameEx(msg?.playerId ?? ::my_user_id_int64, msg?.unitNameLoc ?? ::my_user_name, msg?.team ?? Team.A)
    let whom = this.getUnitNameEx(msg?.victimPlayerId ?? ::my_user_id_int64, msg?.victimUnitNameLoc ?? ::my_user_name, msg?.victimTeam ?? Team.B)

    let msgAction = msg?.action ?? "kill"
    let isCrash = msgAction == "crash" || msgAction == "exit"
    let sequence = isCrash ? [whom, what] : [who, what, whom]
    return ::g_string.implode(sequence, " ")
  }

  function msgStreakToText(msg, forceThirdPerson = false) {
    let playerId = msg?.playerId ?? -1
    let localPlayerId = is_replay_playing() ? spectatorWatchedHero.id : ::get_local_mplayer().id
    let isLocal = !forceThirdPerson && playerId == localPlayerId
    let streakNameType = isLocal ? SNT_MY_STREAK_HEADER : SNT_OTHER_STREAK_TEXT
    let what = ::get_loc_for_streak(streakNameType, msg?.unlockId ?? "", msg?.stage ?? 0)
    return isLocal ? what : format("%s %s", this.getUnitNameEx(playerId), what)
  }

  function msgEscapeCodesToCssColors(sequence) {
    local ret = ""
    foreach (w in split_by_chars(sequence, "\x1B")) {
      if (w.len() >= 3 && this.rePatternNumeric.match(w.slice(0, 3))) {
        let color = getTblValue(w.slice(0, 3).tointeger(), this.escapeCodeToCssColor)
        let value = w.slice(3)
        ret += color ? colorize(color, value) : value
      }
      else
        ret += w
    }
    return ret
  }
}

::g_script_reloader.registerPersistentDataFromRoot("HudBattleLog")
