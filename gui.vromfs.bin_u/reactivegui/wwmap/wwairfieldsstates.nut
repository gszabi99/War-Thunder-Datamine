from "%rGui/globals/ui_library.nut" import *

let { subscribe } = require("eventbus")
let DataBlock = require("DataBlock")
let { wwGetAirfieldsCount, wwGetAirfieldInfo, wwClearOutlinedZones,
  wwSelectAirfield, wwGetSelectedAirfield } = require("worldwar")

let { getZoneByPoint } = require("%rGui/wwMap/wwMapZonesData.nut")
let { getSettings } = require("%appGlobals/worldWar/wwSettings.nut")
let { sendToDagui } = require("%rGui/wwMap/wwMapUtils.nut")
let { convertToRelativeMapCoords } = require("%rGui/wwMap/wwOperationConfiguration.nut")
let { hoveredArmy } = require("%rGui/wwMap/wwArmyStates.nut")
let { hoveredAirfieldIndex } = require("%appGlobals/worldWar/wwAirfieldStatus.nut")
let { isMapHovered } = require("%appGlobals/worldWar/wwMapHoverState.nut")

let airfieldsInfo = Watched([])

let selectedAirfield = Watched(null)
let hoveredAirfield = Watched(null)

let tooltipAirfieldIndex = keepref(Computed(@() (hoveredAirfieldIndex.get() != null && hoveredArmy.get() == null && isMapHovered.get()) ? hoveredAirfieldIndex.get() : null))
tooltipAirfieldIndex.subscribe(function(airfieldIndex) {
  if (airfieldIndex == null && hoveredArmy.get() != null)
    return
  sendToDagui("ww.showAirfieldTooltip", { airfieldIndex })
})

function updateAirfieldsData() {
  let count = wwGetAirfieldsCount()
  if (count == 0) {
    airfieldsInfo.set([])
    return
  }

  airfieldsInfo.set(array(count).map(function(_val, index) {
    let blk = DataBlock()
    wwGetAirfieldInfo(index, blk)
    let airfieldData = {}
    airfieldData.airfieldIdx <- index
    let airfieldPos = convertToRelativeMapCoords(blk.specs.pos)
    airfieldData.airfieldType <- blk.specs.type
    airfieldData.ownedZoneId <- getZoneByPoint(airfieldPos).id
    airfieldData.airfieldPos <- airfieldPos
    airfieldData.side <- blk.groups.item.owner.side

    let iconOverride = blk.iconOverride != "" ? blk.iconOverride : "default"
    airfieldData.airfieldTextures <- getSettings("airfieldsTex")[iconOverride]
    return airfieldData
  }))
}

function getAirfieldByPoint(point) {
  let zone = getZoneByPoint(point)
  if (zone == null)
    return null

  return airfieldsInfo.get().findvalue(@(v) v.ownedZoneId == zone.id)
}

function updateSelectedAirfield(airfieldData) {
  selectedAirfield.set(airfieldData)
  let params = { airfieldIdx = airfieldData?.airfieldIdx ?? -1 }
  wwClearOutlinedZones()
  wwSelectAirfield(params.airfieldIdx)
  sendToDagui("ww.selectAirfield", params)
}

function updateAirfieldsStates() {
  let index = wwGetSelectedAirfield()
  if (index == -1 || airfieldsInfo.get().len() - 1 < index || selectedAirfield.get()?["airfieldIdx"] == index)
    return

  selectedAirfield.set(airfieldsInfo.get()[index])
}

let updateHoveredAirfield = @(airfieldData) hoveredAirfield.set(airfieldData)
subscribe("ww.unselectAirfield", @(_v) updateSelectedAirfield(null))

return {
  updateAirfieldsData
  airfieldsInfo
  getAirfieldByPoint
  updateHoveredAirfield
  hoveredAirfield
  updateSelectedAirfield
  hoveredAirfieldIndex
  selectedAirfield
  updateAirfieldsStates
}