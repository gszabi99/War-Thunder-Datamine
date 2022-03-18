const CHOSEN_RESEARCH_SAVE_ID = "has_chosen_research_of_squadron"

let isAllVehiclesResearched = @() u.search(::all_units,
  @(unit) unit.isSquadronVehicle() && unit.isVisibleInShop() && !::isUnitResearched(unit)
) == null

local _hasChosenResearch = null
let saveResearchChosen = function(value) {
  if (_hasChosenResearch == value)
    return

  _hasChosenResearch = value
  ::save_local_account_settings(CHOSEN_RESEARCH_SAVE_ID, _hasChosenResearch)
}

let hasChosenResearch = function() {
  if (_hasChosenResearch != null)
    return _hasChosenResearch

  _hasChosenResearch = ::load_local_account_settings(CHOSEN_RESEARCH_SAVE_ID, false)
  if (_hasChosenResearch && isAllVehiclesResearched())
    saveResearchChosen(false)

  return _hasChosenResearch
}

return {
  hasChosenResearch = hasChosenResearch
  saveResearchChosen = saveResearchChosen
  isAllVehiclesResearched = isAllVehiclesResearched
}