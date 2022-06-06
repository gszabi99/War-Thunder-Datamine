let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")

let function onEventProfileUpdated(p) {
  let crewsList = ::get_crew_info()
  local hasLockedCrew = false

  foreach(countryCrew in crewsList)
    foreach(idx, crew in countryCrew.crews)
      if (crew.lockedTillSec > 0 || crew.isLocked)
      {
        hasLockedCrew = true
        ::dagor.debug($"[CREW_LOCK] Crew {crew.country} №{idx} isLocked: {crew.isLocked} with lockedTillSec={crew.lockedTillSec}")
        return
      }
  if (!hasLockedCrew)
    ::dagor.debug("[CREW_LOCK] All crews unlocked")
}

addListenersWithoutEnv({
  ProfileUpdated = @(p) onEventProfileUpdated(p)
})
