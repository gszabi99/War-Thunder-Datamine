from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

//
// Unit crew data cache.
// Used to speed up 'get_aircraft_crew_by_id' calls.
//

::g_unit_crew_cache <- {
  lastUnitCrewData = null
  lastUnitCrewId = -1
  lastUnitName = ""

  function invalidateCache() {
    lastUnitCrewId = -1
    lastUnitName = ""
  }
}

::g_unit_crew_cache.getUnitCrewDataById <- function getUnitCrewDataById(crewId, unit)
{
  if (crewId == null)
    return null

  let unitName = unit?.name ?? ""
  if (crewId != lastUnitCrewId || unitName != lastUnitName)
  {
    lastUnitCrewId = crewId
    lastUnitName = unitName
    let unitCrewBlk = ::get_aircraft_crew_blk(lastUnitCrewId, lastUnitName)
    lastUnitCrewData = ::buildTableFromBlk(unitCrewBlk)
  }
  return lastUnitCrewData
}

::g_unit_crew_cache.initCache <- function initCache()
{
  ::add_event_listener("CrewSkillsChanged", onEventCrewSkillsChanged,
    this, ::g_listener_priority.UNIT_CREW_CACHE_UPDATE)
  ::add_event_listener("QualificationIncreased", @(p) invalidateCache(),
    this, ::g_listener_priority.UNIT_CREW_CACHE_UPDATE)
  ::add_event_listener("CrewChanged", onEventCrewChanged,
    this, ::g_listener_priority.UNIT_CREW_CACHE_UPDATE)
}

::g_unit_crew_cache.onEventCrewSkillsChanged <- function onEventCrewSkillsChanged(params)
{
  invalidateCache()
}

::g_unit_crew_cache.onEventCrewChanged <- function onEventCrewChanged(params)
{
  invalidateCache()
}

::g_unit_crew_cache.initCache()
