local enums = require("sqStdlibs/helpers/enums.nut")
local time = require("scripts/time.nut")
local stdMath = require("std/math.nut")


::g_mplayer_param_type <- {
  types = []
  cache = {
    byId = {}
  }
}

g_mplayer_param_type._substract <- function _substract(old, new) {
  return ::to_integer_safe(new) - ::to_integer_safe(old)
}

g_mplayer_param_type._newer <- function _newer(old, new) {
  return new
}

::g_mplayer_param_type.template <- {
  id = ""
  fontIcon = null
  tooltip = ""
  defVal = 0
  isForceUpdate = false // Force updates even when value not changed.
  missionObjective = MISSION_OBJECTIVE.ANY
  getVal = function(player) {
    return ::getTblValue(id, player, defVal)
  }
  printFunc = function(val, player) {
    return val != null ? val.tostring() : ""
  }
  getTooltip = function(val, player, defText) {
    return defText
  }
  getName = @(val = 0) ::loc(tooltip)
  diffFunc = ::g_mplayer_param_type._substract

  width = null
  relWidth = 10
  pareText = false
  updateSpecificMarkupParams = function(markupTbl) {}
  getMarkupData = function()
  {
    local res = {
      fontIcon = fontIcon
      tooltip = getName()
      pareText = pareText
    }

    if (width != null)
      res.width <- width
    else if (relWidth != 0)
      res.relWidth <- relWidth

    updateSpecificMarkupParams(res)
    return res
  }

  isVisible = function(objectivesMask, gameType, gameMode = ::GM_DOMINATION)
  {
    return ((missionObjective == MISSION_OBJECTIVE.ANY) || (missionObjective & objectivesMask) != 0)
      && isVisibleByGameType(gameType) && isVisibleByGameMode(gameMode)
  }
  isVisibleByGameType = @(gt) true
  isVisibleByGameMode = @(gm) true
}

