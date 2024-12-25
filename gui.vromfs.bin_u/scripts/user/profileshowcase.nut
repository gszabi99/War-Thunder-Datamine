from "%scripts/dagui_library.nut" import *

let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { g_difficulty } = require("%scripts/difficulty.nut")
let { hasAllFeatures } = require("%scripts/user/features.nut")
let { charSendBlk } = require("chard")
let { addTask } = require("%scripts/tasker.nut")
let DataBlock = require("DataBlock")
let { decimalFormat } = require("%scripts/langUtils/textFormat.nut")
let { isUnlockOpened } = require("%scripts/unlocks/unlocksModule.nut")
let { getConditionsToUnlockShowcaseById } = require("%scripts/unlocks/unlocksViewModule.nut")
let lbDataType = require("%scripts/leaderboard/leaderboardDataType.nut")
let { getUnitTooltipImage } = require("%scripts/unit/unitInfoTexts.nut")
let { setCurrentShowcase, updateShowcaseDataInCache } = require("%scripts/user/profileShowcasesData.nut")
let { round_by_value } = require("%sqstd/math.nut")
let { measureType } = require("%scripts/measureType.nut")

let defaultShowcase = "favorite_mode"
let defaultShowcaseType = "air_arcade"
let diffNames = ["arcade", "historical", "simulation"]
let gamemodesNoAiStats = ["tank_arcade", "tank_realistic", "tank_simulation", "test_ship_arcade", "test_ship_realistic"]

function getStatsValue(params, value, scorePeriod) {
  let gameType = params?.showcaseType ?? defaultShowcaseType
  let stats = params.stats?.leaderboard[gameType][scorePeriod]
  let val = stats?[value.valueId][scorePeriod] ?? 0
  return val == -1 ? 0 : val
}

let getUnitNameFromTerseInfo = @(terseInfo) (terseInfo.schType == "favorite_unit")
  ? terseInfo?.showcase.unit ?? ""
  : ""

let getUnitFromTerseInfo = @(terseInfo) terseInfo.schType == "favorite_unit"
  ? getAircraftByName(getUnitNameFromTerseInfo(terseInfo))
  : null

function getKillsForMode(playerStats, mode, targetType) {
  let scorePeriod = "value_total"
  let stats = playerStats?.leaderboard[mode][scorePeriod]
  return (stats?[$"air_kills_{targetType}"][scorePeriod] ?? 0)
    + (stats?[$"ground_kills_{targetType}"][scorePeriod] ?? 0)
    + (stats?[$"naval_kills_{targetType}"][scorePeriod] ?? 0)
}

function getDeathsForMode(playerStats, mode) {
  let scorePeriod = "value_total"
  let stats = playerStats?.leaderboard[mode][scorePeriod]
  return (stats?.air_death[scorePeriod] ?? 0)
    + (stats?.ground_death[scorePeriod] ?? 0)
    + (stats?.naval_death[scorePeriod] ?? 0)
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
    return 0

  foreach (lbCategory in ::leaderboards_list)
    if (lbCategory.field == value.valueId) {
      let lbVal = stat.idx < 0 ? -1 : stat.idx + 1
      let text = lbCategory.getItemCell(lbVal, null, false, lbDataType.PLACE)?.text ?? "0"
      return to_integer_safe(text, 0, false)
    }

  return 0
}

function findUnitStats(stats, unitName, diff) {
  let statArr = stats?[diff].total
  return statArr?.findvalue(@(v) v.name == unitName)
}

function getUnitStat(unitName, value, params) {
  let unitStats = params?.unitStats ?? findUnitStats(params?.stats.userstat, unitName, params?.diff ?? "arcade")
  return unitStats?[value.valueId] ?? 0
}

function findUnitBestDiff(unitName, value, params) {
  local maxFlyouts = 0
  local bestDiff = "arcade"
  let oldDiff = params?.diff
  foreach (diff in diffNames) {
    params.diff <- diff
    let statVal = getUnitStat(unitName, value, params)
    if (statVal > maxFlyouts) {
      maxFlyouts = statVal
      bestDiff = diff
    }
  }
  params.diff <- oldDiff
  return bestDiff
}

function getActiveKillsByDeathsRatio(params) {
  let kills = getKillsForMode(params?.stats, params.showcaseType, "player").tofloat()
  let deaths = getDeathsForMode(params?.stats, params.showcaseType).tofloat()
  return round_by_value(kills / (deaths > 0 ? deaths : 1), 0.1)
}

