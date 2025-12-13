from "%scripts/dagui_library.nut" import *

let { getFullUnitBlk } = require("%scripts/unit/unitParams.nut")
let { get_unittags_blk } = require("blkGetters")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { getTooltipType } = require("%scripts/utils/genericTooltipTypes.nut")
let dmViewer = require("%scripts/dmViewer/dmViewer.nut")
let { DM_VIEWER_XRAY } = require("hangar")
let { getInfoBlk } = require("%globalScripts/modeXrayLib.nut")

let unitEngineCache = {}

function getUnitTags(unitName) {
  return get_unittags_blk()?[unitName]
}

function addOnceToCache(unitName, dmPart, unitBlk, unitTags) {
  let info = getInfoBlk(dmPart, unitTags, unitBlk)
  let { manufacturer = "", model = ""} = info
  let key = $"{manufacturer} {model}"

  let data = unitEngineCache[unitName].findvalue(@(val) val.key == key)
  if (data != null)
    data.count++
  else
    unitEngineCache[unitName].append({
      key
      dmPart
      count = 1
      manufacturer
      model
    })
}

function findAirEngine(unitName) {
  if (unitName in unitEngineCache)
    return unitEngineCache[unitName]

  unitEngineCache[unitName] <- []

  let unitBlk = getFullUnitBlk(unitName)
  let unitTags = getUnitTags(unitName)
  let engines = unitTags?.info
  if (engines == null)
    return unitEngineCache[unitName]

  for (local i = 0; i < engines.blockCount(); i++) {
    let engine = engines.getBlock(i)
    let engineDmPartName = engine.getBlockName()
    if (engineDmPartName.contains("engine"))
      addOnceToCache(unitName, engineDmPartName, unitBlk, unitTags)
  }
  return unitEngineCache[unitName]
}

function getUnitEngineMarkup(unitName) {
  dmViewer.updateUnitInfo(unitName)
  let engines = findAirEngine(unitName).map(function(data) {
    let { dmPart, count, manufacturer, model } = data
    let info = dmViewer.getPartTooltipInfo(null, { name = dmPart, viewMode = DM_VIEWER_XRAY, isAddEngineName = false })

    let itemName = " ".join([
        manufacturer != "" ? loc($"engine_manufacturer/{manufacturer}") : ""
        model != "" ? loc($"engine_model/{model}") : ""
        count > 1 ? $" - {count} {loc("measureUnits/pcs")}" : ""
      ], true)

    return {
      itemName
      tooltipId = getTooltipType("UNIT_SIMPLE_TOOLTIP").getTooltipId(unitName, { text = "\n".join(info.desc) })
    }
  })
  return handyman.renderCached("%gui/unitInfo/unitSystems.tpl", { items = engines })
}

return {
  getUnitEngineMarkup
}
