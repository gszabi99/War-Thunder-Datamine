from "%scripts/dagui_library.nut" import *

let getAllUnits = require("%scripts/unit/allUnits.nut")
let { canResearchUnit } = require("%scripts/unit/unitInfo.nut")
let { isInMenu } = require("%scripts/baseGuiHandlerManagerWT.nut")

let isAllClanUnitsResearched = @() getAllUnits().findvalue(
  @(unit) unit.isSquadronVehicle() && unit.isVisibleInShop() && canResearchUnit(unit)
) == null

let function needChooseClanUnitResearch() {
  if (!::is_in_clan() || !hasFeature("ClanVehicles")
      || isAllClanUnitsResearched())
    return false

  let researchingUnitName = ::clan_get_researching_unit()
  if (researchingUnitName == "")
    return true

  let unit = getAircraftByName(researchingUnitName)
  if (!unit || !unit.isVisibleInShop())
    return false

  let curSquadronExp = ::clan_get_exp()
  if (curSquadronExp <= 0 || (curSquadronExp < (unit.reqExp - ::getUnitExp(unit))))
    return false

  return true
}

let function isHaveNonApprovedClanUnitResearches() {
  if (!isInMenu() || ::checkIsInQueue())
    return false

  return needChooseClanUnitResearch()
}

return {
  isAllClanUnitsResearched
  isHaveNonApprovedClanUnitResearches
  needChooseClanUnitResearch
}