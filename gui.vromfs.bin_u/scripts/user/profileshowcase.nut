from "%scripts/dagui_library.nut" import *

let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { g_difficulty } = require("%scripts/difficulty.nut")
let { hasAllFeatures } = require("%scripts/user/features.nut")
let { charSendBlk } = require("chard")
let { addTask } = require("%scripts/tasker.nut")
let DataBlock = require("DataBlock")
let { decimalFormat } = require("%scripts/langUtils/textFormat.nut")
let { isUnlockOpened } = require("%scripts/unlocks/unlocksModule.nut")
let lbDataType = require("%scripts/leaderboard/leaderboardDataType.nut")

let defaultShowcase = "favorite_mode"
let defaultShowcaseType = "air_arcade"

function getStatsValue(params, value, scorePeriod) {
  let gameType = params?.showcaseType ?? defaultShowcaseType
  let stats = params.stats?.leaderboard[gameType][scorePeriod]
  let val = stats?[value.valueId][scorePeriod] ?? 0
  return val == -1 ? 0 : val
}

function getPlayerKillsForMode(playerStats, mode) {
  let scorePeriod = "value_total"
  let stats = playerStats?.leaderboard[mode][scorePeriod]
  return (stats?.air_kills_player[scorePeriod] ?? 0)
    + (stats?.ground_kills_player[scorePeriod] ?? 0)
    + (stats?.naval_kills_player[scorePeriod] ?? 0)
}

function getAtomicAceValue(terseInfo) {
  return terseInfo?.showcase.atomic_ace__counter ?? 0
}

function getPeacefulAtomValue(terseInfo) {
  return terseInfo?.showcase.peacemaker__counter ?? 0
}

function getPosInLeaderboard(params, value, scorePeriod) {
  let gameType = params?.showcaseType ?? defaultShowcaseType
  let stats = params.stats?.leaderboard[gameType][scorePeriod]
  let stat = stats?[value.valueId]
  if (stat == null)
    return "-"

  foreach (lbCategory in ::leaderboards_list) {
    if (lbCategory.field == value.valueId) {
      let lbVal = stat.idx < 0 ? -1 : stat.idx + 1
      return lbCategory.getItemCell(lbVal, null, false, lbDataType.PLACE)?.text ?? "-"
    }
  }
  return "-"
}

let visibleValues = {
  battles = {
    type = "stat"
    icon = "lb_each_player_session"
    locId = "multiplayer/each_player_session"
    valueId = "each_player_session"
  },
  victories = {
    type = "stat"
    icon = "lb_each_player_victories"
    locId = "multiplayer/each_player_victories"
    valueId = "each_player_victories"
  },
  respawns = {
    type = "stat"
    icon = "lb_flyouts"
    locId = "multiplayer/flyouts"
    valueId = "flyouts"
  },
  playerVehicleDestroys = {
    type = "stat"
    icon = "lb_average_active_kills"
    locId = "multiplayer/lb_kills_player"
    valueId = "average_active_kills"
    getValue = @(params, _val) decimalFormat(getPlayerKillsForMode(params?.stats, params.showcaseType))
  },
  aiVehicleDestroys = {
    type = "stat"
    icon = "lb_average_script_kills"
    locId = "multiplayer/lb_kills_ai"
    valueId = "kills_ai"
  },
  totalScore = {
    type = "stat"
    icon = "lb_total_score"
    locId = "debriefing/totalscore"
    valueId = "score"
  },
  kill_by_spawns = {
    type = "stat"
    icon = "lb_average_active_kills_by_spawn"
    locId = "stats/average_active_kills_by_spawn"
    valueId = "average_active_kills_by_spawn"
  },
  ai_kill_by_spawns = {
    type = "stat"
    icon = "lb_average_script_kills_by_spawn"
    locId = "stats/average_script_kills_by_spawn"
    valueId = "score"
  },
  average_score = {
    type = "stat"
    icon = "lb_average_score"
    locId = "multiplayer/averageScore"
    valueId = "averageScore"
  },
  pvpRating = {
    type = "textStat"
    locId = "multiplayer/pvp_ratio_short"
    valueId = "pvp_ratio"
    getValue = @(params, val) $"{getStatsValue(params, val, "value_inhistory")}"
  },
  placeInLeaderboard = {
    type = "textStat"
    locId = "multiplayer/place_in_leaderboard"
    valueId = "pvp_ratio"
    getValue = @(params, val) getPosInLeaderboard(params, val, "value_inhistory")
  },
  atomic_ace = {
    type = "stat_big"
    icon = "!#ui/gameuiskin#atomic_ace_icon.svg"
    valueId = null
    getText = @(params) loc("showcase/nuclear_bombs_dropped", {num = getAtomicAceValue(params?.terseInfo)})
    getValue = @(params, _val) getAtomicAceValue(params?.terseInfo)
  },
  peaceful_atom = {
    type = "stat_big"
    icon = "!#ui/gameuiskin#peacemaker_icon.svg"
    valueId = null
    getText = @(params) loc("showcase/nuclear_carriers_shotdown", {num = getPeacefulAtomValue(params?.terseInfo)})
    getValue = @(params, _val) getPeacefulAtomValue(params?.terseInfo)
  }
}

