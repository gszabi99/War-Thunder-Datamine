from "%scripts/dagui_library.nut" import *
let { appendOnce } = require("%sqStdLibs/helpers/u.nut")
let { getShopVisibleCountries } = require("%scripts/shop/shopCountriesList.nut")

let maxTooltipUnitsCount = 20

function getSortedUnits(rawData) {
  let res = []
  let countries = getShopVisibleCountries()
  foreach (unitData in rawData) {
    if (unitData.unit == null)
      continue
    let { unitType, shopCountry } = unitData.unit
    res.append(unitData.__merge(
      {
        countryIndex = countries.indexof(shopCountry)
        visualSortOrder = unitType.visualSortOrder
      }
    ))
  }
  return res.sort(@(v1, v2) v1.countryIndex <=> v2.countryIndex || v1.visualSortOrder <=> v2.visualSortOrder)
}

function getSortedDiscountUnits(rawData) {
  let res = []
  let countries = getShopVisibleCountries()
  foreach (unitData in rawData) {
    let { unitType, shopCountry } = unitData.unit
    res.append(unitData.__merge(
      {
        countryIndex = countries.indexof(shopCountry)
        visualSortOrder = unitType.visualSortOrder
      }
    ))
  }
  return res.sort(@(v1, v2) v1.countryIndex <=> v2.countryIndex || v1.visualSortOrder <=> v2.visualSortOrder ||
    v2.unit.rank <=> v1.unit.rank || v2.discount <=> v1.discount)
}

function prepareForTooltip(data) {
  local showedUnitsLeft = maxTooltipUnitsCount
  let shuffledUnits = {}
  local shuffledUnitsCount = 0
  let result = []
  for (local i = 0; i < data.len(); i++) {
    let unit = data[i].unit
    let country = unit.shopCountry
    let armyId = unit.unitType.armyId

    if(!(country in shuffledUnits))
      shuffledUnits[country] <- {}
    if(!(armyId in shuffledUnits[country]))
      shuffledUnits[country][armyId] <- [data[i]]
    else
      shuffledUnits[country][armyId].append(data[i])
    shuffledUnitsCount++

    if(result.len() < maxTooltipUnitsCount)
      appendOnce({ country, armyId, units = [], more = 0 }, result, false,
        @(v1, v2) v1.country == v2.country && v1.armyId == v2.armyId)
  }

  while (showedUnitsLeft > 0 && shuffledUnitsCount > 0) {
    for (local i = 0; i < result.len(); i++) {
      let { country, armyId, units } = result[i]
      let unitsData = shuffledUnits[country][armyId]
      if(unitsData.len() == 0)
        continue
      let unitData = unitsData.remove(0)
      shuffledUnitsCount--
      units.append(unitData)
      result[i].more = unitsData.len()
      showedUnitsLeft--
      if(showedUnitsLeft == 0)
        break
    }
  }

  return {
    tooltipUnits = result
    tooltipUnitsCount = result.reduce(function(res, val) { return res + val.units.len() + val.more }, 0)
  }
}

function createMoreText(count) {
  return loc("shop/moreVehicles", { num = count })
}

return {
  getSortedUnits
  getSortedDiscountUnits
  prepareForTooltip
  createMoreText
  maxElementsInSimpleTooltip = 25
  maxTooltipUnitsCount
}