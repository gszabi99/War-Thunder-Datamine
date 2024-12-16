from "%scripts/dagui_natives.nut" import ww_get_rear_zones, ww_side_val_to_name
from "%scripts/dagui_library.nut" import *

let DataBlock  = require("DataBlock")
let { wwGetZoneSideByName } = require("worldwar")

let curOperationCountry = mkWatched(persist, "curOperationCountry", null)

local rearZones = null

function updateRearZones() {
  let blk = DataBlock()
  ww_get_rear_zones(blk)

  rearZones = {}
  foreach (zoneName, zoneOwner in blk) {
    let sideName = ww_side_val_to_name(zoneOwner)
    if (!(sideName in rearZones))
      rearZones[sideName] <- []

    rearZones[sideName].append(zoneName)
  }
}

function getRearZones() {
  if (!rearZones)
    updateRearZones()

  return rearZones
}

function getRearZonesBySide(side) {
  return getRearZones()?[ww_side_val_to_name(side)] ?? []
}

function getRearZonesOwnedToSide(side) {
  return getRearZonesBySide(side).filter(@(zone) wwGetZoneSideByName(zone) == side)
}

function getRearZonesLostBySide(side) {
  return getRearZonesBySide(side).filter(@(zone) wwGetZoneSideByName(zone) != side)
}

return {
  curOperationCountry
  invalidateRearZones = @() rearZones = null
  getRearZones
  getRearZonesOwnedToSide
  getRearZonesLostBySide
}