function getAiKillsByDeathsRatio(params) {
  let kills = getKillsForMode(params?.stats, params.showcaseType, "ai").tofloat()
  let deaths = getDeathsForMode(params?.stats, params.showcaseType).tofloat()
  return round_by_value(kills / (deaths > 0 ? deaths : 1), 0.1)
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
    getValue = @(params, _val) decimalFormat(getKillsForMode(params?.stats, params.showcaseType, "player"))
  },
  aiVehicleDestroys = {
    type = "stat"
    icon = "lb_average_script_kills"
    locId = "multiplayer/lb_kills_ai"
    valueId = "kills_ai"
    canShow = @(params) !gamemodesNoAiStats.contains(params.showcaseType)
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
    locId = "stats/average_active_kills_by_deaths"
    valueId = "average_active_kills_by_spawn"
    getValue = @(params, _val) getActiveKillsByDeathsRatio(params)
  },
  ai_kill_by_spawns = {
    type = "stat"
    icon = "lb_average_script_kills_by_spawn"
    locId = "stats/average_script_kills_by_deaths"
    valueId = "average_script_kills_by_spawn"
    canShow = @(params) !gamemodesNoAiStats.contains(params.showcaseType)
    getValue = @(params, _val) getAiKillsByDeathsRatio(params)
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
    getValue = @(params, val) $"{decimalFormat(getStatsValue(params, val, "value_inhistory"))}"
    tooltip = "multiplayer/pvp_ratio"
  },
  placeInLeaderboard = {
    type = "textStat"
    locId = "multiplayer/place_in_leaderboard"
    valueId = "pvp_ratio"
    getValue = function(params, val) {
      let pos = getPosInLeaderboard(params, val, "value_inhistory")
      return pos == 0 ? "-" : decimalFormat(pos)
    }
    tooltip = "multiplayer/place_in_leaderboard_desc"
  },
  atomic_ace = {
    type = "stat_big"
    icon = "!#ui/gameuiskin#atomic_ace_icon.svg"
    valueId = null
    getText = @(params, _val) loc("showcase/nuclear_bombs_dropped", {num = getAtomicAceValue(params?.terseInfo)})
    getValue = @(params, _val) getAtomicAceValue(params?.terseInfo)
  },
  peaceful_atom = {
    type = "stat_big"
    icon = "!#ui/gameuiskin#peacemaker_icon.svg"
    valueId = null
    getText = @(params, _val) loc("showcase/nuclear_carriers_shotdown", {num = getPeacefulAtomValue(params?.terseInfo)})
    getValue = @(params, _val) getPeacefulAtomValue(params?.terseInfo)
  },
  favUnit = {
    type = "unitImage"
    width = "0.9@accountHeaderWidth"
    height = "320@sf/@pf"
    getImage = function (params) {
      let unit = getUnitFromTerseInfo(params.terseInfo)
      return unit ? getUnitTooltipImage(unit) : null
    }
    valueId = null
  },
  unit_victories = {
    type = "stat", icon = "lb_each_player_victories",
    getText = @(params, val) loc("stats/victories", {num = getUnitStat(params?.unit.name, val, params)})
    valueId = "victories", getValue = @(params, val) getUnitStat(params?.unit.name, val, params)
  }
  unit_battles = {
    type = "stat", icon = "lb_each_player_session",
    getText = @(params, val) loc("stats/battles", {num = getUnitStat(params?.unit.name, val, params)})
    valueId = "sessions", getValue = @(params, val) getUnitStat(params?.unit.name, val, params)
  }
  unit_respawns = {
    type = "stat", icon = "lb_flyouts",
    getText = @(params, val) loc("stats/flyouts", {num = getUnitStat(params?.unit.name, val, params)})
    valueId = "flyouts", getValue = @(params, val) getUnitStat(params?.unit.name, val, params)
  }
  unit_kills = {
    type = "stat", icon = "lb_average_script_kills",
    valueId = "kills",
    getText = @(params, val) loc("stats/targetsDestroyed", {num = getUnitStat(params?.unit.name, val, params)})
    getValue = function(params, _val) {
      let unitStats = params?.unitStats ?? findUnitStats(params?.stats.userstat, params?.unit.name, params?.diff)
      if (!unitStats)
        return 0
      return unitStats.naval_kills + unitStats.ground_kills + unitStats.air_kills
    }
  }
  unit_deaths = {
    type = "stat", icon = "lb_deaths",
    getText = @(params, val) loc("stats/deaths", {num = getUnitStat(params?.unit.name, val, params)})
    valueId = "deaths", getValue = @(params, val) getUnitStat(params?.unit.name, val, params)
  }
  diff_label = {
    type = "label",
    getText = @(params, _val) loc($"difficulty{diffNames.indexof(params?.diff) ?? 0}")
    valueId = "",
  }
  averageRelativePosition = {
    type = "stat"
    icon = "lb_average_relative_position"
    locId = "showcase/averageRelativePosition"
    valueId = "averageRelativePosition"
    getValue = @(params, val) measureType.PERCENT_FLOAT.getMeasureUnitsText(getStatsValue(params, val, params.scorePeriod))
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
      ["battles", "victories", "averageRelativePosition"],
      ["kill_by_spawns", "ai_kill_by_spawns", "average_score"],
      ["pvpRating", "placeInLeaderboard"]
    ]
    blockedGameTypes = ["arcade", "historical", "simulation"]
    scorePeriod = "value_total"
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
      ["favUnit"],
      ["diff_label"],
      ["unit_battles", "unit_victories", "unit_respawns"],
      ["unit_kills", "unit_deaths"]
    ]
    scorePeriod = "value_total"
    terseName = "favorite_unit"
    locName = "showcase/favorite_unit"
    getSecondTitleLoc = function(terseInfo) {
      let unit = getUnitFromTerseInfo(terseInfo)
      return unit ? loc($"{unit.name}_shop") : loc("shop/aircraftNotSelected")
    }
    hasSecondTitleInEditMode = true
    saveUnit = @(terseInfo, unitName, _unitIdx) terseInfo.showcase.unit = unitName
    canBeSaved = function(terseInfo) {
      let unit = getUnitFromTerseInfo(terseInfo)
      if (unit == null) {
        showInfoMsgBox(loc("msg/warning_select_unit"))
        return false
      }
      return true
    }
    getSaveData = function(terseInfo) {
      let data = DataBlock()
      data.showcaseType <- "favorite_unit"
      if ((terseInfo.showcase?.unit ?? "") != "") {
        data.favoriteUnit <- terseInfo.showcase.unit
        data.favoriteUnitDifficulty <- terseInfo.showcase.difficulty ?? "arcade"
      }
      return data
    }
    addAdditionalParams = function (params) {
      let unit = getUnitFromTerseInfo(params.terseInfo)
      if (unit != null) {
        params.unit <- unit
        params.diff = findUnitBestDiff(unit.name, visibleValues["unit_respawns"], params)
        params.unitStats <- findUnitStats(params?.stats.userstat, unit.name, params.diff)
        params.terseInfo.showcase.difficulty <- params.diff
      }
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
    getSecondTitleLoc = @(_terseInfo) "atomic_ace/name"
    isDisabled = @() !isUnlockOpened("atomic_ace")
    hintForDisabled = @() "{\"id\":\"atomic_ace\",\"ttype\":\"UNLOCK_SHORT\"}"
    textForDisabled = @() getConditionsToUnlockShowcaseById("atomic_ace")
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
    getSecondTitleLoc = @(_terseInfo) "peacemaker/name"
    isDisabled = @() !isUnlockOpened("peacemaker")
    hintForDisabled = @() "{\"id\":\"peacemaker\",\"ttype\":\"UNLOCK_SHORT\"}"
    textForDisabled = @() getConditionsToUnlockShowcaseById("peacemaker")
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

function getShowcaseViewData(playerStats, terseInfo, viewParams = null) {
  let {scale = 1, isSmallSize = null} = viewParams
  let showcase = getShowcaseByTerseInfo(terseInfo)
  if (!showcase)
    return null
  let statLines = []
  let modeLines = showcase.lines

  let showcaseType = showcase?.hasGameMode ? showcase?.getShowCaseType(terseInfo) : null
  let params = {stats = playerStats, showcaseType, terseInfo, scorePeriod = showcase?.scorePeriod ?? "value_total"}
  if (showcase?.addAdditionalParams)
    showcase.addAdditionalParams(params)
  local unitIdx = 0

  foreach (line in modeLines) {
    let stats = []
    local idx = 0
    let statsBig = []
    let textStats = []
    let unitsImages = []
    let labels = []

    foreach (valName in line) {
      let value = visibleValues[valName]
      if (value.type == "stat") {
        if (value?.canShow && !value.canShow(params))
          continue

        let statData = {
          icon = $"!#ui/gameuiskin#{value.icon}.svg",
          statName = value?.getText(params, value) ?? loc(value.locId),
          idx,
          statValue = $"{value?.getValue ? value.getValue(params, value) : decimalFormat(getStatsValue(params, value, showcase.scorePeriod))}",
          tooltip = loc(value?.tooltip ?? "")
        }
        stats.append(statData)
        idx++
        continue
      }
      if (value.type == "textStat") {
        let statData = {
          text = value?.getText(params, value) ?? loc(value.locId),
          value = value?.getValue(params, value),
          tooltip = loc(value?.tooltip ?? "")
        }
        textStats.append(statData)
        continue
      }
      if (value.type == "stat_big") {
        let statData = {
          icon = value.icon,
          statName = value?.getText(params, value) ?? loc(value.locId),
          statValue = $"{value?.getValue ? value.getValue(params, value) : decimalFormat(getStatsValue(params, value, showcase.scorePeriod))}",
          tooltip = loc(value?.tooltip ?? "")
        }
        statsBig.append(statData)
        continue
      }
      if (value.type == "unitImage") {
        let unit = getUnitFromTerseInfo(terseInfo)
        let statData = {
          id = $"unitImage_{unitIdx}", imageIdx = unitIdx, unit = unit?.name ?? "",
          image = value.getImage(params), width = value?.width, height = value.height
        }
        unitsImages.append(statData)
        unitIdx = unitIdx + 1
        continue
      }
      if (value.type == "label")
        labels.append({text = value.getText(params, value)})

    }
    let iconStatsCount = stats.len()
    if (iconStatsCount > 1) {
      stats[0].isLeftCell <- true
      stats[iconStatsCount-1].isRightCell <- true
      stats[iconStatsCount-1].isEndInRow <- true
    }

    statLines.append({scale, stats, statsBig, textStats, unitsImages, labels, hasUnitImage = unitsImages.len() > 0})
  }

  return handyman.renderCached("%gui/profile/profileMainPageMiddle.tpl", {scale, isSmallSize, statLines})
}

function getSecondModesViewData(showcase, terseInfo, params = null) {
  let {scale = 1, isSmallSize = null } = params
  let list = getShowcaseGameModes(showcase?.blockedGameTypes)
  let data = []

  let gameMode = showcase.getShowCaseType(terseInfo)
  foreach (mode in list)
    data.append("".concat(
      "option {text:t='", mode.text, "'; mode:t='", mode.mode,
      "'; selected:t='", gameMode == mode ? "yes" : "no", "'",
      isSmallSize ? $";font-pixht:t='{scale}*1@comboboxSmallFontPixHt'" : "" ,"}"
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

function getShowcaseTypeBoxData(terseInfo, params = null) {
  let showcase = getShowcaseByTerseInfo(terseInfo)
  if (!showcase || !showcase.hasGameMode)
    return null
  let secondModesViewData = getSecondModesViewData(showcase, terseInfo, params)
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

function getEditViewData(terseInfo, params) {
  let {scale = 1, isSmallSize = null } = params
  let showcase = getShowcaseByTerseInfo(terseInfo)
  let view = {scale, isSmallSize}
  view.options <- []
  let boxFirstModes = {id = "box_first_modes", options = [], onSelect = "onShowcaseSelect"}
  foreach (idx, mode in pageTypes) {
    let option = {
      id = mode.terseName, text = loc(mode.locName),
      isDisabled = mode?.isDisabled() ? "yes" : null,
      hintForDisabled = mode?.hintForDisabled() ?? ""
    }
    if ((showcase == null && idx == 0) || showcase == mode)
      option.selected <- "yes"
    boxFirstModes.options.append(option)
  }

  view.options.append(boxFirstModes)
  return handyman.renderCached("%gui/profile/profileMainPageEdit.tpl", view)
}

function getShowcaseTitleViewData(terseInfo, params = null) {
  let {scale = 1, isSmallSize = null } = params
  let terseName = (terseInfo?.schType ?? "") == "" ? defaultShowcase : terseInfo.schType
  let view = {scale, isSmallSize}
  foreach (showcase in pageTypes)
    if (showcase?.terseName == terseName) {
      view.title <- showcase?.hasOnlySecondTitle ? " " : loc(showcase.locName)
      if (showcase?.getSecondTitleLoc)
        view.secondTitle <- loc(showcase.getSecondTitleLoc(terseInfo))
      else if (showcase?.hasGameMode) {
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

function onSaveShowcaseComplete(terseInfo, callback) {
  updateShowcaseDataInCache(terseInfo.schType, terseInfo.showcase)
  setCurrentShowcase(terseInfo.schType)
  if (callback)
    callback()
}

function saveShowcase(terseInfo, onSucsess, onError) {
  let showcase = getShowcaseByTerseInfo(terseInfo)
  if (!showcase)
    return
  let taskId = charSendBlk("cln_save_profile_showcase", showcase.getSaveData(terseInfo))
  addTask(taskId, { showProgressBox = true }, @() onSaveShowcaseComplete(terseInfo, onSucsess), onError)
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

function saveUnitToTerseInfo(terseInfo, unit, idx) {
  let showcase = getShowcaseByTerseInfo(terseInfo)
  showcase?.saveUnit(terseInfo, unit.name, idx)
}

function getShowcaseIndexByTerseName(terseName) {
  return pageTypes.findindex(@(p) p.terseName == terseName) ?? 0
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
  saveUnitToTerseInfo
  getShowcaseIndexByTerseName
}