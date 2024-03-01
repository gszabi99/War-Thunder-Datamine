from "%scripts/dagui_library.nut" import *
let countrySymbols = require("%globalScripts/countrySymbols.nut")
let { getUnitName, getUnitCountry } = require("%scripts/unit/unitInfo.nut")

function getUnitCountryByName(unitName) {
  let country = loc(getUnitCountry(getAircraftByName(unitName)))
  return $"({country})"
}

function getClearUnitName(unitName, isLockId = false) {
  local name = isLockId ? loc(unitName) : getUnitName(unitName)
  name = utf8(name.replace(" ", " "))
  if(countrySymbols.indexof(name.slice(0, 1)) == null)
    return "".concat(name)

  return "".concat(name.slice(1), getUnitCountryByName(unitName))
}

return {
  getClearUnitName
}