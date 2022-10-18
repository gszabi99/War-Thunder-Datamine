from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let ItemCouponBase = require("%scripts/items/itemsClasses/itemCouponBase.nut")

::items_classes.Skin <- class extends ItemCouponBase {
  static iType = itemType.SKIN
  static typeIcon = "#ui/gameuiskin#item_type_skin.svg"
  static descHeaderLocId = "coupon/for/skin"

  unitId = null

  // Creates a real skin decorator, with unitId in name
  function addResourcesByUnitId(v_unitId)
  {
    if (unitId)
      return
    unitId = v_unitId
    this.addResources({ unitId = unitId })
  }

  getDecorator = @() ::g_decorator.getDecoratorByResource(this.metaBlk?.resource, this.metaBlk?.resourceType)

  getTagsLoc = @() getDecorator() ? getDecorator().getTagsLoc() : []
  canConsume = @() this.isInventoryItem ? (getDecorator() && !getDecorator().isUnlocked()) : false
  canPreview = @() getDecorator() ? getDecorator().canPreview() : false
  doPreview  = @() getDecorator() && getDecorator().doPreview()
}