from "%scripts/dagui_library.nut" import *

let { setTimeout, clearTimer } = require("dagor.workcycle")
let { calcPercent } = require("%sqstd/math.nut")
let { bundlesShopInfo } = require("%scripts/onlineShop/entitlementsInfo.nut")
let { getEntitlementConfig } = require("%scripts/onlineShop/entitlements.nut")
let { get_charserver_time_sec } = require("chard")
let { isAvailableBuyUnitOnline } = require("%scripts/unit/availabilityBuyOnline.nut")

const DISCOUNT_BUNDLES_TIMER_ID = "timer_discount_bundles_update"

let discountUnitsBundles = Watched({})

function updateDiscountUnitsBundles(bundlesShopInfoV) {
  clearTimer(DISCOUNT_BUNDLES_TIMER_ID)
  if (bundlesShopInfoV == null) {
    discountUnitsBundles.set({})
    return
  }

  let curTime = get_charserver_time_sec()
  let res = {}
  local minTimeLeft = null
  foreach (entId, bundle in bundlesShopInfoV) {
    let { discount_mul = 1.0, discount_till = 0 } = bundle
    if (discount_mul == 1.0)
      continue

    let entConfig = getEntitlementConfig(entId)
    let unitsList = entConfig?.aircraftGift ?? []
    if (unitsList.len() == 0)
      continue

    let discountTillInt = type(discount_till) == "integer" ? discount_till : 0  
    let timeLeft = discountTillInt - curTime
    if (timeLeft <= 0)
      continue

    minTimeLeft = min(minTimeLeft ?? timeLeft, timeLeft)
    foreach (unitName in unitsList) {
      let unit = getAircraftByName(unitName)
      if (unit == null || !isAvailableBuyUnitOnline(unit) || !unit.isVisibleInShop() || unit.isBought())
        continue
      res[unitName] <- calcPercent(1 - discount_mul)
    }
  }
  if (minTimeLeft != null) {
    let self = callee()
    setTimeout(minTimeLeft, @() self(bundlesShopInfo.get()), DISCOUNT_BUNDLES_TIMER_ID)
  }
  discountUnitsBundles.set(res)
}

bundlesShopInfo.subscribe(updateDiscountUnitsBundles)

return {
  discountUnitsBundles
}