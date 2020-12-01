local ItemCouponBase = require("scripts/items/itemsClasses/itemCouponBase.nut")

class ::items_classes.BattlePass extends ItemCouponBase {
  static iType = itemType.BATTLE_PASS
  static typeIcon = "#ui/gameuiskin#item_type_bp.svg"

  canConsume           = @() false
}
