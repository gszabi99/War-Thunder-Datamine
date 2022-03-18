let ItemExternal = require("scripts/items/itemsClasses/itemExternal.nut")

let CouponBase = class extends ItemExternal
{
  static defaultLocId = "coupon"
  static combinedNameLocId = "coupon/name"
  static descHeaderLocId = "coupon/for"

  getContentIconData   = @() { contentIcon = typeIcon }
  getCreationCaption   = @() shouldAutoConsume ? ::loc("unlocks/entitlement") : base.getCreationCaption()
}

return CouponBase