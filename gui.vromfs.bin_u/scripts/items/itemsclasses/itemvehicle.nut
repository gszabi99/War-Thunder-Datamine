from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let ItemCouponBase = require("%scripts/items/itemsClasses/itemCouponBase.nut")

::items_classes.ItemVehicle <- class extends ItemCouponBase {
  static iType = itemType.VEHICLE
  static typeIcon = "#ui/gameuiskin#item_type_blueprints.svg"
  static descHeaderLocId = "coupon/for/vehicle"

  unit = null

  function addResources() {
    base.addResources()
    this.unit = ::getAircraftByName(this.metaBlk?.unit)
  }

  getContentIconData = @() { contentIcon = ::image_for_air(this.unit?.name ?? ""), contentType = "unit" }
  canConsume = @() this.isInventoryItem && !(this.unit?.isBought() ?? true)
  canPreview = @() this.unit ? this.unit.canPreview() : false
  doPreview  = @() this.unit && this.unit.doPreview()
}