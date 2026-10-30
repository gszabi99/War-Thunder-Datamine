from "%scripts/events/eventsState.nut" import isEventMultiSlotEnabled
from "%scripts/events/eventTeamsInfo.nut" import isUnitAllowedForEvent
from "%scripts/slotbar/crewsList.nut" import getCrewsListByCountry
from "%scripts/crew/crew.nut" import getCrewUnit
from "%scripts/unit/unitStatus.nut" import isUnitBroken
from "%scripts/dagui_library.nut" import *





function getSlotbarRank(event, country, idInCountry) {
  local res = 0
  let isMultiSlotEnabled = isEventMultiSlotEnabled(event)
  foreach (idx, crew in getCrewsListByCountry(country)) {
    if (!isMultiSlotEnabled && idInCountry != idx)
      continue

    let unit = getCrewUnit(crew)
    if (!unit)
      continue
    if (!isUnitAllowedForEvent(event, unit))
      continue
    if (isUnitBroken(unit))
      continue

    res = max(res, unit.rank)
  }
  return res
}

return freeze({
  getSlotbarRank
})
