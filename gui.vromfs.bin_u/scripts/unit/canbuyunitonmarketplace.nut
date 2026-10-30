from "%scripts/items/itemsMarketplaceStatus.nut" import isMarketplaceEnabled
from "%scripts/items/itemsManagerModule.nut" import findItemById
from "%scripts/dagui_library.nut" import *

function isAvailableBuyUnitOnMarketPlace(unit) {
  return unit.marketplaceItemdefId != null
    && isMarketplaceEnabled()
    && (findItemById(unit.marketplaceItemdefId)?.hasLink() ?? false)
}
function canBuyUnitOnMarketplace(unit) {
  if (!unit)
    return false
  if (unit.isBought())
    return false
  return isAvailableBuyUnitOnMarketPlace(unit)
}

return freeze({
  isAvailableBuyUnitOnMarketPlace
  canBuyUnitOnMarketplace
})