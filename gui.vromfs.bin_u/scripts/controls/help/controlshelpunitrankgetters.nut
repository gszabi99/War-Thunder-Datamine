from "%scripts/dagui_library.nut" import *
let { getPlayerCurUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let getAllUnits = require("%scripts/unit/allUnits.nut")
let { getCrewUnit } = require("%scripts/crew/crew.nut")
let { getCrewsList } = require("%scripts/slotbar/crewsList.nut")

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

return {
  getTankRankForHelp = @() getMatchedUnitRankForHelp(@(unit) unit.isTank())
}