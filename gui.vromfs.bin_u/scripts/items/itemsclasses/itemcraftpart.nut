let ItemExternal = require("%scripts/items/itemsClasses/itemExternal.nut")

::items_classes.CraftPart <- class extends ItemExternal {
  static iType = itemType.CRAFT_PART
  static defaultLocId = "craft_part"
  static typeIcon = "#ui/gameuiskin#item_type_craftpart"

  canConsume            = @() false
  shouldShowAmount      = @(count) count >= 0
  getOpenedBigIcon      = @() ""

  getLocIdsListImpl = @() base.getLocIdsListImpl().__update({
    openingRewardTitle = "mainmenu/itemCreated/title"
  })
}