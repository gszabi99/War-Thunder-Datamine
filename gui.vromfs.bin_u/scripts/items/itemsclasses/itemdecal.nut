from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import itemType

let { getDecoratorByResource } = require("%scripts/customization/decorCache.nut")
let ItemCouponBase = require("%scripts/items/itemsClasses/itemCouponBase.nut")

::items_classes.Decal <- class extends ItemCouponBase {
  static iType = itemType.DECAL
  static typeIcon = "#ui/gameuiskin#item_type_decal.svg"
  static descHeaderLocId = "coupon/for/decal"

  getDecorator = @() getDecoratorByResource(this.metaBlk?.resource, this.metaBlk?.resourceType)

  canConsume = @() this.isInventoryItem ? (this.getDecorator() && !this.getDecorator().isUnlocked()) : false
  canPreview = @() this.getDecorator() ? this.getDecorator().canPreview() : false
  doPreview  = @() this.getDecorator() && this.getDecorator().doPreview()
}