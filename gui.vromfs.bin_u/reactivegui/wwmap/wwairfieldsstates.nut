from "%rGui/globals/ui_library.nut" import *

let DataBlock = require("DataBlock")
let { wwGetAirfieldsCount, wwGetAirfieldInfo, wwClearOutlinedZones,
  wwSelectAirfield } = require("worldwar")

let { getZoneByPoint } = require("%rGui/wwMap/wwMapZonesData.nut")
let { getSettings } = require("%rGui/wwMap/wwSettings.nut")
let { sendToDagui } = require("%rGui/wwMap/wwMapUtils.nut")
let { convertToRelativeMapCoords } = require("%rGui/wwMap/wwOperationConfiguration.nut")

let airfieldsInfo = Watched([])

let selectedAirfield = Watched(null)
let hoveredAirfield = Watched(null)

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
    airfieldData.aircraftTextures <- getSettings("airfieldsTex")[iconOverride]
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

let updateHoveredAirfield = @(airfieldData) hoveredAirfield.set(airfieldData)

return {
  updateAirfieldsData
  airfieldsInfo
  getAirfieldByPoint
  updateHoveredAirfield
  hoveredAirfield
  updateSelectedAirfield
  selectedAirfield
}