let pageTypes = [
  {
    lines = [
      ["battles", "victories", "respawns"],
      ["playerVehicleDestroys", "aiVehicleDestroys", "totalScore"]
    ]
    blockedGameTypes = ["arcade", "historical", "simulation"]
    scorePeriod = "value_total"
    hasGameMode = true
    getShowCaseType = @(terseInfo, params = null)
      terseInfo?.showcase.mode ?? (params?.skipDefault ? null : defaultShowcaseType)
    terseName = "favorite_mode"
    locName = "showcase/favorite_mode"
    writeGameMode = @(terseInfo, mode) terseInfo.showcase.mode <- mode
    getSaveData = function(terseInfo) {
      let data = DataBlock()
      data.showcaseType <- "favorite_mode"
      data.favoriteMode <- terseInfo.showcase.mode
      return data
    }
  },
  {
    lines = [
      ["battles", "victories", "respawns"],
      ["kill_by_spawns", "ai_kill_by_spawns", "average_score"],
      ["pvpRating", "placeInLeaderboard"]
    ]
    blockedGameTypes = ["arcade", "historical", "simulation"]
    scorePeriod = "value_inhistory"
    hasGameMode = true
    getShowCaseType = @(terseInfo, params = null)
      terseInfo?.showcase.h_mode ?? (params?.skipDefault ? null : defaultShowcaseType)
    terseName = "battle_hardened"
    locName = "showcase/battle_hardened"
    writeGameMode = @(terseInfo, mode) terseInfo.showcase.h_mode <- mode
    getSaveData = function(terseInfo) {
      let data = DataBlock()
      data.showcaseType <- "battle_hardened"
      data.battleHardenedMode <- terseInfo.showcase.h_mode
      return data
    }
  },
  {
    lines = [
      ["atomic_ace"]
    ]
    hasGameMode = false
    getShowCaseType = @(_terseInfo, _params = null) null
    terseName = "atomic_ace"
    locName = "atomic_ace/name"
    hasOnlySecondTitle = true
    secondTitleLoc = "atomic_ace/name"
    isDisabled = @(_terseInfo) !isUnlockOpened("atomic_ace")
    hintForDisabled = @() "{\"id\":\"atomic_ace\",\"ttype\":\"UNLOCK_SHORT\"}"
    getSaveData = function(_terseInfo) {
      let data = DataBlock()
      data.showcaseType <- "atomic_ace"
      return data
    }
  },
  {
    lines = [
      ["peaceful_atom"]
    ]
    hasGameMode = false
    getShowCaseType = @(_terseInfo, _params = null) null
    terseName = "peacemaker"
    locName = "peacemaker/name"
    hasOnlySecondTitle = true
    secondTitleLoc = "peacemaker/name"
    isDisabled = @(_terseInfo) !isUnlockOpened("peacemaker")
    hintForDisabled = @() "{\"id\":\"peacemaker\",\"ttype\":\"UNLOCK_SHORT\"}"
    getSaveData = function(_terseInfo) {
      let data = DataBlock()
      data.showcaseType <- "peacemaker"
      return data
    }
  }
]

