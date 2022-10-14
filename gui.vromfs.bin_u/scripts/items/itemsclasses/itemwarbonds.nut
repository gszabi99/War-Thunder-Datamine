from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

let ItemCouponBase = require("%scripts/items/itemsClasses/itemCouponBase.nut")

::items_classes.Warbonds <- class extends ItemCouponBase {
  static iType = itemType.WARBONDS
  static typeIcon = "#ui/gameuiskin#item_type_warbonds.svg"

  getWarbond           = @() ::g_warbonds.findWarbond(metaBlk?.warbonds)
  getWarbondsAmount    = @() metaBlk?.count || 0
  canConsume           = @() isInventoryItem && getWarbond() != null && getWarbondsAmount() > 0

  function getPrizeDescription(count, colored = true)
  {
    if (!shouldAutoConsume)
      return null
    let wb = getWarbond()
    return wb && (count * getWarbondsAmount())  //prize already has type icon, so we no need 2 warbond icons near amount number
  }
}