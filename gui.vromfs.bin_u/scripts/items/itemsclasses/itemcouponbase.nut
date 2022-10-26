from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let ItemExternal = require("%scripts/items/itemsClasses/itemExternal.nut")

let CouponBase = class extends ItemExternal {
  static defaultLocId = "coupon"
  static combinedNameLocId = "coupon/name"
  static descHeaderLocId = "coupon/for"

  getContentIconData   = @() { contentIcon = this.typeIcon }
  getCreationCaption   = @() this.shouldAutoConsume ? loc("unlocks/entitlement") : base.getCreationCaption()
}

return CouponBase