//checked for plus_string
from "%scripts/dagui_library.nut" import *

let ItemExternal = require("%scripts/items/itemsClasses/itemExternal.nut")

let CouponBase = class (ItemExternal) {
  static defaultLocId = "coupon"
  static combinedNameLocId = "coupon/name"
  static descHeaderLocId = "coupon/for"

  getContentIconData   = @() { contentIcon = this.typeIcon }
  getCreationCaption   = @() this.shouldAutoConsume ? loc("unlocks/entitlement") : base.getCreationCaption()
}

return CouponBase