//checked for plus_string
from "%scripts/dagui_library.nut" import *


let ItemCouponBase = require("%scripts/items/itemsClasses/itemCouponBase.nut")
let { getTypeByResourceType } = require("%scripts/customization/types.nut")

::items_classes.InternalItem <- class extends ItemCouponBase {
  static iType = itemType.INTERNAL_ITEM
  static typeIcon = "#ui/gameuiskin#item_type_trophies.svg"

  getContentItem   = function() {
    let contentItem = this.metaBlk?.item ?? this.metaBlk?.trophy
    return contentItem && ::ItemsManager.findItemById(contentItem)
  }

  function canConsume() {
    let item = this.getContentItem()
    if (!this.isInventoryItem || !item)
      return false

    if (item.iType == itemType.TROPHY) {
      foreach (blk in item.getContent()) {
        let decoratorType = getTypeByResourceType(blk?.resourceType)
        if (!blk?.resource || !decoratorType.isPlayerHaveDecorator(blk.resource))
          return true
      }
      return false
    }

    return true
  }

  function updateShopFilterMask() {
    this.shopFilterMask = this.iType
    let contentItem = this.getContentItem()
    if (contentItem)
      this.shopFilterMask = this.shopFilterMask | contentItem.iType
  }

  getContentIconData   = function() {
    let contentItem = this.getContentItem()
    return contentItem ? { contentIcon = contentItem.typeIcon } : null
  }

  getIcon = @(addItemName = true) this.showAsContentItem()
    ? this.getContentItem()?.getIcon(addItemName) ?? base.getIcon(addItemName)
    : base.getIcon(addItemName)
  getSmallIconName = @() this.getContentItem()?.getSmallIconName() ?? this.typeIcon
  getBigIcon = @() this.showAsContentItem()
    ? this.getContentItem()?.getBigIcon() ?? base.getBigIcon()
    : base.getBigIcon()

  needShowRewardWnd = @() !this.metaBlk?.trophy

  function getViewData(params = {}) {
    if (this.showAsContentItem())
      return this.getContentItem()?.getViewData(
          params.__update({ count = (params?.count ?? 0) * (this.metaBlk?.count ?? 0) }))
        ?? base.getViewData(params)
    return base.getViewData(params)
  }

  showAsContentItem = @() this.itemDef?.tags?.showAsContentItem ?? false

  function getPrizeDescription(count = 1, colored = true) {
    let itemText = this.getShortDescription(colored)
    let quantity = count * (this.metaBlk?.count ?? 1)
    let quantityText = quantity == 1
      ? ""
      : $"x{quantity}"
    return  $"{itemText} {quantityText}"
  }

  getShortDescription = @(colored = true) this.showAsContentItem()
    ? this.getContentItem()?.getShortDescription(colored) ?? base.getShortDescription(colored)
    : base.getShortDescription(colored)

  function getSubstitutionItem() {
    if (this.showAsContentItem())
      return this.getContentItem()

    return base.getSubstitutionItem()
  }
}