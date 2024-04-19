from "%scripts/dagui_library.nut" import *

let { getBundleId } = require("%scripts/onlineShop/onlineBundles.nut")
let { getShopItem } = require("%scripts/onlineShop/entitlementsShopData.nut")
let { isPlatformPC } = require("%scripts/clientState/platform.nut")
let { isMarketplaceEnabled } = require("%scripts/items/itemsMarketplace.nut")
let { isUnitGift } = require("%scripts/unit/unitInfo.nut")
let { findItemById } = require("%scripts/items/itemsManager.nut")

let isEventUnit = @(unit) unit.event != null

let hasShopItem = @(unit) unit.getEntitlements().findvalue(function(id) {
  let bundleId = getBundleId(id)
  return bundleId != "" && getShopItem(bundleId) != null
}) != null

function isAvailableBuyUnitOnline(unit) {
  let canBuy = isUnitGift(unit) && !isEventUnit(unit) && unit.isVisibleInShop()
  && !::canBuyUnitOnMarketplace(unit) && !unit.isCrossPromo

  if (isPlatformPC || !canBuy)
    return canBuy

  return hasShopItem(unit)
}

function isAvailableBuyUnitOnMarketPlace(unit) {
  return unit.marketplaceItemdefId != null
    && isMarketplaceEnabled()
    && (findItemById(unit.marketplaceItemdefId)?.hasLink() ?? false)
}

return {
  isAvailableBuyUnitOnline
  isAvailableBuyUnitOnMarketPlace
}