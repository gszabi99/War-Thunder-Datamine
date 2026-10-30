from "%scripts/crossModuleEvents.nut" import INVENTORY_UPDATE
from "%scripts/items/itemsManagerModule.nut" import getInventoryListByShopMask
from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv, CONFIG_VALIDATION
from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import itemType

let unitCoupons = { valid = false }

function updateUnitCoupons() {
  unitCoupons.__update(getInventoryListByShopMask(itemType.VEHICLE)
    .filter(@(it) it.metaBlk?.unit != null && it.canConsume())
    .reduce(function(res, it) {
      res[it.metaBlk.unit] <- it
      return res
    }, {}))
  unitCoupons.valid <- true
}

function getUnitCoupon(unitName) {
  if(!unitCoupons.valid)
    updateUnitCoupons()
  return unitCoupons?[unitName]
}

function hasUnitCoupon(unitName) {
  if(!unitCoupons.valid)
    updateUnitCoupons()
  return unitCoupons?[unitName] != null
}

addListenersWithoutEnv({
  [INVENTORY_UPDATE] = function(_) {
    unitCoupons.clear()
    unitCoupons.valid <- false
  }
  ProfileUpdated = function(_) {
    unitCoupons.clear()
    unitCoupons.valid <- false
  }
}, CONFIG_VALIDATION)

return freeze({
  getUnitCoupon
  hasUnitCoupon
})