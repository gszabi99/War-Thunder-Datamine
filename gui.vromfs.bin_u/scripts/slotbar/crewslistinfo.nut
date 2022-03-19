local { addListenersWithoutEnv } = require("sqStdLibs/helpers/subscriptions.nut")

local unitsStateCached = null

local function getMyCrewUnitsState(country = null) {
  if (unitsStateCached != null)
    return unitsStateCached

  country = country ?? ::get_profile_country_sq()

  unitsStateCached = {
    crewAirs = {}
    brokenAirs = []
    rank = 0
  }

  foreach(c in ::g_crews_list.get()) {
    if (!("crews" in c))
      continue

    unitsStateCached.crewAirs[c.country] <- []
    foreach(crew in c.crews)
      if (("aircraft" in crew) && crew.aircraft!="") {
        local air = getAircraftByName(crew.aircraft)
        if (air) {
          unitsStateCached.crewAirs[c.country].append(crew.aircraft)
          if (c.country == country && unitsStateCached.rank < air.rank)
            unitsStateCached.rank = air.rank
          if (::wp_get_repair_cost(crew.aircraft) > 0)
            unitsStateCached.brokenAirs.append(crew.aircraft)
        }
      }
  }

  return unitsStateCached
}

addListenersWithoutEnv({
  CrewsListChanged = @(p) unitsStateCached = null
  CrewsListInvalidate = @(p) unitsStateCached = null
}, ::g_listener_priority.CONFIG_VALIDATION)

return {
  getMyCrewUnitsState = getMyCrewUnitsState
}

