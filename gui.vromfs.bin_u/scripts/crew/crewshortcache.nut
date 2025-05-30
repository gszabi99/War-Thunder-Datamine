from "%scripts/dagui_library.nut" import *

let { UNIT_CREW_CACHE_UPDATE } = require("%scripts/g_listener_priority.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { getCrewById } = require("%scripts/slotbar/crewsList.nut")
let { getCrewUnit } = require("%scripts/crew/crew.nut")









let cache = {}

local cacheCrewId = -1
local unit = null

let getCachedCrewId = @() cacheCrewId
let getCachedCrewUnit = @() unit

function resetCache(newCrewId, newUnit = null) {
  cache.clear()
  cacheCrewId = newCrewId
  unit = newUnit ?? getCrewUnit(getCrewById(cacheCrewId))
}

function getCachedCrewData(crewId, newUnit, cacheUid) {
  if (crewId != cacheCrewId || newUnit != unit)
    return null
  return getTblValue(cacheUid, cache)
}

function cacheCrewData(crewId, newUnit, cacheUid, data) {
  if (crewId != cacheCrewId || newUnit != unit)
    resetCache(crewId, newUnit)
  cache[cacheUid] <- data
}

addListenersWithoutEnv({
  CrewSkillsChanged = @(_p) resetCache(cacheCrewId, unit)
  CrewNewSkillsChanged = @(_p) resetCache(cacheCrewId, unit)
  CrewTakeUnit = @(_p) resetCache(cacheCrewId)
  QualificationIncreased = @(_p) resetCache(cacheCrewId, unit)
  CrewSkillsReloaded = @(_p)resetCache(cacheCrewId, unit)
  ModificationChanged = @(_p)resetCache(cacheCrewId, unit)
}, UNIT_CREW_CACHE_UPDATE)

return {
  cacheCrewData
  getCachedCrewData
  getCachedCrewId
  getCachedCrewUnit
}