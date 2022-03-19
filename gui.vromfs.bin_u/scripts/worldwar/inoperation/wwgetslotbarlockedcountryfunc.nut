local function getLockedCountryDataBySquad() {
  local operationcountry = ::g_squad_manager.getWwOperationCountry()
  if (operationcountry == "" || ::g_squad_manager.getWwOperationBattle() == null
    || ::g_squad_manager.getWwOperationId() < 0)
    return null

  return {
    availableCountries = [operationcountry]
    reasonText = ::loc("worldWar/cantChangeCountryInBattlePrepare")
  }
}

local function getLockedCountryData() {
  local curOperationCountry = ::g_world_war.curOperationCountry
  if (curOperationCountry == null)
    return getLockedCountryDataBySquad()

  return {
    availableCountries = [curOperationCountry]
    reasonText = ::loc("worldWar/cantChangeCountryInOperation")
  }
}

return getLockedCountryData
