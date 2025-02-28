from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import itemType

let ItemCouponBase = require("%scripts/items/itemsClasses/itemCouponBase.nut")
let { image_for_air } = require("%scripts/unit/unitInfo.nut")
let { registerItemClass } = require("%scripts/items/itemsTypeClasses.nut")

let ItemVehicle = class (ItemCouponBase) {
  static iType = itemType.VEHICLE
  static name = "ItemVehicle"
  static typeIcon = "#ui/gameuiskin#item_type_blueprints.svg"
  static descHeaderLocId = "coupon/for/vehicle"

  unit = null

  function addResources() {
    base.addResources()
    this.unit = getAircraftByName(this.metaBlk?.unit)
  }

  getContentIconData = @() { contentIcon = image_for_air(this.unit?.name ?? ""), contentType = "unit" }
  canConsume = @() this.isInventoryItem && !(this.unit?.isBought() ?? true)
  canPreview = @() this.unit ? this.unit.canPreview() : false
  doPreview  = @() this.unit && this.unit.doPreview()
}

registerItemClass(ItemVehicle)
