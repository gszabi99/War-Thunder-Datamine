from "%scripts/unit/unitsData.nut" import getAllUnits
from "%scripts/unit/unitInfo.nut" import getUnitExp
from "%scripts/unit/unitStatus.nut" import canResearchUnit
from "%scripts/clientState/clientStates.nut" import isInMenu
from "%scripts/queue/queueState.nut" import isAnyQueuesActive
from "%scripts/dagui_natives.nut" import clan_get_exp, clan_get_researching_unit
from "%scripts/dagui_library.nut" import *
from "%scripts/clans/clanState.nut" import is_in_clan

let isAllClanUnitsResearched = @() getAllUnits().findvalue(
  @(unit) unit.isSquadronVehicle() && unit.isVisibleInShop() && canResearchUnit(unit)
) == null

function needChooseClanUnitResearch() {
  if (!is_in_clan() || !hasFeature("ClanVehicles")
      || isAllClanUnitsResearched())
    return false

  let researchingUnitName = clan_get_researching_unit()
  if (researchingUnitName == "")
    return true

  let unit = getAircraftByName(researchingUnitName)
  if (!unit || !unit.isVisibleInShop())
    return false

  let curSquadronExp = clan_get_exp()
  if (curSquadronExp <= 0 || (curSquadronExp < (unit.reqExp - getUnitExp(unit))))
    return false

  return true
}

function isHaveNonApprovedClanUnitResearches() {
  if (!isInMenu.get() || isAnyQueuesActive())
    return false
  
  if (hasFeature("AutoFlushClanExp") && clan_get_researching_unit() != "")
    return false

  return needChooseClanUnitResearch()
}

return freeze({
  isAllClanUnitsResearched
  isHaveNonApprovedClanUnitResearches
  needChooseClanUnitResearch
})