from "%scripts/dagui_library.nut" import *

let getAllUnits = require("%scripts/unit/allUnits.nut")

let discountsList = persist("discountsList", @() {})
let consoleEntitlementUnits = {} 

function getDiscount(id, defVal = false) {
  return discountsList?[id] ?? defVal
}

function getEntitlementDiscount(id) {
  return discountsList.entitlements?[id] ?? 0
}

function getEntitlementUnitDiscount(unitName) {
  return discountsList.entitlementUnits?[unitName] ?? 0
}

function getUnitDiscountByName(unitName) {
  return discountsList.airList?[unitName] ?? 0
}

function haveAnyUnitDiscount() {
  return discountsList.entitlementUnits.len() > 0 || discountsList.airList.len() > 0
}

let canBeVisibleDiscountOnUnit = @(unit) unit && unit.isVisibleInShop() && !unit.isBought()


function getUnitDiscount(unit) {
  if (!canBeVisibleDiscountOnUnit(unit))
    return 0
  return max(getUnitDiscountByName(unit.name),
    getEntitlementUnitDiscount(unit.name))
}

function getGroupDiscount(list) {
  local res = 0
  foreach (unit in list)
    res = max(res, getUnitDiscount(unit))
  return res
}

function getUnitsDiscounts(countryId = "", armyId = "") {
  if (!haveAnyUnitDiscount())
    return []

  let newDiscountsList = []
  foreach (unit in getAllUnits())
    if ((countryId == "" || unit.shopCountry == countryId) && (armyId == "" || unit.unitType.armyId == armyId)) {
      let discount = getUnitDiscount(unit)
      if (discount > 0)
        newDiscountsList.append({ unit, discount })
    }

  return newDiscountsList
}

return {
  discountsList
  consoleEntitlementUnits
  getDiscount
  getEntitlementDiscount
  getEntitlementUnitDiscount
  getUnitDiscountByName
  haveAnyUnitDiscount
  canBeVisibleDiscountOnUnit
  getUnitDiscount
  getGroupDiscount
  getUnitsDiscounts
}

