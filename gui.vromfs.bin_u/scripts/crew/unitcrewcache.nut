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

g_unit_crew_cache.getUnitCrewDataById <- function getUnitCrewDataById(crewId, unit)
{
  if (unit == null || crewId == null)
    return null

  if (crewId != lastUnitCrewId || unit.name != lastUnitName)
  {
    lastUnitCrewId = crewId
    lastUnitName = unit.name
    local unitCrewBlk = ::get_aircraft_crew_blk(lastUnitCrewId, lastUnitName)
    lastUnitCrewData = ::buildTableFromBlk(unitCrewBlk)
  }
  return lastUnitCrewData
}

g_unit_crew_cache.initCache <- function initCache()
{
  ::add_event_listener("CrewSkillsChanged", onEventCrewSkillsChanged,
    this, ::g_listener_priority.UNIT_CREW_CACHE_UPDATE)
  ::add_event_listener("QualificationIncreased", @(p) invalidateCache(),
    this, ::g_listener_priority.UNIT_CREW_CACHE_UPDATE)
  ::add_event_listener("CrewChanged", onEventCrewChanged,
    this, ::g_listener_priority.UNIT_CREW_CACHE_UPDATE)
}

g_unit_crew_cache.onEventCrewSkillsChanged <- function onEventCrewSkillsChanged(params)
{
  invalidateCache()
}

g_unit_crew_cache.onEventCrewChanged <- function onEventCrewChanged(params)
{
  invalidateCache()
}

::g_unit_crew_cache.initCache()
