from "%sqStdLibs/helpers/subscriptions.nut" import add_event_listener
from "%sqstd/datablock.nut" import convertBlk
from "%scripts/dagui_natives.nut" import get_aircraft_crew_blk
from "%scripts/dagui_library.nut" import *

let g_listener_priority = require("%scripts/g_listener_priority.nut")






let unitCrewDataCache = {}

function invalidateCache() {
  unitCrewDataCache.clear()
}

function getUnitCrewDataById(crewId, unit) {
  if (crewId == null)
    return null

  let unitName = unit?.name ?? ""
  let key = $"crew{crewId}_{unitName}"

  if (key not in unitCrewDataCache)
    unitCrewDataCache[key] <- convertBlk(get_aircraft_crew_blk(crewId, unitName))

  return unitCrewDataCache[key]
}

let onNeedReset = @(_p) invalidateCache()

add_event_listener("CrewSkillsChanged", onNeedReset, null, g_listener_priority.UNIT_CREW_CACHE_UPDATE)
add_event_listener("QualificationIncreased", onNeedReset, null, g_listener_priority.UNIT_CREW_CACHE_UPDATE)
add_event_listener("CrewChanged", onNeedReset, null, g_listener_priority.UNIT_CREW_CACHE_UPDATE)

return {
  getUnitCrewDataById
}
