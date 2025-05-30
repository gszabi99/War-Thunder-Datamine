from "%scripts/dagui_natives.nut" import get_aircraft_crew_blk
from "%scripts/dagui_library.nut" import *

let g_listener_priority = require("%scripts/g_listener_priority.nut")
let { add_event_listener } = require("%sqStdLibs/helpers/subscriptions.nut")
let { convertBlk } = require("%sqstd/datablock.nut")






local lastUnitCrewData = null
local lastUnitCrewId = -1
local lastUnitName = ""

function invalidateCache() {
  lastUnitCrewData = null
  lastUnitCrewId = -1
  lastUnitName = ""
}

function getUnitCrewDataById(crewId, unit) {
  if (crewId == null)
    return null

  let unitName = unit?.name ?? ""
  if (crewId != lastUnitCrewId || unitName != lastUnitName) {
    lastUnitCrewId = crewId
    lastUnitName = unitName
    let unitCrewBlk = get_aircraft_crew_blk(lastUnitCrewId, lastUnitName)
    lastUnitCrewData = convertBlk(unitCrewBlk)
  }
  return lastUnitCrewData
}

let onNeedReset = @(_p) invalidateCache()

add_event_listener("CrewSkillsChanged", onNeedReset, null, g_listener_priority.UNIT_CREW_CACHE_UPDATE)
add_event_listener("QualificationIncreased", onNeedReset, null, g_listener_priority.UNIT_CREW_CACHE_UPDATE)
add_event_listener("CrewChanged", onNeedReset, null, g_listener_priority.UNIT_CREW_CACHE_UPDATE)

return {
  getUnitCrewDataById
}
