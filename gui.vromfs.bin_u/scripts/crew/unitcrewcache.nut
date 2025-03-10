from "%scripts/dagui_natives.nut" import get_aircraft_crew_blk
from "%scripts/dagui_library.nut" import *


let g_listener_priority = require("%scripts/g_listener_priority.nut")
let { add_event_listener } = require("%sqStdLibs/helpers/subscriptions.nut")
let { convertBlk } = require("%sqstd/datablock.nut")






::g_unit_crew_cache <- {
  lastUnitCrewData = null
  lastUnitCrewId = -1
  lastUnitName = ""

  function invalidateCache() {
    this.lastUnitCrewId = -1
    this.lastUnitName = ""
  }

  function getUnitCrewDataById(crewId, unit) {
    if (crewId == null)
      return null

    let unitName = unit?.name ?? ""
    if (crewId != this.lastUnitCrewId || unitName != this.lastUnitName) {
      this.lastUnitCrewId = crewId
      this.lastUnitName = unitName
      let unitCrewBlk = get_aircraft_crew_blk(this.lastUnitCrewId, this.lastUnitName)
      this.lastUnitCrewData = convertBlk(unitCrewBlk)
    }
    return this.lastUnitCrewData
  }

  function initCache() {
    add_event_listener("CrewSkillsChanged", this.onEventCrewSkillsChanged,
      this, g_listener_priority.UNIT_CREW_CACHE_UPDATE)
    add_event_listener("QualificationIncreased", @(_p) this.invalidateCache(),
      this, g_listener_priority.UNIT_CREW_CACHE_UPDATE)
    add_event_listener("CrewChanged", this.onEventCrewChanged,
      this, g_listener_priority.UNIT_CREW_CACHE_UPDATE)
  }

  function onEventCrewSkillsChanged(_params) {
    this.invalidateCache()
  }

  function onEventCrewChanged(_params) {
    this.invalidateCache()
  }

}

::g_unit_crew_cache.initCache()
