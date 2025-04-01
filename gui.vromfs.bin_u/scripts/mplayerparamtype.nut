from "%scripts/dagui_natives.nut" import get_race_checkpoints_count, get_race_laps_count
from "%scripts/dagui_library.nut" import *
import "%scripts/time.nut" as time
import "%sqstd/math.nut" as stdMath
from "%scripts/utils_sa.nut" import is_mode_with_teams

let { enumsAddTypes, getCachedType } = require("%sqStdLibs/helpers/enums.nut")
let { MISSION_OBJECTIVE } = require("%scripts/missions/missionsUtilsModule.nut")
let { getUnitName } = require("%scripts/unit/unitInfo.nut")

const KG_TO_TONS = 0.001

let expEventLocIds = {
  [EXP_EVENT_CAPTURE_ZONE]       = "expEventScore/captureZone",
  [EXP_EVENT_DESTROY_ZONE]       = "expEventScore/destroyZone",
  [EXP_EVENT_KILL]               = "expEventScore/kill",
  [EXP_EVENT_KILL_GROUND]        = "expEventScore/killGround",
  [EXP_EVENT_CRITICAL_HIT]       = "expEventScore/criticalHit",
  [EXP_EVENT_HIT]                = "expEventScore/hit",
  [EXP_EVENT_ASSIST]             = "expEventScore/assist",
  [EXP_EVENT_DAMAGE_ZONE]        = "expEventScore/damageZone",
  [EXP_EVENT_UNIT_DAMAGE]        = "expEventScore/unitDamage",
  [EXP_EVENT_SCOUT]              = "expEventScore/scout",
  [EXP_EVENT_SCOUT_CRITICAL_HIT] = "expEventScore/scoutCriticalHit",
  [EXP_EVENT_SCOUT_KILL]         = "expEventScore/scoutKill",
  [EXP_EVENT_SCOUT_KILL_UNKNOWN] = "expEventScore/scoutKillUnknown",
  [EXP_EVENT_DEATH]              = "expEventScore/death",
  [EXP_EVENT_MISSION_ACTION]     = "expEventScore/missionAction",
  [EXP_EVENT_HELP_TO_ALLIES]     = "expEventScore/helpToAllies",
  [EXP_EVENT_SEVERE_DAMAGE]      = "expEventScore/severeDamage",
  [EXP_EVENT_MISSILE_EVADE]      = "expEventScore/missileEvade",
  [EXP_EVENT_SHELL_INTERCEPTION] = "expEventScore/shellInterception",
  [EXP_EVENT_KILL_HUMAN]         = "expEventScore/killHuman",
}

let g_mplayer_param_type = {
  types = []
  cache = {
    byId = {}
  }
}

g_mplayer_param_type._substract <- function _substract(old, new) {
  return to_integer_safe(new) - to_integer_safe(old)
}

g_mplayer_param_type._newer <- function _newer(_old, new) {
  return new
}

g_mplayer_param_type.template <- {
  id = ""
  fontIcon = null
  tooltip = ""
  defVal = 0
  isForceUpdate = false 
  missionObjective = MISSION_OBJECTIVE.ANY
  getVal = function(player) {
    return getTblValue(this.id, player, this.defVal)
  }
  printFunc = function(val, _player) {
    return val != null ? val.tostring() : ""
  }
  getTooltip = function(_val, _player, defText) {
    return defText
  }
  getName = @(_val = 0) loc(this.tooltip)
  diffFunc = g_mplayer_param_type._substract

  width = null
  relWidth = 10
  pareText = false
  updateSpecificMarkupParams = function(_markupTbl) {}
  getMarkupData = function() {
    let res = {
      fontIcon = this.fontIcon
      tooltip = this.getName()
      pareText = this.pareText
    }

    if (this.width != null)
      res.width <- this.width
    else if (this.relWidth != 0)
      res.relWidth <- this.relWidth

    this.updateSpecificMarkupParams(res)
    return res
  }

  isVisible = function(objectivesMask, gameType, gameMode = GM_DOMINATION) {
    return ((this.missionObjective == MISSION_OBJECTIVE.ANY) || (this.missionObjective & objectivesMask) != 0)
      && this.isVisibleByGameType(gameType) && this.isVisibleByGameMode(gameMode)
  }
  isVisibleByGameType = @(_gt) true
  isVisibleByGameMode = @(_gm) true
}