enums.addTypesByGlobalName("g_mplayer_param_type", {
  UNKNOWN = {
  }

  NAME = {
    id = "name"
    tooltip = "multiplayer/name"
    defVal = ""
    printFunc = function(val, player) {
      return ::build_mplayer_name(player, false)
    }
    diffFunc = ::g_mplayer_param_type._newer
    width = "1@nameWidth + 1@tablePad"
    pareText = true
    updateSpecificMarkupParams = function(markupTbl)
    {
      markupTbl.widthInWideScreen <- "1@nameWidthInWideScreen + 1@tablePad"
      delete markupTbl.tooltip
    }
  }

  AIRCRAFT_NAME = {
    id = "aircraftName"
    tooltip = "options/unit"
    defVal = ""
    relWidth = 30
    pareText = true
    printFunc = function(val, player) {
      return ::getUnitName(val)
    }
    diffFunc = ::g_mplayer_param_type._newer
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
  }

  AIR_KILLS = {
    id = "kills"
    fontIcon = "#icon/mpstats/kills"
    tooltip = "multiplayer/air_kills"
    missionObjective = MISSION_OBJECTIVE.KILLS_AIR
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
    isVisibleByGameMode = @(gm) gm != ::GM_SKIRMISH
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
        res += ::getTblValue(aiKillsRowId, player, 0)
      return res
    }
    printFunc = function(val, player) {
      return getVal(player).tostring()
    }
  }

  ASSISTS = {
    id = "assists"
    fontIcon = "#icon/mpstats/assists"
    tooltip = "multiplayer/assists"
    isVisibleByGameType = @(gt) ::is_mode_with_teams(gt)
    getVal = function(player) {
      local res = 0
      foreach (rowId in [ "assists", "scoutKills" ])
        res += player?[rowId] ?? 0
      return res
    }
    printFunc = function(val, player) {
      return getVal(player).tostring()
    }
    getTooltip = function(val, player, defText) {
      if (!(player?.scoutKills ?? 0))
        return defText

      local rows = [
        { id = "assists",    label = "multiplayer/assists" }
        { id = "scoutKills", label = "multiplayer/scout_kills" }
      ]
      local res = []
      foreach (row in rows)
      {
        local rowVal = player?[row.id] ?? 0
        if (rowVal)
          res.append(::loc(row.label) + ::loc("ui/colon") + rowVal)
      }
      return ::g_string.implode(res, "\n")
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
    printFunc = function(val, player) {
      return stdMath.roundToDigits(val * ::KG_TO_TONS, 3).tostring()
    }
  }

  ROW_NO = {
    id = "rowNo"
    fontIcon = "#icon/mpstats/rowNo"
    tooltip = "multiplayer/place"
    diffFunc = ::g_mplayer_param_type._newer
  }

  RACE_LAST_CHECKPOINT = {
    id = "raceLastCheckpoint"
    fontIcon = "#icon/mpstats/raceLastCheckpoint"
    tooltip = "multiplayer/raceLastCheckpoint"
    relWidth = 15
    printFunc = function(val, player) {
      local total = ::get_race_checkpioints_count()
      local laps = ::get_race_laps_count()
      if (total && laps)
        val = (::max(val, 0) % (total / laps))
      return val.tostring()
    }
    diffFunc = ::g_mplayer_param_type._newer
  }

  RACE_LAST_CHECKPOINT_TIME = {
    id = "raceLastCheckpointTime"
    fontIcon = "#icon/mpstats/raceLastCheckpointTime"
    tooltip = "multiplayer/raceLastCheckpointTime"
    relWidth = 30
    defVal = -1
    printFunc = function(val, player) {
      return time.getRaceTimeFromSeconds(val)
    }
    diffFunc = ::g_mplayer_param_type._newer
  }

  RACE_LAP = {
    id = "raceLap"
    fontIcon = "#icon/mpstats/raceLap"
    tooltip = "multiplayer/raceLap"
    diffFunc = ::g_mplayer_param_type._newer
  }

  RACE_BEST_LAP_TIME = {
    id = "raceBestLapTime"
    tooltip = "multiplayer/each_player_fastlap"
    relWidth = 30
    defVal = -1
    printFunc = function(val, player) {
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
    isForceUpdate = true // Because it shows race completion percentage.
    printFunc = function(val, player) {
      if (val < 0)
      {
        local total = ::get_race_checkpioints_count()
        if (total)
          return (100 * ::getTblValue("raceLastCheckpoint", player, 0) / total).tointeger() + "%"
      }
      return time.getRaceTimeFromSeconds(val)
    }
    diffFunc = ::g_mplayer_param_type._newer
  }

  RACE_SAME_CHECKPOINT_TIME = {
    id = "raceSameCheckpointTime"
    relWidth = 30
  }

  RACE_PENALTY_TIME = {
    id = "penaltyTime"
    relWidth = 30
    defVal = 0
    printFunc = function(val, player) {
      if (val == 0)
        return ""

      return "".concat(val > 0 ? "+" : "", val, ::loc("debriefing/timeSec"))
    }
    getName = function(val = 0) {
      if (val >= 0)
        return ::loc("HUD_RACE_PENALTY_TIME")

      return ::loc("HUD_RACE_BONUS_TIME")
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
    fontIcon = "#icon/mpstats/assists"
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
    updateSpecificMarkupParams = function(markupTbl)
    {
      markupTbl.image <- "#ui/gameuiskin#table_squad_background"
      markupTbl.hideImage <- true
    }
  }

  ALIVE_TIME = {
    id = "missionAliveTime"
    tooltip = "multiplayer/lifetime"
    fontIcon = "#icon/timer"
    relWidth = 15
    missionObjective = MISSION_OBJECTIVE.ALIVE_TIME
    printFunc = @(val, player) time.secondsToString(val, false)
    isVisibleByGameType = @(gt) !!(gt & ::GT_LAST_MAN_STANDING)
  }
})

g_mplayer_param_type.getTypeById <- function getTypeById(id)
{
  return enums.getCachedType("id", id, ::g_mplayer_param_type.cache.byId,
    ::g_mplayer_param_type, ::g_mplayer_param_type.UNKNOWN)
}
