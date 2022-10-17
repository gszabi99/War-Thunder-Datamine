from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

/*
 Short tie cache for current viewing crew with selected unit
 saved only for one crew,
 Reset on:
   * save data for another crew
   * crew skills change
   * crew new skills change
   * crew unit change
*/

::g_crew_short_cache <- {
  cache = {}
  cacheCrewid = -1
  unit = null
}

::g_crew_short_cache.resetCache <- function resetCache(newCrewId, newUnit = null)
{
  cache.clear()
  cacheCrewid = newCrewId
  unit = newUnit ?? ::g_crew.getCrewUnit(::get_crew_by_id(cacheCrewid))
}

::g_crew_short_cache.getData <- function getData(crewId, newUnit, cacheUid)
{
  if (crewId != cacheCrewid || newUnit != unit)
    return null
  return getTblValue(cacheUid, cache)
}

::g_crew_short_cache.setData <- function setData(crewId, newUnit, cacheUid, data)
{
  if (crewId != cacheCrewid || newUnit != unit)
    resetCache(crewId, newUnit)
  cache[cacheUid] <- data
}

::g_crew_short_cache.onEventCrewSkillsChanged <- function onEventCrewSkillsChanged(params)
{
  resetCache(cacheCrewid, unit)
}

::g_crew_short_cache.onEventCrewNewSkillsChanged <- function onEventCrewNewSkillsChanged(params)
{
  resetCache(cacheCrewid, unit)
}

::g_crew_short_cache.onEventCrewTakeUnit <- function onEventCrewTakeUnit(params)
{
  resetCache(cacheCrewid)
}

::g_crew_short_cache.onEventQualificationIncreased <- function onEventQualificationIncreased(params)
{
  resetCache(cacheCrewid, unit)
}

::g_crew_short_cache.onEventCrewSkillsReloaded <- function onEventCrewSkillsReloaded(params)
{
  resetCache(cacheCrewid, unit)
}

::subscribe_handler(::g_crew_short_cache, ::g_listener_priority.UNIT_CREW_CACHE_UPDATE)