local ItemCouponBase = require("scripts/items/itemsClasses/itemCouponBase.nut")

class ::items_classes.RentedUnit extends ItemCouponBase {
  static iType = itemType.RENTED_UNIT
  static typeIcon = "#ui/gameuiskin#item_type_rent"

  getRentedUnitId      = @() metaBlk?.rentedUnit
  function canConsume() {
    if (!isInventoryItem)
      return false

    local unitId = getRentedUnitId()
    local unit = ::getAircraftByName(unitId)
    return unit != null && !unit.isBought()
      && (unit.isVisibleInShop() || unit.showOnlyWhenBought)
  }
}