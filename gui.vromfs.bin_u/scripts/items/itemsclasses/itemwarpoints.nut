//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let ItemCouponBase = require("%scripts/items/itemsClasses/itemCouponBase.nut")

::items_classes.Warpoints <- class extends ItemCouponBase {
  static iType = itemType.WARPOINTS
  static typeIcon = "#ui/gameuiskin#item_type_warpoints.svg"

  getWarpoints         = @() this.metaBlk?.warpoints ?? 0
  canConsume           = @() this.isInventoryItem && this.getWarpoints() > 0

  function getPrizeDescription(count, _colored = true) {
    if (!this.shouldAutoConsume)
      return null
    let wp = this.getWarpoints()
    if (wp == 0)
      return null
    return count * wp //prize already has type icon, so we no need 2 warpoints icons near amount number
  }
}