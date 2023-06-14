//checked for plus_string
from "%scripts/dagui_library.nut" import *
let { LayersIcon } = require("%scripts/viewUtils/layeredIcon.nut")

let ItemCouponBase = require("%scripts/items/itemsClasses/itemCouponBase.nut")
let { getEntitlementConfig, getEntitlementName,
  getEntitlementDescription } = require("%scripts/onlineShop/entitlements.nut")

::items_classes.Entitlement <- class extends ItemCouponBase {
  static iType = itemType.ENTITLEMENT
  static typeIcon = "#ui/gameuiskin#item_type_premium.svg"

  getEntitlement = @() this.metaBlk?.entitlement
  canConsume = @() this.isInventoryItem && this.getEntitlement() != null
  showAsContentItem = @() this.itemDef?.tags?.showAsContentItem ?? false
  getConfig = @() getEntitlementConfig(this.getEntitlement())

  getName = @(colored = true) this.showAsContentItem() ? getEntitlementName(this.getConfig())
    : base.getName(colored)

  getDescription = @() this.showAsContentItem() ? getEntitlementDescription(this.getConfig(), this.getEntitlement())
    : base.getDescription()

  getBigIcon = @() this.getIcon()

  function getIcon(addItemName = true) {
    return this.showAsContentItem()
      ? LayersIcon.getIconData(null, this.typeIcon)
      : base.getIcon(addItemName)
  }
}
