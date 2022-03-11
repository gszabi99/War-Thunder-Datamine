local ItemCouponBase = require("scripts/items/itemsClasses/itemCouponBase.nut")

class ::items_classes.Warpoints extends ItemCouponBase {
  static iType = itemType.WARPOINTS
  static typeIcon = "#ui/gameuiskin#item_type_warpoints"

  getWarpoints         = @() metaBlk?.warpoints ?? 0
  canConsume           = @() isInventoryItem && getWarpoints() > 0

  function getPrizeDescription(count)
  {
    if (!shouldAutoConsume)
      return null
    local wp = getWarpoints()
    if (wp == 0)
      return null
    return count * wp //prize already has type icon, so we no need 2 warpoints icons near amount number
  }
}