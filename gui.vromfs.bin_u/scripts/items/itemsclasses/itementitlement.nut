local ItemExternal = require("scripts/items/itemsClasses/itemExternal.nut")

class ::items_classes.Entitlement extends ItemExternal {
  static iType = itemType.ENTITLEMENT
  static defaultLocId = "coupon"
  static combinedNameLocId = "coupon/name"
  static typeIcon = "#ui/gameuiskin#item_type_premium"
  static descHeaderLocId = "coupon/for"

  getContentIconData   = @() { contentIcon = typeIcon }
  getResourceDesc      = @() ""
  getCreationCaption   = @() shouldAutoConsume ? ::loc("unlocks/entitlement") : base.getCreationCaption()

  getEntitlement       = @() metaBlk?.entitlement
  canConsume           = @() isInventoryItem && getEntitlement() != null
}