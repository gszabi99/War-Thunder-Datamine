from "%scripts/dagui_library.nut" import *

let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { g_difficulty } = require("%scripts/difficulty.nut")
let { hasAllFeatures } = require("%scripts/user/features.nut")
let { charSendBlk } = require("chard")
let { addTask } = require("%scripts/tasker.nut")
let DataBlock = require("DataBlock")

let defaultShowcase = "favorite_mode"
let defaultShowcaseType = "air_arcade"

function getStatsValue(params, value, scorePeriod) {
  let gameType = params?.showcaseType ?? defaultShowcaseType
  let stats = params.stats.leaderboard?[gameType][scorePeriod]
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

let visibleValues = {
  battles = {
    type = "stat"
    icon = "lb_each_player_session"
    locId = "multiplayer/each_player_session"
    valueId = "each_player_session"
  }
  victories = {
    type = "stat"
    icon = "lb_each_player_victories"
    locId = "multiplayer/each_player_victories"
    valueId = "each_player_victories"
  }
  respawns = {
    type = "stat"
    icon = "lb_flyouts"
    locId = "multiplayer/flyouts"
    valueId = "flyouts"
  }
  playerVehicleDestroys = {
    type = "stat"
    icon = "lb_average_active_kills"
    locId = "multiplayer/lb_kills_player"
    valueId = "average_active_kills"
    getValue = @(params, _val) getPlayerKillsForMode(params?.stats, params.showcaseType)
  }
  aiVehicleDestroys = {
    type = "stat"
    icon = "lb_average_script_kills"
    locId = "multiplayer/lb_kills_ai"
    valueId = "kills_ai"
  }
  totalScore = {
    type = "stat"
    icon = "lb_total_score"
    locId = "debriefing/totalscore"
    valueId = "score"
  }
  kill_by_spawns = {
    type = "stat"
    icon = "lb_average_active_kills_by_spawn"
    locId = "stats/average_active_kills_by_spawn"
    valueId = "average_active_kills_by_spawn"
  }
  ai_kill_by_spawns = {
    type = "stat"
    icon = "lb_average_script_kills_by_spawn"
    locId = "stats/average_script_kills_by_spawn"
    valueId = "score"
  }
  average_score = {
    type = "stat"
    icon = "lb_average_score"
    locId = "multiplayer/averageScore"
    valueId = "averageScore"
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
  let params = {stats = playerStats, showcaseType}

  foreach (line in modeLines) {
    let stats = []

    foreach (valName in line) {
      let value = visibleValues[valName]
      if (value.type == "stat") {
        let statData = {icon = $"!#ui/gameuiskin#{value.icon}.svg", statName = loc(value.locId),
          statValue = $"{value?.getValue ? value.getValue(params, value) : getStatsValue(params, value, showcase.scorePeriod)}"}
        stats.append(statData)
        continue
      }
    }
    let iconStatsCount = stats.len()
    if (iconStatsCount > 1) {
      stats[0].isLeftCell <- true
      stats[iconStatsCount-1].isRightCell <- true
      stats[iconStatsCount-1].isEndInRow <- true
    }

    statLines.append({stats})
  }
  return handyman.renderCached("%gui/profile/profileMainPageMiddle.tpl", {statLines})
}

function getSecondModesViewData(showcase) {
  let list = getShowcaseGameModes(showcase?.blockedGameTypes)
  let data = []
  foreach (mode in list)
    data.append("".concat("option {text:t='", mode.text, "'; mode:t='", mode.mode, "'}"))

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
  if (!showcase)
    return null
  let secondModesViewData = getSecondModesViewData(showcase)
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

function getEditViewData() {
  let view = {}
  view.options <- []
  let boxFirstModes = {id = "box_first_modes", options = [], onSelect = "onShowcaseSelect"}
  foreach (mode in pageTypes)
    boxFirstModes.options.append({id = mode.terseName, text = loc(mode.locName)})

  view.options.append(boxFirstModes)
  return handyman.renderCached("%gui/profile/profileMainPageEdit.tpl", view)
}

function getShowcaseTitleViewData(terseInfo) {
  let terseName = (terseInfo?.schType ?? "") == "" ? defaultShowcase : terseInfo.schType
  let view = {}
  foreach (showcase in pageTypes)
    if (showcase?.terseName == terseName) {
      view.title <- loc(showcase.locName)
      if (showcase.hasGameMode) {
        let gameMode = getGameMode(terseInfo, showcase)
        view.gamemode <- loc(gameMode?.text ?? "")
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
}