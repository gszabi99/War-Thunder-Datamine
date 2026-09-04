from "dagor.workcycle" import setInterval, clearTimer
from "%sqstd/underscore.nut" import isEqual
from "guiMission" import getCaptureZones, CZ_IS_HIDDEN
from "%rGui/globals/darg_library.nut" import *

const CAP_ZONES_STATE_POLLING_INTERVAL = 1

let capZones = Watched([])

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
  prevIfEqualList(getCaptureZones().filter(@(c) (c.flags & CZ_IS_HIDDEN) == 0), capZones.get()))

function startPollingZonesState() {
  clearTimer(updateCapZones)
  updateCapZones()
  setInterval(CAP_ZONES_STATE_POLLING_INTERVAL, updateCapZones)
}

function stopPollingZonesState() {
  clearTimer(updateCapZones)
}

return {
  capZones
  startPollingZonesState
  stopPollingZonesState
}