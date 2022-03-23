let ItemCouponBase = require("%scripts/items/itemsClasses/itemCouponBase.nut")

::items_classes.ItemVehicle <- class extends ItemCouponBase {
  static iType = itemType.VEHICLE
  static typeIcon = "#ui/gameuiskin#item_type_blueprints"
  static descHeaderLocId = "coupon/for/vehicle"

  unit = null

  function addResources() {
    base.addResources()
    unit = ::getAircraftByName(metaBlk?.unit)
  }

  getContentIconData = @() { contentIcon = ::image_for_air(unit?.name ?? ""), contentType = "unit" }
  canConsume = @() isInventoryItem && !(unit?.isBought() ?? true)
  canPreview = @() unit ? unit.canPreview() : false
  doPreview  = @() unit && unit.doPreview()
}