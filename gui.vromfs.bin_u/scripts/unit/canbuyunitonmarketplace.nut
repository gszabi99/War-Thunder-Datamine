from "%scripts/dagui_library.nut" import *
let { isMarketplaceEnabled } = require("%scripts/items/itemsMarketplaceStatus.nut")
let { findItemById } = require("%scripts/items/itemsManager.nut")

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

return {
  isAvailableBuyUnitOnMarketPlace
  canBuyUnitOnMarketplace
}