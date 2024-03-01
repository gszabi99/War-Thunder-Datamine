from "%scripts/dagui_natives.nut" import get_crew_info
from "%scripts/dagui_library.nut" import *

let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")

function onEventProfileUpdated(_p) {
  let crewsList = get_crew_info()
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
