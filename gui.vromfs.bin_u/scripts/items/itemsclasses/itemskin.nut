from "%scripts/customization/decoratorGetters.nut" import getDecoratorByResource
from "%scripts/items/itemsTypeClasses.nut" import registerItemClass
from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import itemType

let ItemCouponBase = require("%scripts/items/itemsClasses/itemCouponBase.nut")

let Skin = class (ItemCouponBase) {
  static iType = itemType.SKIN
  static name = "Skin"
  static typeIcon = "#ui/gameuiskin#item_type_skin.svg"
  static descHeaderLocId = "coupon/for/skin"

  unitId = null

  
  function addResourcesByUnitId(v_unitId) {
    if (this.unitId)
      return
    this.unitId = v_unitId
    this.addResources(this.unitId)
  }

  getDecorator = @() getDecoratorByResource(this.metaBlk?.resource, this.metaBlk?.resourceType)

  getTagsLoc = @() this.getDecorator() ? this.getDecorator().getTagsLoc() : []
  canConsume = @() this.isInventoryItem ? (this.getDecorator() && !this.getDecorator().isUnlocked()) : false
  canPreview = @() this.getDecorator() ? this.getDecorator().canPreview() : false
  doPreview  = @() this.getDecorator() && this.getDecorator().doPreview()
}

registerItemClass(Skin)
