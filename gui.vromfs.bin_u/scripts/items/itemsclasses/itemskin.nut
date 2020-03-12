local ItemExternal = require("scripts/items/itemsClasses/itemExternal.nut")

class ::items_classes.Skin extends ItemExternal {
  static iType = itemType.SKIN
  static defaultLocId = "coupon"
  static combinedNameLocId = "coupon/name"
  static typeIcon = "#ui/gameuiskin#item_type_skin"
  static descHeaderLocId = "coupon/for/skin"

  unitId = null

  // Creates a real skin decorator, with unitId in name
  function addResourcesByUnitId(_unitId)
  {
    if (unitId)
      return
    unitId = _unitId
    addResources({ unitId = unitId })
  }

  getDecorator = @() ::g_decorator.getDecoratorByResource(metaBlk?.resource, metaBlk?.resourceType)

  getContentIconData = @() { contentIcon = typeIcon }
  getTagsLoc = @() getDecorator() ? getDecorator().getTagsLoc() : []
  canConsume = @() isInventoryItem ? (getDecorator() && !getDecorator().isUnlocked()) : false
  canPreview = @() getDecorator() ? getDecorator().canPreview() : false
  doPreview  = @() getDecorator() && getDecorator().doPreview()
}