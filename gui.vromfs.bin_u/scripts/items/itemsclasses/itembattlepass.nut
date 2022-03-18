let ItemCouponBase = require("scripts/items/itemsClasses/itemCouponBase.nut")

::items_classes.BattlePass <- class extends ItemCouponBase {
  static iType = itemType.BATTLE_PASS
  static typeIcon = "#ui/gameuiskin#item_type_bp.svg"

  canConsume           = @() false
}
