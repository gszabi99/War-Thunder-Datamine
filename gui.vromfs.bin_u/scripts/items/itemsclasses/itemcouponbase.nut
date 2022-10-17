from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

let ItemExternal = require("%scripts/items/itemsClasses/itemExternal.nut")

let CouponBase = class extends ItemExternal
{
  static defaultLocId = "coupon"
  static combinedNameLocId = "coupon/name"
  static descHeaderLocId = "coupon/for"

  getContentIconData   = @() { contentIcon = typeIcon }
  getCreationCaption   = @() shouldAutoConsume ? loc("unlocks/entitlement") : base.getCreationCaption()
}

return CouponBase