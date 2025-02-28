from "%scripts/dagui_library.nut" import *

let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let DataBlock = require("DataBlock")
let { isUnlockOpened } = require("%scripts/unlocks/unlocksModule.nut")
let { getConditionsToUnlockShowcaseById } = require("%scripts/unlocks/unlocksViewModule.nut")
let { showcaseValues, getUnitFromTerseInfo } = require("%scripts/user/showcase/showcaseValues.nut")
let { isArray } = require("%sqstd/underscore.nut")

const COLLECTOR_UNITS_COUNT = 3

let unitsCollector = {
  lines = ["collection_unit", "collection_unit", "collection_unit",
    "vehicle_hangar","collectionUnitFlags"]
  scorePeriod = "value_total"
  terseName = "unit_collector"
  locName = "unit_collector/name"
  hasOnlySecondTitle = true
  getSecondTitle = @(_terseInfo) loc("unit_collector/name")
  isDisabled = @() !isUnlockOpened("unit_collector")
  hintForDisabled = @() "{\"id\":\"unit_collector\",\"ttype\":\"UNLOCK_SHORT\"}"
  textForDisabled = @() getConditionsToUnlockShowcaseById("unit_collector")
  saveUnit = function (terseInfo, unitName, unitIdx) {
    if (terseInfo.showcase?.units == null)
      terseInfo.showcase.units <- []
    let unitsLen = terseInfo.showcase.units.len()
    if (unitsLen < COLLECTOR_UNITS_COUNT)
      for (local i = unitsLen; i < COLLECTOR_UNITS_COUNT; i++)
        terseInfo.showcase.units.append("")
    terseInfo.showcase.units[to_integer_safe(unitIdx)] = unitName ?? ""
  }
  canBeSaved = function(terseInfo) {
    let hasUnits = terseInfo.showcase?.units.findvalue(@(uname) uname && uname != "") != null
    if (!hasUnits) {
      showInfoMsgBox(loc("msg/warning_select_unit"))
      return false
    }
    return true
  }
  getSaveData = function(terseInfo) {
    let data = DataBlock()
    data.showcaseType <- "unit_collector"
    if (terseInfo.showcase?.units)
      foreach (unit in terseInfo.showcase.units)
        data.unitCollectorFavorites <- unit ?? ""
    return data
  }
  getUnitsFilter = function(terseInfo, unitIdx) {
    let blockedUnits = []
    if (terseInfo.showcase?.units)
      foreach (idx, unit in terseInfo.showcase.units)
        if (unitIdx != idx)
          blockedUnits.append(unit)
    return @(u) !blockedUnits.contains(u.name)
  }

  getViewData = function(showcase, playerStats, terseInfo, viewParams = null) {
    if (terseInfo.showcase?.units == null)
      terseInfo.showcase.units <- []
    else if (!isArray(terseInfo.showcase.units))
      terseInfo.showcase.units = [terseInfo.showcase.units]

    let {scale = 1} = viewParams
    let params = {stats = playerStats, terseInfo, scorePeriod = showcase?.scorePeriod ?? "value_total"}

    let textStats = []
    let unitsImages = []
    let selectedUnits = []
    local unitIdx = 0
    local flags = null

    foreach (valName in showcase.lines) {
      let value = showcaseValues[valName]
      if (value.type == "textStat") {
        let statData = {
          isFirst = textStats.len() == 0,
          text = value?.getText(params, value) ?? loc(value.locId),
          value = value?.getValue(params, value),
          tooltip = loc(value?.tooltip ?? "")
        }
        textStats.append(statData)
        continue
      }
      if (value.type == "unitImage") {
        let unit = getUnitFromTerseInfo(terseInfo, unitIdx)
        let statData = {
          id = $"unitImage_{unitIdx}", imageIdx = unitIdx, unit = unit?.name ?? "", isForEditMode = true
          image = value.getImage(params, unitIdx), width = value?.width, height = value.height,
          margin = value?.getMargin(scale)
          isOneInRow = unitIdx == 0,
        }
        if (unit != null)
          selectedUnits.append({unit, unitIdx, value})
        unitsImages.append(statData)
        unitIdx = unitIdx + 1
        continue
      }
      if (value.type == "flags") {
        flags = value.getValue(params, value)
        continue
      }
    }

    let selectedUnitsCount = selectedUnits.len()
    foreach (data in selectedUnits) {
      let statData = {
        id = $"unitImage_{data.unitIdx}", imageIdx = data.unitIdx, unit = data.unit.name,
        isDisabledInEditMode = true, isOneInRow = (data.unitIdx == 0) && (selectedUnitsCount == COLLECTOR_UNITS_COUNT),
        image = data.value.getImage(params, data.unitIdx),
        width = selectedUnitsCount == 1 ? "0.9@accountHeaderWidth" : data.value.width,
        height = selectedUnitsCount == 1 ? "@favoriteUnitImageHeight" : data.value.height
      }
      unitsImages.append(statData)
    }

    return handyman.renderCached("%gui/profile/showcase/unitsCollector.tpl", { textStats
      scale, unitsImages, flags, hasFlags = (flags?.len() ?? 0) > 0, hasUnitImage = unitsImages.len() > 0
    })
  }
}

return {
  unitsCollector
}