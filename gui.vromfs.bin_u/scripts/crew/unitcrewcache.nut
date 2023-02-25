//checked for plus_string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

//
// Unit crew data cache.
// Used to speed up 'get_aircraft_crew_by_id' calls.
//

::g_unit_crew_cache <- {
  lastUnitCrewData = null
  lastUnitCrewId = -1
  lastUnitName = ""

  function invalidateCache() {
    this.lastUnitCrewId = -1
    this.lastUnitName = ""
  }
}

::g_unit_crew_cache.getUnitCrewDataById <- function getUnitCrewDataById(crewId, unit) {
  if (crewId == null)
    return null

  let unitName = unit?.name ?? ""
  if (crewId != this.lastUnitCrewId || unitName != this.lastUnitName) {
    this.lastUnitCrewId = crewId
    this.lastUnitName = unitName
    let unitCrewBlk = ::get_aircraft_crew_blk(this.lastUnitCrewId, this.lastUnitName)
    this.lastUnitCrewData = ::buildTableFromBlk(unitCrewBlk)
  }
  return this.lastUnitCrewData
}

::g_unit_crew_cache.initCache <- function initCache() {
  ::add_event_listener("CrewSkillsChanged", this.onEventCrewSkillsChanged,
    this, ::g_listener_priority.UNIT_CREW_CACHE_UPDATE)
  ::add_event_listener("QualificationIncreased", @(_p) this.invalidateCache(),
    this, ::g_listener_priority.UNIT_CREW_CACHE_UPDATE)
  ::add_event_listener("CrewChanged", this.onEventCrewChanged,
    this, ::g_listener_priority.UNIT_CREW_CACHE_UPDATE)
}

::g_unit_crew_cache.onEventCrewSkillsChanged <- function onEventCrewSkillsChanged(_params) {
  this.invalidateCache()
}

::g_unit_crew_cache.onEventCrewChanged <- function onEventCrewChanged(_params) {
  this.invalidateCache()
}

::g_unit_crew_cache.initCache()
