from "%scripts/unit/unitStatus.nut" import canBuyNotResearched, isUnitResearched
from "%scripts/user/balance.nut" import get_balance
from "%scripts/unit/unitInfo.nut" import getUnitCost
from "%scripts/unit/unitShopInfo.nut" import canBuyUnit, isUnitGift
from "%scripts/unit/availabilityBuyOnline.nut" import canBuyUnitOnline, isAvailableBuyUnitOnline
from "%scripts/unit/canBuyUnitOnMarketplace.nut" import canBuyUnitOnMarketplace, isAvailableBuyUnitOnMarketPlace
from "%scripts/unlocks/unlocksModule.nut" import isUnlockOpened
from "%scripts/discounts/discountsState.nut" import getUnitDiscount
from "%appGlobals/ranks_common_shared.nut" import isUnitSpecial
from "%scripts/dagui_library.nut" import *

function getUnitBuyTypes(unit, isFriendWishList = false) {
  let res = []
  if(unit.isSquadronVehicle())
    res.append("squadron")
  if(isUnitSpecial(unit))
    res.append("premium")
  if(isFriendWishList ? isAvailableBuyUnitOnline(unit) : canBuyUnitOnline(unit))
    res.append("shop")
  if(isFriendWishList ? isAvailableBuyUnitOnMarketPlace(unit) : canBuyUnitOnMarketplace(unit))
    res.append("marketPlace")


  if(res.len() == 0 && ((unit.reqUnlock != null && !isUnlockOpened(unit.reqUnlock)) || isUnitGift(unit)))
    return ["conditionToReceive"]

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

function getUnitAvailabilityForBuyType(unit, isFriendWishList = false) {
  let unitBuyTypes = getUnitBuyTypes(unit, isFriendWishList)
  let isShopVehicle = unitBuyTypes.contains("shop")
  let isStockVehicle = unitBuyTypes.contains("marketPlace")
  let isPremiumVehicle = unitBuyTypes.contains("premium")
  let isSquadronVehicle = unitBuyTypes.contains("squadron")
  let isResearchableVehicle = unitBuyTypes.contains("researchable")

  let res = []
  let hasDiscount = getUnitDiscount(unit) > 0
  if(((isSquadronVehicle && isUnitResearched(unit)) || !isSquadronVehicle) && hasDiscount)
    res.append("discount")

  if(isShopVehicle || isStockVehicle)
    return res.append("available")

  let { isGoldEnough } = balanceEnough(unit)
  let canBuyNotResearchedUnit = canBuyNotResearched(unit)

  if(isResearchableVehicle && (canBuyNotResearchedUnit || canBuyUnit(unit)))
    return res.append("available")

  if((isPremiumVehicle || (isSquadronVehicle && canBuyNotResearchedUnit && !isResearchableVehicle)) && isGoldEnough)
    return res.append("available")

  return res
}

return freeze({
  getUnitBuyTypes
  isIntersects
  isFullyIncluded
  getUnitAvailabilityForBuyType
})
