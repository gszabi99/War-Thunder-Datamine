from "%scripts/dagui_library.nut" import *
let { getEsUnitType } = require("%scripts/unit/unitParams.nut")
let { isUnitBought } = require("%scripts/unit/unitShopInfo.nut")

let getAllUnits = require("%scripts/unit/allUnits.nut")

function isCountryHaveUnitType(country, unitType) {
  foreach (unit in getAllUnits())
    if (unit.shopCountry == country && unit.esUnitType == unitType && unit.isVisibleInShop())
      return true
  return false
}

let getMaxUnitsRank = @() getAllUnits().reduce(@(res, unit) unit.isBought() ? max(res, unit.rank) : res, 0)

function isUnitAvailableForRank(unit, rank, esUnitType, country, exact_rank, needBought) {
  // Keep this in sync with getUnitsCountAtRank() in chard
  return (esUnitType == getEsUnitType(unit) || esUnitType == ES_UNIT_TYPE_TOTAL)
    && (country == unit.shopCountry || country == "")
    && (unit.rank == rank || (!exact_rank && unit.rank > rank))
    && ((!needBought || isUnitBought(unit)) && unit.isVisibleInShop())
}

function hasUnitAtRank(rank, esUnitType, country, exact_rank, needBought = true) {
  foreach (unit in getAllUnits())
    if (isUnitAvailableForRank(unit, rank, esUnitType, country, exact_rank, needBought))
      return true
  return false
}

function get_units_count_at_rank(rank, esUnitType, country, exact_rank, needBought = true) {
  local count = 0
  foreach (unit in getAllUnits())
    if (isUnitAvailableForRank(unit, rank, esUnitType, country, exact_rank, needBought))
      count++
  return count
}

function get_units_list(filterFunc) {
  let res = []
  foreach (unit in getAllUnits())
    if (filterFunc(unit))
      res.append(unit)
  return res
}

return {
  isCountryHaveUnitType
  getMaxUnitsRank
  isUnitAvailableForRank
  hasUnitAtRank
  get_units_count_at_rank
  get_units_list
}
