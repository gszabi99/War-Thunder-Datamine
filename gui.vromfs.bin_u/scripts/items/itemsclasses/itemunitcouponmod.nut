from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

let ItemExternal = require("%scripts/items/itemsClasses/itemExternal.nut")

::items_classes.ItemUnitCouponMod <- class extends ItemExternal {
  static iType = itemType.UNIT_COUPON_MOD
  static defaultLocId = "coupon_modify"

  getSmallIconName = @() $"#ui/gameuiskin#item_type_coupon_mod_{rarity.colorValue}.svg"

  getContentIconData = function() {
    let unitName = itemDef?.tags.unit
    if (unitName)
      return { contentIcon = ::image_for_air(unitName), contentType = "unit" }

    return { contentIcon = getSmallIconName() }
  }

  getTypeNameForMarketableDesc = @() ::g_string.utf8ToLower(loc("item"))
}