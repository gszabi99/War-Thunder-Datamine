from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

let ItemCouponBase = require("%scripts/items/itemsClasses/itemCouponBase.nut")

::items_classes.Entitlement <- class extends ItemCouponBase {
  static iType = itemType.ENTITLEMENT
  static typeIcon = "#ui/gameuiskin#item_type_premium.svg"

  getEntitlement       = @() metaBlk?.entitlement
  canConsume           = @() isInventoryItem && getEntitlement() != null
}