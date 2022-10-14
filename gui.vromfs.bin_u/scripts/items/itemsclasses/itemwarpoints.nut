from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

let ItemCouponBase = require("%scripts/items/itemsClasses/itemCouponBase.nut")

::items_classes.Warpoints <- class extends ItemCouponBase {
  static iType = itemType.WARPOINTS
  static typeIcon = "#ui/gameuiskin#item_type_warpoints.svg"

  getWarpoints         = @() metaBlk?.warpoints ?? 0
  canConsume           = @() isInventoryItem && getWarpoints() > 0

  function getPrizeDescription(count, colored = true)
  {
    if (!shouldAutoConsume)
      return null
    let wp = getWarpoints()
    if (wp == 0)
      return null
    return count * wp //prize already has type icon, so we no need 2 warpoints icons near amount number
  }
}