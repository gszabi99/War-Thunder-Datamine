let unitTypes = require("%scripts/unit/unitTypesList.nut")
let {isChineseHarmonized} = require("%scripts/langUtils/language.nut")

function is_harmonized_unit_image_required(unit) {
  return unit.shopCountry == "country_japan" && unit.unitType == unitTypes.AIRCRAFT
    && isChineseHarmonized()
}

return {is_harmonized_unit_image_required}