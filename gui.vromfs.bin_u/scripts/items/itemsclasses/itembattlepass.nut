//checked for plus_string
from "%scripts/dagui_library.nut" import *

let ItemCouponBase = require("%scripts/items/itemsClasses/itemCouponBase.nut")

::items_classes.BattlePass <- class extends ItemCouponBase {
  static iType = itemType.BATTLE_PASS
  static typeIcon = "#ui/gameuiskin#item_type_bp.svg"

  canConsume           = @() false
}
