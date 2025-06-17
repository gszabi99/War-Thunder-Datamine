from "%scripts/dagui_library.nut" import *

let { getBundleId } = require("%scripts/onlineShop/onlineBundles.nut")
let { getShopItem } = require("%scripts/onlineShop/entitlementsShopData.nut")
let { isPlatformPC } = require("%scripts/clientState/platform.nut")
let { canBuyUnitOnMarketplace } = require("%scripts/unit/canBuyUnitOnMarketplace.nut")

let isEventUnit = @(unit) unit.event != null

let hasShopItem = @(unit) unit.getEntitlements().findvalue(function(id) {
  let bundleId = getBundleId(id)
  return bundleId != "" && getShopItem(bundleId) != null
}) != null

function isAvailableBuyUnitOnline(unit) {
  let canBuy = (unit.gift != null) && !isEventUnit(unit) && unit.isVisibleInShop()
  && !canBuyUnitOnMarketplace(unit) && !unit.isCrossPromo

  if (isPlatformPC || !canBuy)
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
::canBuyUnitOnline <- canBuyUnitOnline

return {
  isAvailableBuyUnitOnline
  canBuyUnitOnline
}