from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")

function getEsUnitType(unit) {
  return unit?.esUnitType ?? ES_UNIT_TYPE_INVALID
}

function getUnitTypeTextByUnit(unit) {
  return ::getUnitTypeText(getEsUnitType(unit))
}

function isUnitsEraUnlocked(unit) {
  return ::is_era_available(::getUnitCountry(unit), unit?.rank ?? -1, getEsUnitType(unit))
}

function getUnitName(unit, shopName = true) {
  let unitId = u.isUnit(unit) ? unit.name
    : u.isString(unit) ? unit
    : ""
  let localized = loc(unitId + (shopName ? "_shop" : "_0"), unitId)
  return shopName ? ::stringReplace(localized, " ", ::nbsp) : localized
}

return {
  getEsUnitType, getUnitTypeTextByUnit, isUnitsEraUnlocked, getUnitName
}