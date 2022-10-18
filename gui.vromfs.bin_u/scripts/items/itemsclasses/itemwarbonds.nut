from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let ItemCouponBase = require("%scripts/items/itemsClasses/itemCouponBase.nut")

::items_classes.Warbonds <- class extends ItemCouponBase {
  static iType = itemType.WARBONDS
  static typeIcon = "#ui/gameuiskin#item_type_warbonds.svg"

  getWarbond           = @() ::g_warbonds.findWarbond(this.metaBlk?.warbonds)
  getWarbondsAmount    = @() this.metaBlk?.count || 0
  canConsume           = @() this.isInventoryItem && getWarbond() != null && getWarbondsAmount() > 0

  function getPrizeDescription(count, _colored = true)
  {
    if (!this.shouldAutoConsume)
      return null
    let wb = getWarbond()
    return wb && (count * getWarbondsAmount())  //prize already has type icon, so we no need 2 warbond icons near amount number
  }
}