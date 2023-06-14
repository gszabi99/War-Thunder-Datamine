//checked for plus_string
from "%scripts/dagui_library.nut" import *


let ItemExternal = require("%scripts/items/itemsClasses/itemExternal.nut")
let { utf8ToLower } = require("%sqstd/string.nut")

::items_classes.ItemUnitCouponMod <- class extends ItemExternal {
  static iType = itemType.UNIT_COUPON_MOD
  static defaultLocId = "coupon_modify"

  getSmallIconName = @() $"#ui/gameuiskin#item_type_coupon_mod_{this.rarity.colorValue}.svg"

  getContentIconData = function() {
    let unitName = this.itemDef?.tags.unit
    if (unitName)
      return { contentIcon = ::image_for_air(unitName), contentType = "unit" }

    return { contentIcon = this.getSmallIconName() }
  }

  getTypeNameForMarketableDesc = @() utf8ToLower(loc("item"))
}