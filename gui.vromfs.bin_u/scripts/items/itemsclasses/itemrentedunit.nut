//checked for plus_string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let ItemCouponBase = require("%scripts/items/itemsClasses/itemCouponBase.nut")

::items_classes.RentedUnit <- class extends ItemCouponBase {
  static iType = itemType.RENTED_UNIT
  static typeIcon = "#ui/gameuiskin#item_type_rent.svg"

  getRentedUnitId      = @() this.metaBlk?.rentedUnit
  function canConsume() {
    if (!this.isInventoryItem)
      return false

    let unitId = this.getRentedUnitId()
    let unit = ::getAircraftByName(unitId)
    return unit != null && !unit.isBought()
      && (unit.isVisibleInShop() || unit.showOnlyWhenBought)
  }
}