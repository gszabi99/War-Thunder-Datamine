local ItemCouponBase = require("scripts/items/itemsClasses/itemCouponBase.nut")

class ::items_classes.Entitlement extends ItemCouponBase {
  static iType = itemType.ENTITLEMENT
  static typeIcon = "#ui/gameuiskin#item_type_premium"

  getEntitlement       = @() metaBlk?.entitlement
  canConsume           = @() isInventoryItem && getEntitlement() != null
}