local ItemCouponBase = require("scripts/items/itemsClasses/itemCouponBase.nut")

class ::items_classes.RentedUnit extends ItemCouponBase {
  static iType = itemType.RENTED_UNIT
  static typeIcon = "#ui/gameuiskin#item_type_rent"

  getRentedUnitId      = @() metaBlk?.rentedUnit
  function canConsume() {
    local unitId = getRentedUnitId()
    return unitId != null
      && (::getAircraftByName(unitId)?.isVisibleInShop() ?? false)
  }
}