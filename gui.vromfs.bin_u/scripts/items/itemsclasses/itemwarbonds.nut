local ItemCouponBase = require("scripts/items/itemsClasses/itemCouponBase.nut")

class ::items_classes.Warbonds extends ItemCouponBase {
  static iType = itemType.WARBONDS
  static typeIcon = "#ui/gameuiskin#item_type_warbonds"

  getWarbond           = @() ::g_warbonds.findWarbond(metaBlk?.warbonds)
  getWarbondsAmount    = @() metaBlk?.count || 0
  canConsume           = @() isInventoryItem && getWarbond() != null && getWarbondsAmount() > 0

  function getPrizeDescription(count)
  {
    if (!shouldAutoConsume)
      return null
    local wb = getWarbond()
    return wb && (count * getWarbondsAmount())  //prize already has type icon, so we no need 2 warbond icons near amount number
  }
}