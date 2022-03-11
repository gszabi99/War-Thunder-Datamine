local { addListenersWithoutEnv } = require("sqStdLibs/helpers/subscriptions.nut")

local countDefaultUnitsByCountry = null

local function initCache() {
  countDefaultUnitsByCountry = {}
  foreach (u in ::all_units) {
    if (u.isVisibleInShop() && ::isUnitDefault(u))
      countDefaultUnitsByCountry[u.shopCountry] <- (countDefaultUnitsByCountry?[u.shopCountry] ?? 0) + 1
  }
}

local function invalidateCache() {
  countDefaultUnitsByCountry = null
}

local function hasDefaultUnitsInCountry(country) {
  if (countDefaultUnitsByCountry == null)
    initCache()

  return (countDefaultUnitsByCountry?[country] ?? 0) > 0
}

addListenersWithoutEnv({
  InitConfigs = @(p) invalidateCache()
})

return {
  hasDefaultUnitsInCountry
}
