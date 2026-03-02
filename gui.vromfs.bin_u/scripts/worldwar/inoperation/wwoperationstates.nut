from "%scripts/dagui_library.nut" import *
from "%scripts/dagui_natives.nut" import ww_get_rear_zones,
  ww_side_val_to_name, ww_get_operation_objectives

let time = require("%scripts/time.nut")
let DataBlock  = require("DataBlock")
let {
  wwGetZoneSideByName, wwGetOperationId, wwGetPlayerSide, wwGetOperationTimeMillisec
} = require("worldwar")

let curOperationCountry = mkWatched(persist, "curOperationCountry", null)


const WW_LAST_OPERATION_LOG_SAVE_ID = "worldWar/lastReadLog/operation"

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


function getSaveOperationLogId() {
  return $"{WW_LAST_OPERATION_LOG_SAVE_ID}{wwGetOperationId()}"
}


function getOperationObjectives() {
  let blk = DataBlock()
  ww_get_operation_objectives(blk)
  return blk
}


function getOppositeSide(side) {
  return side == SIDE_2 ? SIDE_1 : SIDE_2
}


function getSidesOrder() {
  local playerSide = wwGetPlayerSide()
  if (playerSide == SIDE_NONE)
    playerSide = SIDE_1

  let enemySide = getOppositeSide(playerSide)
  return [ playerSide, enemySide ]
}


let getOperationTimeSec = @()
  time.millisecondsToSecondsInt(wwGetOperationTimeMillisec())


return {
  curOperationCountry
  invalidateRearZones = @() rearZones = null
  getRearZones
  getRearZonesOwnedToSide
  getRearZonesLostBySide
  getSaveOperationLogId
  getOperationObjectives
  getOppositeSide
  getSidesOrder
  getOperationTimeSec
}