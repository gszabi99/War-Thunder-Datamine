from "%scripts/squads/squadManager.nut" import g_squad_manager
from "%scripts/worldWar/inOperation/wwOperationStates.nut" import curOperationCountry
from "%scripts/dagui_library.nut" import *

function getLockedCountryDataBySquad() {
  let operationcountry = g_squad_manager.getWwOperationCountry()
  if (operationcountry == "" || g_squad_manager.getWwOperationBattle() == null
    || g_squad_manager.getWwOperationId() < 0)
    return null

  return {
    availableCountries = [operationcountry]
    reasonText = loc("worldWar/cantChangeCountryInBattlePrepare")
  }
}

function getLockedCountryData() {
  if (curOperationCountry.get() == null)
    return getLockedCountryDataBySquad()

  return {
    availableCountries = [curOperationCountry.get()]
    reasonText = loc("worldWar/cantChangeCountryInOperation")
  }
}

return getLockedCountryData
