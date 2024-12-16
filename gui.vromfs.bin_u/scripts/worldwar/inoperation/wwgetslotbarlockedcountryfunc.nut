from "%scripts/dagui_library.nut" import *

let { getGlobalModule } = require("%scripts/global_modules.nut")
let g_squad_manager = getGlobalModule("g_squad_manager")
let { curOperationCountry } = require("%scripts/worldWar/inOperation/wwOperationStates.nut")

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
