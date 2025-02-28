from "%scripts/dagui_library.nut" import *

let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let DataBlock = require("DataBlock")
let { getCountryFlagImg } = require("%scripts/options/countryFlagsPreset.nut")
let getAllUnits = require("%scripts/unit/allUnits.nut")

let uTypes = [unitTypes.AIRCRAFT, unitTypes.TANK, unitTypes.SHIP, unitTypes.HELICOPTER, unitTypes.BOAT]
const whiteLineColor = "#05111111"
const disabledFlagColor = "#05222222"
const linePrefix = "ace_line_"
const showcaseContainerId = "ace_of_spades_container"
const eliteUnitsCountLabelId = "elite_units_count"
local isOnCheckboxProcessing = false

function updateLinesBackground(isEditMode, container) {
  local needBg = false
  foreach (idx, _uType in uTypes) {
    let lineObj = container.findObject($"{linePrefix}{idx}")
    if (!lineObj || (!isEditMode && lineObj.isLineEnabled == "no"))
      continue
    needBg = !needBg
    lineObj["background-color"] = needBg ? whiteLineColor : "@transparent"
  }
}

function getFlagAndEliteData(terseInfo, playerStats) {
  let acedUnits = terseInfo.showcase?.aced_units

  let shortCountryNames = {}
  local eliteUnitsCount = 0
  let flags = {}

  foreach (country in shopCountriesList) {
    let countryShortName = country.split("_")[1]
    shortCountryNames[country] <- countryShortName
    local isCountryEnabled = false

    if (acedUnits != null)
      foreach (uType in uTypes) {
        let val = acedUnits?[uType.name][countryShortName] ?? 0
        if (val > 0) {
          isCountryEnabled = true
          eliteUnitsCount += acedUnits?[uType.name][countryShortName] ?? 0
        }
      }
    flags[countryShortName] <- isCountryEnabled ? "#FFFFFF" : disabledFlagColor
  }

  local totalSelectedCount = 0
  let unitsData = playerStats?.userstat.units
  let allUnits = getAllUnits()

  if (acedUnits != null)
    foreach (unit in allUnits) {
      let countryShortName = shortCountryNames?[unit.shopCountry]
      if (acedUnits?[unit.unitType.name][countryShortName] == null)
        continue

      if (unitsData)
        totalSelectedCount += unitsData?[unit.shopCountry].contains(unit.name) ? 1 : 0
      else if (unit.isBought())
        totalSelectedCount = totalSelectedCount + 1
    }
  return {flags, eliteCount = $"{eliteUnitsCount}/{totalSelectedCount}"}
}

function updateFlagsAndEliteCount(terseInfo, playerStats, container) {
  let data = getFlagAndEliteData(terseInfo, playerStats)
  foreach (country, flagColor in data.flags) {
    let flag = container.findObject($"flag_{country}")
    if (flag == null)
      continue
    flag["background-color"] = flagColor
  }
  let label = container?.findObject(eliteUnitsCountLabelId)
  label?.setValue(data.eliteCount)
}

function switchUnitSelection(isSelected, utypeName, country, terseInfo, container = null) {
  let valArray = isSelected ? terseInfo.showcase.aced_units_hidden : terseInfo.showcase.aced_units
  let targetArray = isSelected ? terseInfo.showcase.aced_units : terseInfo.showcase.aced_units_hidden

  let val = valArray?[utypeName][country]
  if (val == null)
    return
  if (targetArray?[utypeName] == null)
    targetArray[utypeName] <- {}
  targetArray[utypeName][country] <- val
  valArray[utypeName].$rawdelete(country)

  let checkbox = container?.findObject($"{country}_{utypeName}")
  if (!checkbox)
    return

  checkbox.setValue(isSelected)
}

function onAllCheckboxClick(obj, terseInfo, container) {
  let isSelected = obj.getValue()

  foreach (country in shopCountriesList) {
    let countryShortName = country.split("_")[1]
    foreach (uType in uTypes)
      switchUnitSelection(isSelected, uType.name, countryShortName, terseInfo, container)
  }
}

