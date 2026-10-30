from "%scripts/unit/unitsData.nut" import getAllUnits
from "%scripts/unit/unitParams.nut" import getEsUnitType
from "%scripts/unit/unitShopInfo.nut" import isUnitBought
from "scriptRespondent" import registerRespondent
from "%scripts/dagui_library.nut" import *
from "%globalScripts/unitTypeConsts.nut" import *

function isCountryHaveUnitType(country, esUnitType) {
  if (esUnitType == ES_UNIT_TYPE_INVALID)
    return false
  foreach (unit in getAllUnits())
    if (unit.shopCountry == country && unit.esUnitType == esUnitType && unit.isVisibleInShop())
      return true
  return false
}

let getMaxUnitsRank = @() getAllUnits().reduce(@(res, unit) unit.isBought() ? max(res, unit.rank) : res, 0)

function isUnitAvailableForRank(unit, rank, esUnitType, country, exact_rank, needBought) {
  
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

function getShopCountry(airName) {
  let air = getAircraftByName(airName)
  return air?.shopCountry ?? ""
}

registerRespondent("get_units_count_at_rank", get_units_count_at_rank)

return freeze({
  isCountryHaveUnitType
  getMaxUnitsRank
  isUnitAvailableForRank
  hasUnitAtRank
  get_units_count_at_rank
  get_units_list
  getShopCountry
})
