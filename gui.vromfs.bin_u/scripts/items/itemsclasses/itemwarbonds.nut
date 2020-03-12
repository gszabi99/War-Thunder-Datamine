local ItemExternal = require("scripts/items/itemsClasses/itemExternal.nut")

class ::items_classes.Warbonds extends ItemExternal {
  static iType = itemType.WARBONDS
  static defaultLocId = "coupon"
  static combinedNameLocId = "coupon/name"
  static typeIcon = "#ui/gameuiskin#item_type_warbonds"
  static descHeaderLocId = "coupon/for"

  getContentIconData   = @() { contentIcon = typeIcon }
  getResourceDesc      = @() ""
  getCreationCaption   = @() shouldAutoConsume ? ::loc("unlocks/entitlement") : base.getCreationCaption()

  getWarbond           = @() ::g_warbonds.findWarbond(metaBlk?.warbonds)
  getWarbondsAmount    = @() metaBlk?.count || 0
  canConsume           = @() isInventoryItem && getWarbond() != null && getWarbondsAmount() > 0

  function getPrizeDescription(count)
  {
    if (!shouldAutoConsume)
      return null
    local wb = getWarbond()
    return wb && (count * getWarbondsAmount())  //prize already has type icon, so we no need 2 warbond icons near amount number
  }
}