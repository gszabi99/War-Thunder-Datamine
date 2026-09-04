from "%scripts/dagui_library.nut" import *

let { isEventMultiSlotEnabled } = require("%scripts/events/eventsState.nut")
let { isUnitAllowedForEvent } = require("%scripts/events/eventTeamsInfo.nut")
let { getCrewsListByCountry } = require("%scripts/slotbar/crewsList.nut")
let { getCrewUnit } = require("%scripts/crew/crew.nut")
let { isUnitBroken } = require("%scripts/unit/unitStatus.nut")





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

return {
  getSlotbarRank
}
