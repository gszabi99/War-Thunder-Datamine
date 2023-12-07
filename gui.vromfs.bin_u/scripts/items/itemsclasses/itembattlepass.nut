from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import itemType

let ItemCouponBase = require("%scripts/items/itemsClasses/itemCouponBase.nut")

::items_classes.BattlePass <- class (ItemCouponBase) {
  static iType = itemType.BATTLE_PASS
  static typeIcon = "#ui/gameuiskin#item_type_bp.svg"

  canConsume           = @() false
}
