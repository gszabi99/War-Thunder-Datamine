from "%scripts/dagui_library.nut" import *

let { isUnitSpecial } = require("%appGlobals/ranks_common_shared.nut")
let { canBuyNotResearched } = require("%scripts/unit/unitStatus.nut")
let { get_balance } = require("%scripts/user/balance.nut")
let { getUnitCost } = require("%scripts/unit/unitInfo.nut")
let { canBuyUnit } = require("%scripts/unit/unitShopInfo.nut")
let { canBuyUnitOnline } = require("%scripts/unit/availabilityBuyOnline.nut")

function getUnitBuyTypes(unit) {
  let res = []

  if(isUnitSpecial(unit))
    res.append("premium")
  if(canBuyUnitOnline(unit))
    res.append("shop")

  if(res.len() == 0)
    return ["researchable"]

  return res
}

function isIntersects(arr1, arr2) {
  return arr1.filter(@(v) arr2.contains(v)).len() > 0
}

function isFullyIncluded(refArr, testArr) {
  return refArr.filter(@(v) testArr.contains(v)).len() == testArr.len()
}

function balanceEnough(unit) {
  let canBuyNotResearchedUnit = canBuyNotResearched(unit)
  let unitCost = canBuyNotResearchedUnit ? unit.getOpenCost() : getUnitCost(unit)
  let { wp, gold } = get_balance()

  return {
    isGoldEnough = gold >= unitCost.gold
    isWpEnough = wp >= unitCost.wp
  }
}

function getUnitAvailabilityForBuyType(unit) {
  let unitBuyTypes = getUnitBuyTypes(unit)
  let isShopVehicle = unitBuyTypes.contains("shop")
  let isPremiumVehicle = unitBuyTypes.contains("premium")
  let isResearchableVehicle = unitBuyTypes.contains("researchable")

  let res = []

  if(isShopVehicle)
    return res.append("available")

  let { isGoldEnough } = balanceEnough(unit)
  let canBuyNotResearchedUnit = canBuyNotResearched(unit)

  if(isResearchableVehicle && (canBuyNotResearchedUnit || canBuyUnit(unit)))
    return res.append("available")

  if(isPremiumVehicle && isGoldEnough)
    return res.append("available")

  return res
}

return {
  getUnitBuyTypes
  isIntersects
  isFullyIncluded
  getUnitAvailabilityForBuyType
}
