from "%rGui/globals/darg_library.nut" import *
let { setInterval, clearTimer } = require("dagor.workcycle")
let { isEqual } = require("%sqstd/underscore.nut")
let { getCaptureZones, CZ_IS_HIDDEN } = require("guiMission")

const CAP_ZONES_STATE_POLLING_INTERVAL = 1

let capZones = Watched([])

let function prevIfEqualList(cur, prev) {
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
  prevIfEqualList(getCaptureZones().filter(@(c) (c.flags & CZ_IS_HIDDEN) == 0), capZones.value))

let function startPollingZonesState() {
  clearTimer(updateCapZones)
  updateCapZones()
  setInterval(CAP_ZONES_STATE_POLLING_INTERVAL, updateCapZones)
}

let function stopPollingZonesState() {
  clearTimer(updateCapZones)
}

return {
  capZones
  startPollingZonesState
  stopPollingZonesState
}