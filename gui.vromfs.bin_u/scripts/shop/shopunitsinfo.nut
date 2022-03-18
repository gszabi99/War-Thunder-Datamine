let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")

local countDefaultUnitsByCountry = null

let function initCache() {
  countDefaultUnitsByCountry = {}
  foreach (u in ::all_units) {
    if (u.isVisibleInShop() && ::isUnitDefault(u))
      countDefaultUnitsByCountry[u.shopCountry] <- (countDefaultUnitsByCountry?[u.shopCountry] ?? 0) + 1
  }
}

let function invalidateCache() {
  countDefaultUnitsByCountry = null
}

let function hasDefaultUnitsInCountry(country) {
  if (countDefaultUnitsByCountry == null)
    initCache()

  return (countDefaultUnitsByCountry?[country] ?? 0) > 0
}

let function isCountryHaveUnitType(country, unitType) {
  foreach(unit in ::all_units)
    if (unit.shopCountry == country && unit.esUnitType == unitType && unit.isVisibleInShop())
      return true
  return false
}

addListenersWithoutEnv({
  InitConfigs = @(p) invalidateCache()
})

return {
  hasDefaultUnitsInCountry
  isCountryHaveUnitType
}
