from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv, CONFIG_VALIDATION
from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import itemType

let { INVENTORY_UPDATE } = require("%scripts/crossModuleEvents.nut")
let { getInventoryListByShopMask } = require("%scripts/items/itemsManagerModule.nut")

let unitCoupons = persist("unitCoupons", @() { valid = false })

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

return {
  getUnitCoupon
  hasUnitCoupon
}