from "%scripts/dagui_natives.nut" import clan_get_exp, clan_get_researching_unit
from "%scripts/dagui_library.nut" import *
from "%scripts/clans/clanState.nut" import is_in_clan

let getAllUnits = require("%scripts/unit/allUnits.nut")
let { getUnitExp } = require("%scripts/unit/unitInfo.nut")
let { canResearchUnit } = require("%scripts/unit/unitStatus.nut")
let { isInMenu } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { isAnyQueuesActive } = require("%scripts/queue/queueState.nut")

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
  if (!isInMenu() || isAnyQueuesActive())
    return false

  return needChooseClanUnitResearch()
}

return {
  isAllClanUnitsResearched
  isHaveNonApprovedClanUnitResearches
  needChooseClanUnitResearch
}