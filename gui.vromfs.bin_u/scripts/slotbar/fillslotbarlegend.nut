from "%scripts/dagui_library.nut" import *
let { getCrewSpecTypeByCode, getTrainedCrewSpecCode } = require("%scripts/crew/crewSpecType.nut")
let { getUnitName, getUnitCountry } = require("%scripts/unit/unitInfo.nut")
let { getCrewsListByCountry } = require("%scripts/slotbar/crewsList.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")

function addLegendData(result, specType) {
  foreach (data in result)
    if (specType == data.specType)
      return

  result.append({
    id = specType.specName,
    specType = specType,
    imagePath = specType.trainedIcon,
    locId = specType.getName()
  })
}

function getLegendView(unit, crewsList) {
  let legendData = []
  foreach (crew in crewsList) {
    let specType = getCrewSpecTypeByCode(getTrainedCrewSpecCode(crew, unit))
    addLegendData(legendData, specType)
  }

  if (legendData.len() == 0)
    return null

  return {
    header = loc("mainmenu/selectCrew/qualificationLegend",
      { unitName = colorize("userlogColoredText", getUnitName(unit)) })
    haveLegend = true
    legendData = legendData.sort(@(a, b) a.specType.code <=> b.specType.code)
  }
}

function fillSlotbarLegend(obj, unit, handler) {
  if (!obj?.isValid())
    return null
  let country = getUnitCountry(unit)
  let view = getLegendView(unit, getCrewsListByCountry(country))
  let blk = handyman.renderCached("%gui/slotbar/legend_block.tpl", view)

  handler.guiScene.replaceContentFromText(obj, blk, blk.len(), handler)
  return obj
}

return fillSlotbarLegend