let aceOfSpades = {
  hasGameMode = false
  terseName = "ace_of_spades"
  locName = "ace_of_spades/name"
  hasOnlySecondTitle = true
  getSecondTitle = @(_terseInfo) loc("ace_of_spades/name")
  onChangeEditMode = function(isEditMode, _terseInfo, scene) {
    updateLinesBackground(isEditMode, scene)
  }
  onClickFunction = function(obj, terseInfo, playerStats, scene) {
    if (isOnCheckboxProcessing)
      return

    let container = scene.findObject(showcaseContainerId)
    isOnCheckboxProcessing = true
    if (obj.id == "all_checkbox") {
      onAllCheckboxClick(obj, terseInfo, container)
      updateFlagsAndEliteCount(terseInfo, playerStats, container)
      isOnCheckboxProcessing = false
      return
    }

    let data = obj.id.split("_")
    let [country, unitType] = data
    let needAdd = obj.getValue()

    switchUnitSelection(needAdd, unitType, country, terseInfo)
    updateFlagsAndEliteCount(terseInfo, playerStats, container)
    isOnCheckboxProcessing = false
  }
  getSaveData = function(terseInfo) {
    let data = DataBlock()
    data.showcaseType <- "ace_of_spades"
    data.acedUnitsFilter = DataBlock()
    foreach (unitType, countryes in terseInfo.showcase.aced_units) {
      foreach (country, _val in countryes)
        data.acedUnitsFilter[$"country_{country}"] <- unitType
    }
    return data
  }
  canBeSaved = function(terseInfo) {
    if (terseInfo.showcase?.aced_units)
      foreach (unitType in terseInfo.showcase.aced_units)
        if (unitType.len() > 0)
          return true

    showInfoMsgBox(loc("ace_of_spades/warning_select_category"))
    return false
  }
  getViewData = function(_showcase, playerStats, terseInfo, viewParams = null) {
    let {scale = 1} = viewParams
    let statLines = {stats = []}
    local needBg = false
    let acedUnitsHidden = terseInfo.showcase?.aced_units_hidden ?? {}
    let acedUnits = terseInfo.showcase?.aced_units ?? {}

    foreach (idx, unitType in uTypes) {
      let typeName = unitType.name
      let statLine = {unitTypeIcon = unitType.testFlightIcon, lineBgColor = "@transparent",
        values = [], isLineEnabled = false, lineIdx = $"{linePrefix}{idx}"}

      let dash = loc("ui/mdash")
      foreach (country in shopCountriesList) {
        let countryShortName = country.split("_")[1]
        let isEnabled = acedUnits?[typeName][countryShortName] != null
        let isCheckboxEnabled = isEnabled || acedUnitsHidden?[typeName][countryShortName] != null
        let unitsCount = isEnabled ? acedUnits?[typeName][countryShortName] : (acedUnitsHidden?[typeName][countryShortName] ?? dash)
        if (isEnabled && !statLine.isLineEnabled) {
          needBg = !needBg
          statLine.isLineEnabled = true
          statLine.lineBgColor = needBg ? whiteLineColor : "@transparent"
        }

        statLine.values.append({value = isEnabled ? unitsCount : dash, valInEditMode = unitsCount,
          checkboxId = $"{countryShortName}_{typeName}", isValEnabled = isEnabled ? "yes" : "no", isCheckboxEnabled})
      }
      statLines.stats.append(statLine)
    }

    let flags = []
    let data = getFlagAndEliteData(terseInfo, playerStats)

    foreach (country in shopCountriesList) {
      let countryShortName = country.split("_")[1]
      flags.append({flag = getCountryFlagImg(country), flagId = $"flag_{countryShortName}", flagColor = data.flags[countryShortName]})
    }

    return handyman.renderCached("%gui/profile/showcase/aceOfSpades.tpl", {
      scale, containerId = showcaseContainerId, eliteUnitsCountLabelId,
      flags, stats = statLines.stats, elitUnitsCounts = data.eliteCount
    })
  }
}

return {
  aceOfSpades
}