//checked for plus_string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

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

::g_crew_short_cache.resetCache <- function resetCache(newCrewId, newUnit = null) {
  this.cache.clear()
  this.cacheCrewid = newCrewId
  this.unit = newUnit ?? ::g_crew.getCrewUnit(::get_crew_by_id(this.cacheCrewid))
}

::g_crew_short_cache.getData <- function getData(crewId, newUnit, cacheUid) {
  if (crewId != this.cacheCrewid || newUnit != this.unit)
    return null
  return getTblValue(cacheUid, this.cache)
}

::g_crew_short_cache.setData <- function setData(crewId, newUnit, cacheUid, data) {
  if (crewId != this.cacheCrewid || newUnit != this.unit)
    this.resetCache(crewId, newUnit)
  this.cache[cacheUid] <- data
}

::g_crew_short_cache.onEventCrewSkillsChanged <- function onEventCrewSkillsChanged(_params) {
  this.resetCache(this.cacheCrewid, this.unit)
}

::g_crew_short_cache.onEventCrewNewSkillsChanged <- function onEventCrewNewSkillsChanged(_params) {
  this.resetCache(this.cacheCrewid, this.unit)
}

::g_crew_short_cache.onEventCrewTakeUnit <- function onEventCrewTakeUnit(_params) {
  this.resetCache(this.cacheCrewid)
}

::g_crew_short_cache.onEventQualificationIncreased <- function onEventQualificationIncreased(_params) {
  this.resetCache(this.cacheCrewid, this.unit)
}

::g_crew_short_cache.onEventCrewSkillsReloaded <- function onEventCrewSkillsReloaded(_params) {
  this.resetCache(this.cacheCrewid, this.unit)
}

::subscribe_handler(::g_crew_short_cache, ::g_listener_priority.UNIT_CREW_CACHE_UPDATE)