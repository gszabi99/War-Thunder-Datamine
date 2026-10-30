from "%scripts/langUtils/language.nut" import isChineseHarmonized

let unitTypes = require("%scripts/unit/unitTypesList.nut")

function is_harmonized_unit_image_required(unit) {
  return unit.shopCountry == "country_japan" && unit.unitType == unitTypes.AIRCRAFT
    && isChineseHarmonized()
}

return freeze({is_harmonized_unit_image_required})