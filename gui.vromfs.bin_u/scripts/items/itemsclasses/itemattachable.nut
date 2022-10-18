let ItemCouponBase = require("%scripts/items/itemsClasses/itemCouponBase.nut")

::items_classes.Attachable <- class extends ItemCouponBase {
  static iType = itemType.ATTACHABLE
  static typeIcon = "#ui/gameuiskin#item_type_attachable.svg"
  static descHeaderLocId = "coupon/for/attachable"

  getDecorator = @() ::g_decorator.getDecoratorByResource(metaBlk?.resource, metaBlk?.resourceType)

  canConsume = @() isInventoryItem ? (getDecorator() && !getDecorator().isUnlocked()) : false
  canPreview = @() getDecorator() ? getDecorator().canPreview() : false
  doPreview  = @() getDecorator() && getDecorator().doPreview()
}