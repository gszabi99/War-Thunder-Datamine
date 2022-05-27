let ItemCouponBase = require("%scripts/items/itemsClasses/itemCouponBase.nut")

::items_classes.RentedUnit <- class extends ItemCouponBase {
  static iType = itemType.RENTED_UNIT
  static typeIcon = "#ui/gameuiskin#item_type_rent"

  getRentedUnitId      = @() metaBlk?.rentedUnit
  function canConsume() {
    if (!isInventoryItem)
      return false

    let unitId = getRentedUnitId()
    let unit = ::getAircraftByName(unitId)
    return unit != null && !unit.isBought()
      && (unit.isVisibleInShop() || unit.showOnlyWhenBought)
  }
}