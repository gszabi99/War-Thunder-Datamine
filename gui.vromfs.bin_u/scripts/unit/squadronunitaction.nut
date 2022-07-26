const CHOSEN_RESEARCH_SAVE_ID = "has_chosen_research_of_squadron"

let isAllClanUnitsResearched = @() u.search(::all_units,
  @(unit) unit.isSquadronVehicle() && unit.isVisibleInShop() && !::isUnitResearched(unit)
) == null

local _hasChosenResearch = null
let function saveClanUnitResearchChosen(value) {
  if (_hasChosenResearch == value)
    return

  _hasChosenResearch = value
  ::save_local_account_settings(CHOSEN_RESEARCH_SAVE_ID, _hasChosenResearch)
}

let function hasClanUnitChosenResearch() {
  if (_hasChosenResearch != null)
    return _hasChosenResearch

  _hasChosenResearch = ::load_local_account_settings(CHOSEN_RESEARCH_SAVE_ID, false)
  if (_hasChosenResearch && isAllClanUnitsResearched())
    saveClanUnitResearchChosen(false)

  return _hasChosenResearch
}

let function isHaveNonApprovedClanUnitResearches() {
  if (!::isInMenu() || !::has_feature("ClanVehicles")
      || ::checkIsInQueue()
      || isAllClanUnitsResearched())
    return false

  let researchingUnitName = ::clan_get_researching_unit()
  if (researchingUnitName == "")
    return false

  let curSquadronExp = ::clan_get_exp()
  let hasChosenResearchOfSquadron = hasClanUnitChosenResearch()
  if (hasChosenResearchOfSquadron && curSquadronExp <=0)
    return false

  let unit = ::getAircraftByName(researchingUnitName)
  if (!unit || !unit.isVisibleInShop())
    return false

  if ((hasChosenResearchOfSquadron || !::is_in_clan())
      && (curSquadronExp <= 0 || curSquadronExp < unit.reqExp - ::getUnitExp(unit)))
    return false

  return true
}

return {
  hasClanUnitChosenResearch
  saveClanUnitResearchChosen
  isAllClanUnitsResearched
  isHaveNonApprovedClanUnitResearches
}