function getShowcaseByTerseInfo(terseInfo) {
  let terseName = (terseInfo?.schType ?? "") == "" ? defaultShowcase : terseInfo.schType
  return pageTypes.findvalue(@(showcase) showcase?.terseName == terseName)
}

function getShowcaseGameModes(blockedGameTypes) {
  let list = []
  foreach (mode in ::leaderboard_modes) {
    if (blockedGameTypes != null && blockedGameTypes.indexof(mode.mode) != null)
      continue
    let diffCode = mode?.diffCode
    if (!g_difficulty.isDiffCodeAvailable(diffCode, GM_DOMINATION))
      continue
    let reqFeature = mode?.reqFeature
    if (!hasAllFeatures(reqFeature))
      continue
    list.append(mode)
  }
  return list
}

function getGameMode(terseInfo, showcase = null) {
  showcase = showcase ?? getShowcaseByTerseInfo(terseInfo)
  if (!showcase?.hasGameMode)
    return null

  let modeName = showcase.getShowCaseType(terseInfo)
  let gameModes = getShowcaseGameModes(showcase?.blockedGameTypes)
  return gameModes.findvalue(@(mode) mode.mode == modeName)
}

function getShowcaseViewData(playerStats, terseInfo) {
  let showcase = getShowcaseByTerseInfo(terseInfo)
  if (!showcase)
    return null
  let statLines = []
  let modeLines = showcase.lines

  let showcaseType = showcase?.hasGameMode ? showcase?.getShowCaseType(terseInfo) : null
  let params = {stats = playerStats, showcaseType, terseInfo}

  foreach (line in modeLines) {
    let stats = []
    local idx = 0
    let statsBig = []
    let textStats = []

    foreach (valName in line) {
      let value = visibleValues[valName]
      if (value.type == "stat") {
        let statData = {icon = $"!#ui/gameuiskin#{value.icon}.svg", statName = value?.getText(params) ?? loc(value.locId), idx,
          statValue = $"{value?.getValue ? value.getValue(params, value) : decimalFormat(getStatsValue(params, value, showcase.scorePeriod))}"}
        stats.append(statData)
        idx++
        continue
      }
      if (value.type == "textStat") {
        let statData = {text = value?.getText(params) ?? loc(value.locId), value = value?.getValue(params, value)}
        textStats.append(statData)
        continue
      }
      if (value.type == "stat_big") {
        let statData = {icon = value.icon, statName = value?.getText(params) ?? loc(value.locId),
          statValue = $"{value?.getValue ? value.getValue(params, value) : decimalFormat(getStatsValue(params, value, showcase.scorePeriod))}"}
        statsBig.append(statData)
        continue
      }
    }
    let iconStatsCount = stats.len()
    if (iconStatsCount > 1) {
      stats[0].isLeftCell <- true
      stats[iconStatsCount-1].isRightCell <- true
      stats[iconStatsCount-1].isEndInRow <- true
    }

    statLines.append({stats, statsBig, textStats})
  }
  return handyman.renderCached("%gui/profile/profileMainPageMiddle.tpl", {statLines})
}

function getSecondModesViewData(showcase, terseInfo) {
  let list = getShowcaseGameModes(showcase?.blockedGameTypes)
  let data = []

  let gameMode = showcase.getShowCaseType(terseInfo)
  foreach (mode in list)
    data.append("".concat(
      "option {text:t='", mode.text, "'; mode:t='", mode.mode,
      "'; selected:t='", gameMode == mode ? "yes" : "no", "'}"
    ))

  return "".join(data)
}

function getShowcaseGameModeByIndex(index, terseInfo) {
  let showcase = getShowcaseByTerseInfo(terseInfo)
  if (!showcase?.hasGameMode)
    return null
  let gameModes = getShowcaseGameModes(showcase?.blockedGameTypes)
  return gameModes?[index]
}

