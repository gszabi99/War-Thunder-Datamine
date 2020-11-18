local ItemCouponBase = require("scripts/items/itemsClasses/itemCouponBase.nut")

class ::items_classes.ItemVehicle extends ItemCouponBase {
  static iType = itemType.VEHICLE
  static typeIcon = "#ui/gameuiskin#item_type_blueprints"
  static descHeaderLocId = "coupon/for/vehicle"

  unit = null

  function addResources() {
    base.addResources()
    unit = ::getAircraftByName(metaBlk?.unit)
  }

  getContentIconData = @() { contentIcon = ::image_for_air(unit?.name ?? ""), contentType = "unit" }
  canConsume = @() isInventoryItem && (unit?.isBought() ?? false)
  canPreview = @() unit ? unit.canPreview() : false
  doPreview  = @() unit && unit.doPreview()
}