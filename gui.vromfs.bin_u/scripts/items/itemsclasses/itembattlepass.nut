from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import itemType

let ItemCouponBase = require("%scripts/items/itemsClasses/itemCouponBase.nut")

let BattlePass = class (ItemCouponBase) {
  static name = "BattlePass"
  static iType = itemType.BATTLE_PASS
  static typeIcon = "#ui/gameuiskin#item_type_bp.svg"

  canConsume           = @() false
}

return { BattlePass }