function getShowcaseTypeBoxData(terseInfo) {
  let showcase = getShowcaseByTerseInfo(terseInfo)
  if (!showcase || !showcase.hasGameMode)
    return null
  let secondModesViewData = getSecondModesViewData(showcase, terseInfo)
  return secondModesViewData
}

function getGameModeBoxIndex(terseInfo) {
  let showcase = getShowcaseByTerseInfo(terseInfo)
  if (!showcase?.hasGameMode)
    return -1

  let list = getShowcaseGameModes(showcase?.blockedGameTypes)
  let gameMode = getGameMode(terseInfo, showcase)
  if (gameMode == null)
    return -1

  return list.findindex(@(mode) mode.mode == gameMode?.mode) ?? -1
}

function getEditViewData(terseInfo) {
  let showcase = getShowcaseByTerseInfo(terseInfo)
  let view = {}
  view.options <- []
  let boxFirstModes = {id = "box_first_modes", options = [], onSelect = "onShowcaseSelect"}
  foreach (idx, mode in pageTypes) {
    let option = {
      id = mode.terseName, text = loc(mode.locName),
      isDisabled = mode?.isDisabled(terseInfo) ? "yes" : null,
      hintForDisabled = mode?.hintForDisabled() ?? ""
    }
    if ((showcase == null && idx == 0) || showcase == mode)
      option.selected <- "yes"
    boxFirstModes.options.append(option)
  }

  view.options.append(boxFirstModes)
  return handyman.renderCached("%gui/profile/profileMainPageEdit.tpl", view)
}

function getShowcaseTitleViewData(terseInfo) {
  let terseName = (terseInfo?.schType ?? "") == "" ? defaultShowcase : terseInfo.schType
  let view = {}
  foreach (showcase in pageTypes)
    if (showcase?.terseName == terseName) {
      view.title <- showcase?.hasOnlySecondTitle ? " " : loc(showcase.locName)
      if (showcase?.secondTitleLoc)
        view.secondTitle <- loc(showcase.secondTitleLoc)
      else if (showcase.hasGameMode) {
        let gameMode = getGameMode(terseInfo, showcase)
        view.secondTitle <- loc(gameMode?.text ?? "")
      }
      break
    }
  return handyman.renderCached("%gui/profile/profileMainPageTitle.tpl", view)
}

function writeGameModeToTerseInfo(terseInfo, mode) {
  let showcase = getShowcaseByTerseInfo(terseInfo)
  if (!showcase?.hasGameMode)
    return
  showcase.writeGameMode(terseInfo, mode)
}

function saveShowcase(terseInfo, onSucsess, onError) {
  let showcase = getShowcaseByTerseInfo(terseInfo)
  if (!showcase)
    return
  let taskId = charSendBlk("cln_save_profile_showcase", showcase.getSaveData(terseInfo))
  addTask(taskId, { showProgressBox = true }, onSucsess, onError)
}

function trySetBestShowcaseMode(stats, terseInfo) {
  let showcase = getShowcaseByTerseInfo(terseInfo)
  if (!showcase || !showcase?.hasGameMode)
    return

  let gameMode = showcase.getShowCaseType(terseInfo, {skipDefault = true})
  //skip if gamemode already has in terseInfo
  if ((gameMode ?? "") != "")
    return

  let gameModes = getShowcaseGameModes(showcase?.blockedGameTypes)
  let checkValue = visibleValues.battles
  local maxValue = -1
  local bestMode = null

  foreach (mode in gameModes) {
    let val = getStatsValue({stats, showcaseType = mode.mode}, checkValue, showcase.scorePeriod)
    if (val > maxValue) {
      maxValue = val
      bestMode = mode
    }
  }
  if (bestMode)
    showcase.writeGameMode(terseInfo, bestMode.mode)
}

function getShowcaseByIndex(idx) {
  return pageTypes?[idx]
}

return {
  getShowcaseTitleViewData
  getEditViewData
  getShowcaseTypeBoxData
  getShowcaseViewData
  getShowcaseGameModeByIndex
  writeGameModeToTerseInfo
  saveShowcase
  getGameModeBoxIndex
  trySetBestShowcaseMode
  getShowcaseByIndex
  getShowcaseByTerseInfo
}