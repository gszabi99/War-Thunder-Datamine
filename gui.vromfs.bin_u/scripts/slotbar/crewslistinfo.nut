from "%scripts/dagui_natives.nut" import wp_get_repair_cost
from "%scripts/dagui_library.nut" import *

let g_listener_priority = require("%scripts/g_listener_priority.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { getCrewsList } = require("%scripts/slotbar/crewsList.nut")

local unitsStateCached = null

function getMyCrewUnitsState(country = null) {
  if (unitsStateCached != null)
    return unitsStateCached

  country = country ?? profileCountrySq.get()

  unitsStateCached = {
    crewAirs = {}
    brokenAirs = []
    rank = 0
  }

  foreach (c in getCrewsList()) {
    if (!("crews" in c))
      continue

    let crewAirs = []
    foreach (crew in c.crews)
      if (("aircraft" in crew) && crew.aircraft != "" && crew.isLocked == 0) {
        let air = getAircraftByName(crew.aircraft)
        if (air) {
          crewAirs.append(crew.aircraft)
          if (c.country == country && unitsStateCached.rank < air.rank)
            unitsStateCached.rank = air.rank
          if (wp_get_repair_cost(crew.aircraft) > 0)
            unitsStateCached.brokenAirs.append(crew.aircraft)
        }
      }

    let preset = ::slotbarPresets.getCurrentPreset(c.country)
    if(preset != null)
      crewAirs.replace(preset.orderedUnits.filter(@(unit) crewAirs.indexof(unit) != -1))

    unitsStateCached.crewAirs[c.country] <- crewAirs
  }

  return unitsStateCached
}

function getBrokenUnits() {
  let brokenUnits = {}
  foreach (c in getCrewsList()) {
    if (!("crews" in c))
      continue
    foreach (crew in c.crews)
      if (("aircraft" in crew) && crew.aircraft != "" && crew.isLocked == 0
        && getAircraftByName(crew.aircraft) && wp_get_repair_cost(crew.aircraft) > 0)
        brokenUnits[crew.aircraft] <- true
  }
  return brokenUnits
}

addListenersWithoutEnv({
  CrewsListChanged = @(_p) unitsStateCached = null
  CrewsListInvalidate = @(_p) unitsStateCached = null
  SlotbarPresetChangedWithoutProfileUpdate = @(_p) unitsStateCached = null
  CrewsOrderChanged = @(_p) unitsStateCached = null
  UnitRepaired = @(_p) unitsStateCached = null
}, g_listener_priority.CONFIG_VALIDATION)

return {
  getMyCrewUnitsState
  getBrokenUnits
}
