import "DataBlock" as DataBlock
from "dagor.workcycle" import setInterval, clearTimer
from "%sqstd/underscore.nut" import isEqual
from "eventbus" import eventbus_subscribe, eventbus_unsubscribe
from "guiMission" import getCaptureZones, CZ_IS_HIDDEN, get_current_mission_desc
from "%rGui/globals/darg_library.nut" import *
from "%rGui/globalState.nut" import isInFlight

const CAP_ZONES_STATE_POLLING_INTERVAL = 1
const CAPTURE_ZONE_CHANGED_EVENT = "captureZoneChanged"

let capZones = Watched([])


function readCaptureZoneStateIcons() {
  let misBlk = DataBlock()
  get_current_mission_desc(misBlk)
  return misBlk.getBool("captureZoneStateIcons", false)
}

let captureZoneStateIcons = Computed(@()
  isInFlight.get() ? readCaptureZoneStateIcons() : false
)

function prevIfEqualList(cur, prev) {
  let minLen = min(cur.len(), prev.len())
  local hasChanges = cur.len() != prev.len()
  for (local i = 0; i < minLen; i++)
    if (isEqual(cur[i], prev[i]))
      cur[i] = prev[i]
    else
      hasChanges = true
  return hasChanges ? cur : prev
}

let updateCapZones = @() capZones.set(
  prevIfEqualList(
    getCaptureZones(captureZoneStateIcons.get())
      .filter(@(c) (c.flags & CZ_IS_HIDDEN) == 0), capZones.get()
  ))

let onZoneChanged = @(_) updateCapZones()

function startPollingZonesState() {
  clearTimer(updateCapZones)
  updateCapZones()
  setInterval(CAP_ZONES_STATE_POLLING_INTERVAL, updateCapZones)
  eventbus_subscribe(CAPTURE_ZONE_CHANGED_EVENT, onZoneChanged)
}

function stopPollingZonesState() {
  clearTimer(updateCapZones)
  eventbus_unsubscribe(CAPTURE_ZONE_CHANGED_EVENT, onZoneChanged)
}

return freeze({
  capZones
  captureZoneStateIcons
  startPollingZonesState
  stopPollingZonesState
})