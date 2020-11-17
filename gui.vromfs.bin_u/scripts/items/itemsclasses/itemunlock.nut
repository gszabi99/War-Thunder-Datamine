local ItemCouponBase = require("scripts/items/itemsClasses/itemCouponBase.nut")

class ::items_classes.Unlock extends ItemCouponBase {
  static iType = itemType.UNLOCK
  static typeIcon = "#ui/gameuiskin#item_type_unlock"

  getUnlock            = @() metaBlk?.unlock
  canConsume           = @() isInventoryItem && getUnlock() != null
}