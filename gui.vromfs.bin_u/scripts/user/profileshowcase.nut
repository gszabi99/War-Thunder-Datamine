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
let { setCurrentShowcase, updateShowcaseDataInCache } = require("%scripts/user/profileShowcasesData.nut")
let { showcaseValues, getUnitFromTerseInfo, getStatsValue, defaultShowcaseType, diffNames, findUnitStats
} = require("%scripts/user/showcase/showcaseValues.nut")
let { favoriteShowcase } = require("%scripts/user/showcase/favoriteShowcase.nut")
let { aceOfSpades } = require("%scripts/user/showcase/aceOfSpades.nut")
let { unitsCollector } = require("%scripts/user/showcase/unitsCollector.nut")
let { medalist } = require("%scripts/user/showcase/medalist.nut")
let { achivHunter } = require("%scripts/user/showcase/achievementHunter.nut")
let { leaderboardModes } = require("%scripts/leaderboard/leaderboardCategoryType.nut")

let defaultShowcase = "favorite_mode"
let getDiffByIndex = @(index) diffNames?[index] ?? diffNames[0]

let pageTypes = [
  favoriteShowcase,
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
    getSecondTitle = function(terseInfo) {
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
        params.unitStats <- findUnitStats(params?.stats.userstat, unit.name, params.terseInfo.showcase?.difficulty ?? diffNames[0])
      }
    }
    getDiffsForUnitsSort = function(terseInfo) {
      return terseInfo.showcase?.difficulty ?? diffNames[0]
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
    getSecondTitle = @(_terseInfo) loc("atomic_ace/name")
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
    getSecondTitle = @(_terseInfo) loc("peacemaker/name")
    isDisabled = @() !isUnlockOpened("peacemaker")
    hintForDisabled = @() "{\"id\":\"peacemaker\",\"ttype\":\"UNLOCK_SHORT\"}"
    textForDisabled = @() getConditionsToUnlockShowcaseById("peacemaker")
    getSaveData = function(_terseInfo) {
      let data = DataBlock()
      data.showcaseType <- "peacemaker"
      return data
    }
  },
  unitsCollector,
  aceOfSpades,
  medalist,
  achivHunter
]

function getShowcaseByTerseInfo(terseInfo) {
  let terseName = (terseInfo?.schType ?? "") == "" ? defaultShowcase : terseInfo.schType
  return pageTypes.findvalue(@(showcase) showcase?.terseName == terseName)
}

function getShowcaseGameModes(blockedGameTypes) {
  let list = []
  foreach (mode in leaderboardModes) {
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
  let showcase = getShowcaseByTerseInfo(terseInfo)
  if (!showcase)
    return null

  if (showcase?.getViewData)
    return showcase?.getViewData(showcase, playerStats, terseInfo, viewParams)

  let {scale = 1, isSmallSize = null} = viewParams
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
    local flags = null

    foreach (valName in line) {
      let value = showcaseValues[valName]
      if (value.type == "stat") {
        if (value?.canShow && !value.canShow(params))
          continue

        let statData = {
          icon = $"!#ui/gameuiskin#{value.icon}.svg",
          statName = value?.getText(params, value) ?? loc(value.locId),
          idx,
          statValue = $"{value?.getValue ? value.getValue(params, value) : decimalFormat(getStatsValue(params, value, showcase.scorePeriod))}",
          statValueId = $"ters_info_stat_{valName}"
          tooltip = loc(value?.tooltip ?? "")
        }
        stats.append(statData)
        idx++
        continue
      }
      if (value.type == "textStat") {
        let statData = {
          isFirst = textStats.len() == 0,
          text = value?.getText(params, value) ?? loc(value.locId),
          value = value?.getValue(params, value),
          tooltip = loc(value?.getTooltip(params, value) ?? "")
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
        let unit = getUnitFromTerseInfo(terseInfo, unitIdx)
        let statData = {
          id = $"unitImage_{unitIdx}", imageIdx = unitIdx, unit = unit?.name ?? "", margin = value?.getMargin(scale),
          image = value.getImage(params, unitIdx), width = value?.width, height = value.height
        }
        unitsImages.append(statData)
        unitIdx = unitIdx + 1
        continue
      }
      if (value.type == "flags") {
        flags = value.getValue(params, value)
        continue
      }
      if (value.type == "label") {
        labels.append({text = value.getText(params, value), comboBoxData = value?.getComboBox(params, value)})
        continue
      }
    }
    let iconStatsCount = stats.len()
    if (iconStatsCount > 1) {
      stats[0].isLeftCell <- true
      stats[iconStatsCount-1].isRightCell <- true
      stats[iconStatsCount-1].isEndInRow <- true
    }

    statLines.append({isFirstLine = statLines.len() == 0, flags, hasFlags = (flags?.len() ?? 0) > 0,
      stats, statsBig, textStats, unitsImages, labels, hasUnitImage = unitsImages.len() > 0})
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
      if (showcase?.getSecondTitle)
        view.secondTitle <- showcase.getSecondTitle(terseInfo)
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
  
  if ((gameMode ?? "") != "")
    return

  let gameModes = getShowcaseGameModes(showcase?.blockedGameTypes)
  let checkValue = showcaseValues.battles
  local maxValue = -1
  local bestMode = null

  foreach (mode in gameModes) {
    let val = getStatsValue({stats, terseInfo, showcaseType = mode.mode}, checkValue, showcase.scorePeriod)
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
  showcase?.saveUnit(terseInfo, unit?.name, idx)
}

function fillStatsValuesOfTerseInfo(scene, terseInfo, playerStats) {
  let showcase = getShowcaseByTerseInfo(terseInfo)
  if (showcase == null)
    return

  let showcaseType = showcase?.hasGameMode ? showcase?.getShowCaseType(terseInfo) : null
  let params = {stats = playerStats, showcaseType, terseInfo, scorePeriod = showcase?.scorePeriod ?? "value_total"}
  showcase?.addAdditionalParams(params)

  foreach (line in showcase.lines)
    foreach (valName in line) {
      let value = showcaseValues[valName]
      if (value.type != "stat")
        continue

      let obj = scene.findObject($"ters_info_stat_{valName}")
      if (!obj?.isValid())
        continue

      obj.setValue($"{value?.getValue ? value.getValue(params, value) : decimalFormat(getStatsValue(params, value, showcase.scorePeriod))}")
    }
}

function getShowcaseIndexByTerseName(terseName) {
  return pageTypes.findindex(@(p) p.terseName == terseName) ?? 0
}

function getShowcaseUnitsFilter(terseInfo, unitIdx = -1) {
  let showcase = getShowcaseByTerseInfo(terseInfo)
  return showcase?.getUnitsFilter(terseInfo, unitIdx) ?? @(_u) true
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
  fillStatsValuesOfTerseInfo
  getShowcaseIndexByTerseName
  getShowcaseUnitsFilter
  getDiffByIndex
}