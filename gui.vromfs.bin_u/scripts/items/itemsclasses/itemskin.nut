from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let ItemCouponBase = require("%scripts/items/itemsClasses/itemCouponBase.nut")

::items_classes.Skin <- class extends ItemCouponBase {
  static iType = itemType.SKIN
  static typeIcon = "#ui/gameuiskin#item_type_skin.svg"
  static descHeaderLocId = "coupon/for/skin"

  unitId = null

  // Creates a real skin decorator, with unitId in name
  function addResourcesByUnitId(v_unitId)
  {
    if (this.unitId)
      return
    this.unitId = v_unitId
    this.addResources({ unitId = this.unitId })
  }

  getDecorator = @() ::g_decorator.getDecoratorByResource(this.metaBlk?.resource, this.metaBlk?.resourceType)

  getTagsLoc = @() this.getDecorator() ? this.getDecorator().getTagsLoc() : []
  canConsume = @() this.isInventoryItem ? (this.getDecorator() && !this.getDecorator().isUnlocked()) : false
  canPreview = @() this.getDecorator() ? this.getDecorator().canPreview() : false
  doPreview  = @() this.getDecorator() && this.getDecorator().doPreview()
}