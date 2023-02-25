//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")

let function onEventProfileUpdated(_p) {
  let crewsList = ::get_crew_info()
  local hasLockedCrew = false

  foreach (countryCrew in crewsList)
    foreach (idx, crew in countryCrew.crews)
      if (crew.lockedTillSec > 0 || crew.isLocked) {
        hasLockedCrew = true
        log($"[CREW_LOCK] Crew {crew.country} №{idx} isLocked: {crew.isLocked} with lockedTillSec={crew.lockedTillSec}")
        return
      }
  if (!hasLockedCrew)
    log("[CREW_LOCK] All crews unlocked")
}

addListenersWithoutEnv({
  ProfileUpdated = @(p) onEventProfileUpdated(p)
})
