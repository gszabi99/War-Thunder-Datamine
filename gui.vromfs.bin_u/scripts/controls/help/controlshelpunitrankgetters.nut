from "%scripts/unit/unitsData.nut" import getAllUnits
from "%scripts/slotbar/playerCurUnit.nut" import getPlayerCurUnit
from "%scripts/user/playerCountry.nut" import profileCountrySq
from "%scripts/crew/crew.nut" import getCrewUnit
from "%scripts/slotbar/crewsList.nut" import getCrewsList
from "%scripts/dagui_library.nut" import *

function getMatchedUnitRankForHelp(unitMatchFn) {
  let curUnit = getPlayerCurUnit()
  if (curUnit != null && unitMatchFn(curUnit))
    return curUnit.rank

  let curCountrySlotbarMatchedUnits = (getCrewsList()
    .findvalue(@(crew) crew.country == profileCountrySq.get())?.crews ?? [])
    .map(@(crew) getCrewUnit(crew))
    .filter(@(unit) unit != null && unitMatchFn(unit))
  if (curCountrySlotbarMatchedUnits.len() > 0)
    return curCountrySlotbarMatchedUnits.reduce(@(maxRank, u) max(maxRank, u.rank), 0)

  return getAllUnits()
    .filter(@(unit) unit != null && unit.isBought() && unitMatchFn(unit))
    .reduce(@(maxRank, u) max(maxRank, u.rank), 0)
}

return freeze({
  getTankRankForHelp = @() getMatchedUnitRankForHelp(@(unit) unit.isTank())
})