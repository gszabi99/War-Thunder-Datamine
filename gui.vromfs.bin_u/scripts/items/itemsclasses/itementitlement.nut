from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let ItemCouponBase = require("%scripts/items/itemsClasses/itemCouponBase.nut")

::items_classes.Entitlement <- class extends ItemCouponBase {
  static iType = itemType.ENTITLEMENT
  static typeIcon = "#ui/gameuiskin#item_type_premium.svg"

  getEntitlement       = @() this.metaBlk?.entitlement
  canConsume           = @() this.isInventoryItem && this.getEntitlement() != null
}