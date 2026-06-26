from "%scripts/dagui_library.nut" import *
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { eachBlock, blkOptFromPath } = require("%sqstd/datablock.nut")
let { getTooltipType, addTooltipTypes } = require("%scripts/utils/genericTooltipTypes.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { getUnitClassIco } = require("%scripts/unit/unitInfoTexts.nut")
let { getUnitName, getUnitCountryIcon } = require("%scripts/unit/unitInfo.nut")
let { destroyModalInfo } = require("%scripts/modalInfo/modalInfo.nut")

const RADAR_TYPE_DEFAULT = "all_purpose"

local bandsInfoCache = null

function getBandsInfo() {
  if (bandsInfoCache != null)
    return bandsInfoCache

  bandsInfoCache = {}
  let bandsInfoBlk = blkOptFromPath("config/arm_bands_props.blk")
  let { targetsGroups = null } = bandsInfoBlk
  if (targetsGroups == null)
    return bandsInfoCache
  eachBlock(targetsGroups, function(bandBlk) {
    let { band = null } = bandBlk
    if (band == null)
      return
    let bandInfo = { targets = [], targetsTypes = [] }
    eachBlock(bandBlk, function(targetsBlk, targetType) {
      let targets = (targetsBlk % "target").map(@(t) {
        units = t % "unit"
        radarTypes = (t % "type").filter(@(v) v != RADAR_TYPE_DEFAULT)
        targetType
      }).filter(@(v) v.units.len() > 0)
      bandInfo.targetsTypes.append(targetType)
      bandInfo.targets.extend(targets)
    })
    bandsInfoCache[band] <- bandInfo
  })

  return bandsInfoCache
}

let getBandLocName = @(v) loc($"radar_freq_band_{v}")

function mkRadarBandsListMarkup(weapon) {
  let { radarBands } = weapon
  let count = radarBands.len()
  if (count == 0)
    return null
  let lastIdx = count - 1
  let bandsInfo = getBandsInfo()
  let data = handyman.renderCached("%gui/weaponry/radarBands.tpl", {
    radarBands = radarBands.map(function(v, idx) {
      let hasTooltip = (bandsInfo?[v].targets.len() ?? 0) > 0
      return {
        name = getBandLocName(v)
        isLast = idx == lastIdx
        isTooltipByHold = showConsoleButtons.get()
        tooltipId = !hasTooltip ? null
          : getTooltipType("RADAR_BAND_TOOLTIP").getTooltipId(v)
      }
    })
  })
  return data
}

function getUnitsListView(targets, filterTargetType = null) {
  let res = []
  local idx = 0
  foreach (targetInfo in targets) {
    let { units, radarTypes, targetType } = targetInfo
    if (filterTargetType != null && filterTargetType != targetType)
      continue
    let unitId = units[0]
    let unit = getAircraftByName(unitId)
    res.append({
      countryIcon = unit == null ? null : getUnitCountryIcon(unit)
      isWideIco = unit?.unitType.isWideUnitIco ?? false
      unitTypeIco = unit?.isInShop ? getUnitClassIco(unit) : null
      unitName = unit?.isInShop ? getUnitName(unitId)
        : loc($"{unitId}_1", unitId)
       additionalInfo = radarTypes.len() == 0 ? ""
         : loc("ui/comma").join(radarTypes.map(@(v) loc($"radarType/{v}")))
       even = idx % 2 == 0
    })
    idx++
  }
  return res
}

function getTagetTypesView(targetsTypes) {
  let res = [{
    id = "all"
    tabName = loc("userlog/page/all")
  }]
  foreach (targetsType in targetsTypes)
    res.append({
      id = targetsType
      tabName = loc($"radarBand/targetType/{targetsType}")
    })
  return res
}

let onModalInfoClose = @() destroyModalInfo()

function fillUnitsList(nestObj, targets, curTargetsType) {
  let data = handyman.renderCached("%gui/unit/textListOfUnits.tpl", {
    units = getUnitsListView(targets, curTargetsType)
  })
  let guiScene = nestObj.getScene()
  guiScene.replaceContentFromText(nestObj.findObject("units_list"),
    data, data.len(), null)
}

addTooltipTypes({
  RADAR_BAND_TOOLTIP = {
    isCustomTooltipFill = true
    isEmptyTooltipObjClass = true
    isModalTooltip = true
    fillTooltip = function(obj, _handler, id, _params) {
      if (!obj?.isValid())
        return false

      let band = id.tointeger()
      let bandInfo = getBandsInfo()?[band]
      if (bandInfo == null)
        return false
      let { targets, targetsTypes } = bandInfo
      let hasDifferentTagetTypes = targetsTypes.len() > 1
      let data = handyman.renderCached("%gui/weaponry/radarBandsTooltip.tpl", {
        name = loc("ui/colon").concat(getBandLocName(band), loc("radarBand/targetsVehicles"))
        units = hasDifferentTagetTypes ? null : getUnitsListView(targets)
        hasDifferentTagetTypes
        tabs = hasDifferentTagetTypes ? getTagetTypesView(targetsTypes) : null
      })
      let guiScene = obj.getScene()
      guiScene.replaceContentFromText(obj, data, data.len(), {
        onModalInfoClose
        onTargetTypeChange = @(typeObj) fillUnitsList(obj, targets,
          targetsTypes?[typeObj.getValue() - 1])
      })
      if (hasDifferentTagetTypes) {
        guiScene.applyPendingChanges(false)
        let tooltipMainObj = obj.findObject("main_block")
        tooltipMainObj.width = tooltipMainObj.getSize()[0] 
        obj.findObject("targets_types").setValue(0)
      }

      return true
    }
  }
})

return {
  mkRadarBandsListMarkup
}