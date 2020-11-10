local ItemCouponBase = require("scripts/items/itemsClasses/itemCouponBase.nut")

class ::items_classes.InternalItem extends ItemCouponBase
{
  static iType = itemType.INTERNAL_ITEM
  static typeIcon = "#ui/gameuiskin#item_type_trophies"

  getContentItem   = function()
  {
    local contentItem = metaBlk?.item ?? metaBlk?.trophy
    return contentItem && ::ItemsManager.findItemById(contentItem)
  }

  function canConsume()
  {
    local item = getContentItem()
    if (!isInventoryItem || !item)
      return false

    if (item.iType == itemType.TROPHY) {
      foreach (blk in item.getContent())
      {
        local decoratorType = ::g_decorator_type.getTypeByResourceType(blk?.resourceType)
        if (!blk?.resource || !decoratorType.isPlayerHaveDecorator(blk.resource))
          return true
      }
      return false
    }

    return true
  }

  function updateShopFilterMask()
  {
    shopFilterMask = iType
    local contentItem = getContentItem()
    if (contentItem)
      shopFilterMask = shopFilterMask | contentItem.iType
  }

  getContentIconData   = function()
  {
    local contentItem = getContentItem()
    return contentItem && { contentIcon = contentItem.typeIcon }
  }

  getIcon = @(addItemName = true) showAsContentItem()
    ? getContentItem()?.getIcon(addItemName) ?? base.getIcon(addItemName)
    : base.getIcon(addItemName)
  getSmallIconName = @() getContentItem()?.getSmallIconName() ?? typeIcon
  getBigIcon = @() showAsContentItem()
    ? getContentItem()?.getBigIcon() ?? base.getBigIcon()
    : base.getBigIcon()

  needShowRewardWnd = @() !metaBlk?.trophy

  function getViewData(params = {}) {
    if (showAsContentItem())
      return getContentItem()?.getViewData(
          params.__update({count = (params?.count ?? 0) * (metaBlk?.count ?? 0)}))
        ?? base.getViewData(params)
    return base.getViewData(params)
  }

  showAsContentItem = @() itemDef?.tags?.showAsContentItem ?? false
}