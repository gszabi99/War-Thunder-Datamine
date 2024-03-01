from "%scripts/dagui_library.nut" import *
let { getPlayerCurUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let getAllUnits = require("%scripts/unit/allUnits.nut")
let { getCrewUnit } = require("%scripts/crew/crew.nut")

function getMatchedUnitRankForHelp(unitMatchFn) {
  let curUnit = getPlayerCurUnit()
  if (unitMatchFn(curUnit))
    return curUnit.rank

  let curCountrySlotbarMatchedUnits = (::g_crews_list.get()
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