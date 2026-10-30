from "%scripts/onlineShop/onlineBundles.nut" import getBundleId
from "%scripts/onlineShop/entitlementsShopData.nut" import getShopItem
from "%sqstd/platform.nut" import isPC
from "%scripts/unit/canBuyUnitOnMarketplace.nut" import canBuyUnitOnMarketplace
from "%scripts/dagui_library.nut" import *

let isEventUnit = @(unit) unit.event != null

let hasShopItem = @(unit) unit.getEntitlements().findvalue(function(id) {
  let bundleId = getBundleId(id)
  return bundleId != "" && getShopItem(bundleId) != null
}) != null

function isAvailableBuyUnitOnline(unit) {
  let canBuy = (unit.gift != null) && !isEventUnit(unit) && unit.isVisibleInShop()
  && !canBuyUnitOnMarketplace(unit) && !unit.isCrossPromo

  if (isPC || !canBuy)
    return canBuy

  return hasShopItem(unit)
}

function canBuyUnitOnline(unit) {
  if (!unit)
    return false
  if (unit.isBought())
    return false
  return isAvailableBuyUnitOnline(unit)
}

return freeze({
  isAvailableBuyUnitOnline
  canBuyUnitOnline
})