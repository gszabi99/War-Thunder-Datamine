from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import itemType

let { getDecoratorByResource } = require("%scripts/customization/decorCache.nut")
let ItemCouponBase = require("%scripts/items/itemsClasses/itemCouponBase.nut")

let Skin = class (ItemCouponBase) {
  static iType = itemType.SKIN
  static name = "Skin"
  static typeIcon = "#ui/gameuiskin#item_type_skin.svg"
  static descHeaderLocId = "coupon/for/skin"

  unitId = null

  // Creates a real skin decorator, with unitId in name
  function addResourcesByUnitId(v_unitId) {
    if (this.unitId)
      return
    this.unitId = v_unitId
    this.addResources({ unitId = this.unitId })
  }

  getDecorator = @() getDecoratorByResource(this.metaBlk?.resource, this.metaBlk?.resourceType)

  getTagsLoc = @() this.getDecorator() ? this.getDecorator().getTagsLoc() : []
  canConsume = @() this.isInventoryItem ? (this.getDecorator() && !this.getDecorator().isUnlocked()) : false
  canPreview = @() this.getDecorator() ? this.getDecorator().canPreview() : false
  doPreview  = @() this.getDecorator() && this.getDecorator().doPreview()
}
return {Skin}