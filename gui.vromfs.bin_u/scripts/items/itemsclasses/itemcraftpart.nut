local ItemExternal = require("scripts/items/itemsClasses/itemExternal.nut")

class ::items_classes.CraftPart extends ItemExternal {
  static iType = itemType.CRAFT_PART
  static defaultLocId = "craft_part"
  static typeIcon = "#ui/gameuiskin#item_type_craftpart"
  static openingCaptionLocId = "mainmenu/itemCreated/title"

  canConsume            = @() false
  shouldShowAmount      = @(count) count >= 0
  getOpenedBigIcon      = @() ""
}