from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let ItemCouponBase = require("%scripts/items/itemsClasses/itemCouponBase.nut")

::items_classes.InternalItem <- class extends ItemCouponBase
{
  static iType = itemType.INTERNAL_ITEM
  static typeIcon = "#ui/gameuiskin#item_type_trophies.svg"

  getContentItem   = function()
  {
    let contentItem = this.metaBlk?.item ?? this.metaBlk?.trophy
    return contentItem && ::ItemsManager.findItemById(contentItem)
  }

  function canConsume()
  {
    let item = getContentItem()
    if (!this.isInventoryItem || !item)
      return false

    if (item.iType == itemType.TROPHY) {
      foreach (blk in item.getContent())
      {
        let decoratorType = ::g_decorator_type.getTypeByResourceType(blk?.resourceType)
        if (!blk?.resource || !decoratorType.isPlayerHaveDecorator(blk.resource))
          return true
      }
      return false
    }

    return true
  }

  function updateShopFilterMask()
  {
    this.shopFilterMask = iType
    let contentItem = getContentItem()
    if (contentItem)
      this.shopFilterMask = this.shopFilterMask | contentItem.iType
  }

  getContentIconData   = function()
  {
    let contentItem = getContentItem()
    return contentItem ? { contentIcon = contentItem.typeIcon } : null
  }

  getIcon = @(addItemName = true) showAsContentItem()
    ? getContentItem()?.getIcon(addItemName) ?? base.getIcon(addItemName)
    : base.getIcon(addItemName)
  getSmallIconName = @() getContentItem()?.getSmallIconName() ?? typeIcon
  getBigIcon = @() showAsContentItem()
    ? getContentItem()?.getBigIcon() ?? base.getBigIcon()
    : base.getBigIcon()

  needShowRewardWnd = @() !this.metaBlk?.trophy

  function getViewData(params = {}) {
    if (showAsContentItem())
      return getContentItem()?.getViewData(
          params.__update({count = (params?.count ?? 0) * (this.metaBlk?.count ?? 0)}))
        ?? base.getViewData(params)
    return base.getViewData(params)
  }

  showAsContentItem = @() this.itemDef?.tags?.showAsContentItem ?? false

  function getPrizeDescription(count = 1, colored = true)
  {
    let itemText = getShortDescription(colored)
    let quantity = count * (this.metaBlk?.count ?? 1)
    let quantityText = quantity == 1
      ? ""
      : $"x{quantity}"
    return  $"{itemText} {quantityText}"
  }

  getShortDescription = @(colored = true) showAsContentItem()
    ? getContentItem()?.getShortDescription(colored) ?? base.getShortDescription(colored)
    : base.getShortDescription(colored)

  function getSubstitutionItem()
  {
    if (showAsContentItem())
      return getContentItem()

    return base.getSubstitutionItem()
  }
}