enumsAddTypes(g_mplayer_param_type, {
  UNKNOWN = {
  }

  NAME = {
    id = "name"
    tooltip = "multiplayer/name"
    defVal = ""
    printFunc = function(_val, player) {
      return ::build_mplayer_name(player, false)
    }
    diffFunc = g_mplayer_param_type._newer
    width = "1@nameWidth + 1@tablePad"
    pareText = true
    updateSpecificMarkupParams = function(markupTbl) {
      markupTbl.widthInWideScreen <- "1@nameWidthInWideScreen + 1@tablePad"
      markupTbl.$rawdelete("tooltip")
    }
  }

  AIRCRAFT_NAME = {
    id = "aircraftName"
    tooltip = "options/unit"
    defVal = ""
    relWidth = 30
    pareText = true
    printFunc = function(val, _player) {
      return getUnitName(val)
    }
    diffFunc = g_mplayer_param_type._newer
  }

  AIRCRAFT = {
    id = "aircraft"
    relWidth = 30
    pareText = true
  }

  SCORE = {
    id = "score"
    fontIcon = "#icon/mpstats/score"
    tooltip = "multiplayer/score"
    relWidth = 25
    missionObjective = ~MISSION_OBJECTIVE.WITHOUT_SCORE

    getTooltip = function(_val, player, _defText) {
      let res = []
      for (local i = 0; i < EXP_EVENT_TOTAL; i++) {
        let rowVal = player?.scoreForExpEvents[$"event{i}"] ?? 0
        if (rowVal <= 0)
          continue
        let evLocId = expEventLocIds?[i] ?? ""
        if (evLocId == "")
          continue
        res.append("".concat(loc(evLocId), loc("ui/colon"), rowVal))
      }
      res.append("".concat(loc("expEventScore/total"), loc("ui/colon"), (player?.score ?? 0)))
      return "\n".join(res)
    }
  }

  AIR_KILLS = {
    id = "kills"
    fontIcon = "#icon/mpstats/kills"
    tooltip = "multiplayer/air_kills"
    missionObjective = MISSION_OBJECTIVE.KILLS_AIR
    printFunc = function(val, player) {
      local valStr = this.getVal(player).tostring()
      let airSevereDamageCount = player?.airSevereDamage ?? 0
      if (airSevereDamageCount > 0)
        valStr = $"{val}+{airSevereDamageCount}"
      return valStr
    }
    getTooltip = function(_val, player, defText) {
      if ((player?.airSevereDamage ?? 0) == 0)
        return defText

      let rows = [
        { id = "kills",           label = "multiplayer/air_kills" }
        { id = "airSevereDamage", label = "multiplayer/severe_damage" }
      ]
      let res = []
      foreach (row in rows) {
        let rowVal = player?[row.id] ?? 0
        if (rowVal)
          res.append("".concat(loc(row.label), loc("ui/colon"), rowVal))
      }
      return "\n".join(res, true)
    }
  }

  GROUND_KILLS = {
    id = "groundKills"
    fontIcon = "#icon/mpstats/groundKills"
    tooltip = "multiplayer/ground_kills"
    missionObjective = MISSION_OBJECTIVE.KILLS_GROUND
  }

  NAVAL_DAMAGE = {
    id = "awardDamage"
    fontIcon = "#icon/mpstats/navalDamage"
    tooltip = "multiplayer/naval_damage"
    relWidth = 25
    missionObjective = MISSION_OBJECTIVE.KILLS_NAVAL
    isVisibleByGameMode = @(gm) gm != GM_SKIRMISH
  }

  NAVAL_KILLS = {
    id = "navalKills"
    fontIcon = "#icon/mpstats/navalKills"
    tooltip = "multiplayer/naval_kills"
    missionObjective = MISSION_OBJECTIVE.KILLS_NAVAL
  }

  AI_AIR_KILLS = {
    id = "aiKills"
    fontIcon = "#icon/mpstats/aiKills"
    tooltip = "multiplayer/air_kills_ai"
    missionObjective = MISSION_OBJECTIVE.KILLS_AIR_AI
  }

  AI_GROUND_KILLS = {
    id = "aiGroundKills"
    fontIcon = "#icon/mpstats/aiGroundKills"
    tooltip = "multiplayer/ground_kills_ai"
    missionObjective = MISSION_OBJECTIVE.KILLS_GROUND_AI
  }

  AI_NAVAL_KILLS = {
    id = "aiNavalKills"
    fontIcon = "#icon/mpstats/aiNavalKills"
    tooltip = "multiplayer/naval_kills_ai"
    missionObjective = MISSION_OBJECTIVE.KILLS_NAVAL_AI
  }

  AI_TOTAL_KILLS = {
    id = "aiTotalKills"
    fontIcon = "#icon/mpstats/aiTotalKills"
    tooltip = "multiplayer/total_kills_ai"
    missionObjective = MISSION_OBJECTIVE.KILLS_TOTAL_AI
    getVal = function(player) {
      local res = 0
      foreach (aiKillsRowId in [ "aiKills", "aiGroundKills", "aiNavalKills" ])
        res += getTblValue(aiKillsRowId, player, 0)
      return res
    }
    printFunc = function(_val, player) {
      return this.getVal(player).tostring()
    }
    getTooltip = function(_val, player, defText) {
      let rows = [
        { id = "aiKills",         label = "multiplayer/air_kills_ai" }
        { id = "aiGroundKills",   label = "multiplayer/ground_kills_ai" }
        { id = "aiNavalKills",    label = "multiplayer/naval_kills_ai" }
      ]
      let res = []
      foreach (row in rows) {
        let rowVal = player?[row.id] ?? 0
        if (rowVal)
          res.append($"{loc(row.label)}{loc("ui/colon")}{rowVal}")
      }
      if (res.len() == 0)
        return defText
      return "\n".join(res, true)
    }
  }

  ASSISTS = {
    id = "assists"
    fontIcon = "#icon/mpstats/assists"
    tooltip = "multiplayer/assists"
    missionObjective = MISSION_OBJECTIVE.KILLS_ANY | MISSION_OBJECTIVE.KILLS_ANY_AI
    isVisibleByGameType = @(gt) is_mode_with_teams(gt)
    getVal = function(player) {
      local res = 0
      foreach (rowId in [ "assists", "scoutKills" ])
        res += player?[rowId] ?? 0
      return res
    }
    printFunc = function(_val, player) {
      return this.getVal(player).tostring()
    }
    getTooltip = function(_val, player, defText) {
      if (!(player?.scoutKills ?? 0))
        return defText

      let rows = [
        { id = "assists",    label = "multiplayer/assists" }
        { id = "scoutKills", label = "multiplayer/scout_kills" }
      ]
      let res = []
      foreach (row in rows) {
        let rowVal = player?[row.id] ?? 0
        if (rowVal)
          res.append("".concat(loc(row.label), loc("ui/colon"), rowVal))
      }
      return "\n".join(res, true)
    }
  }

  MISSILE_EVADES = {
    id = "missileEvade"
    fontIcon = "#icon/mpstats/missileEvade"
    tooltip = "multiplayer/missileEvade"
    getVal = function(player) {
      return player?["missileEvades"] ?? 0
    }
    printFunc = function(_val, player) {
      return this.getVal(player).tostring()
    }
  }

  SHELL_INTERCEPTIONS = {
    id = "shellInterception"
    fontIcon = "#icon/mpstats/shellInterception"
    tooltip = "multiplayer/shellInterception"
    getVal = function(player) {
      return player?["shellInterceptions"] ?? 0
    }
    printFunc = function(_val, player) {
      return this.getVal(player).tostring()
    }
  }

  DEATHS = {
    id = "deaths"
    fontIcon = "#icon/mpstats/deaths"
    tooltip = "multiplayer/deaths"
  }

  CAPTURE_ZONE = {
    id = "captureZone"
    fontIcon = "#icon/mpstats/captureZone"
    tooltip = "multiplayer/zone_captures"
    missionObjective = MISSION_OBJECTIVE.ZONE_CAPTURE
  }

  DAMAGE_ZONE = {
    id = "damageZone"
    fontIcon = "#icon/mpstats/damageZone"
    tooltip = "debriefing/Damage"
    relWidth = 15
    missionObjective = MISSION_OBJECTIVE.ZONE_BOMBING
    printFunc = function(val, _player) {
      return stdMath.roundToDigits(val * KG_TO_TONS, 3).tostring()
    }
  }

  ROW_NO = {
    id = "rowNo"
    fontIcon = "#icon/mpstats/rowNo"
    tooltip = "multiplayer/place"
    diffFunc = g_mplayer_param_type._newer
  }

  RACE_LAST_CHECKPOINT = {
    id = "raceLastCheckpoint"
    fontIcon = "#icon/mpstats/raceLastCheckpoint"
    tooltip = "multiplayer/raceLastCheckpoint"
    relWidth = 15
    printFunc = function(val, _player) {
      let total = get_race_checkpoints_count()
      let laps = get_race_laps_count()
      if (total && laps)
        val = (max(val, 0) % (total / laps))
      return val.tostring()
    }
    diffFunc = g_mplayer_param_type._newer
  }

  RACE_LAST_CHECKPOINT_TIME = {
    id = "raceLastCheckpointTime"
    fontIcon = "#icon/mpstats/raceLastCheckpointTime"
    tooltip = "multiplayer/raceLastCheckpointTime"
    relWidth = 30
    defVal = -1
    printFunc = function(val, _player) {
      return time.getRaceTimeFromSeconds(val)
    }
    diffFunc = g_mplayer_param_type._newer
  }

  RACE_LAP = {
    id = "raceLap"
    fontIcon = "#icon/mpstats/raceLap"
    tooltip = "multiplayer/raceLap"
    diffFunc = g_mplayer_param_type._newer
  }

  RACE_BEST_LAP_TIME = {
    id = "raceBestLapTime"
    tooltip = "multiplayer/each_player_fastlap"
    relWidth = 30
    defVal = -1
    printFunc = function(val, _player) {
      return time.getRaceTimeFromSeconds(val)
    }
    diffFunc = function(old, new) {
      return old != new ? new : -1
    }
  }

  RACE_FINISH_TIME = {
    id = "raceFinishTime"
    tooltip = "HUD_RACE_FINISH"
    relWidth = 30
    defVal = -1
    isForceUpdate = true 
    printFunc = function(val, player) {
      if (val < 0) {
        let total = get_race_checkpoints_count()
        if (total)
          return "".concat((100 * getTblValue("raceLastCheckpoint", player, 0) / total).tointeger(), "%")
      }
      return time.getRaceTimeFromSeconds(val)
    }
    diffFunc = g_mplayer_param_type._newer
  }

  RACE_SAME_CHECKPOINT_TIME = {
    id = "raceSameCheckpointTime"
    relWidth = 30
  }

  RACE_PENALTY_TIME = {
    id = "penaltyTime"
    relWidth = 30
    defVal = 0
    printFunc = function(val, _player) {
      if (val == 0)
        return ""

      return "".concat(val > 0 ? "+" : "", val, loc("debriefing/timeSec"))
    }
    getName = function(val = 0) {
      if (val >= 0)
        return loc("HUD_RACE_PENALTY_TIME")

      return loc("HUD_RACE_BONUS_TIME")
    }
  }

  FOOTBALL_GOALS = {
    id = "footballGoals"
    fontIcon = "#icon/mpstats/football_goals"
    tooltip = "multiplayer/football/goals"
    relWidth = 10
  }

  FOOTBALL_ASSISTS = {
    id = "footballAssists"
    fontIcon = "#icon/mpstats/football_assists"
    tooltip = "multiplayer/football/assists"
    relWidth = 10
  }

  FOOTBALL_SAVES = {
    id = "footballSaves"
    fontIcon = "#icon/mpstats/football_saves"
    tooltip = "multiplayer/football/saves"
    relWidth = 10
  }

  FOOTBALL_SCORE = {
    id = "footballScore"
    fontIcon = "#icon/mpstats/score"
    tooltip = "multiplayer/score"
    relWidth = 15
  }

  UNIT_ICON = {
    id = "unitIcon"
    width = "1.5@tableIcoSize"
  }

  SQUAD = {
    id = "squad"
    width = "1@tableIcoSize"
    updateSpecificMarkupParams = function(markupTbl) {
      markupTbl.image <- "#ui/gameuiskin#table_squad_background.svg"
      markupTbl.hideImage <- true
    }
  }

  ALIVE_TIME = {
    id = "missionAliveTime"
    tooltip = "multiplayer/lifetime"
    fontIcon = "#icon/timer"
    relWidth = 15
    missionObjective = MISSION_OBJECTIVE.ALIVE_TIME
    printFunc = @(val, _player) time.secondsToString(val, false)
    isVisibleByGameType = @(gt) !!(gt & GT_LAST_MAN_STANDING)
  }
})

g_mplayer_param_type.getTypeById <- function getTypeById(id) {
  return getCachedType("id", id, g_mplayer_param_type.cache.byId,
    g_mplayer_param_type, g_mplayer_param_type.UNKNOWN)
}
return {g_mplayer_param_type}
