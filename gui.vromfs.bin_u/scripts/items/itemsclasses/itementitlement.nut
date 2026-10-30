from "%scripts/viewUtils/layeredIcon.nut" import LayersIcon
from "%scripts/onlineShop/entitlements.nut" import getEntitlementConfig, getEntitlementName, getEntitlementDescription
from "%scripts/items/itemsTypeClasses.nut" import registerItemClass
from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import itemType

let ItemCouponBase = require("%scripts/items/itemsClasses/itemCouponBase.nut")

let Entitlement = class (ItemCouponBase) {
  static name = "Entitlement"
  static iType = itemType.ENTITLEMENT
  static typeIcon = "#ui/gameuiskin#item_type_premium.svg"
  allowBigPicture = false

  getEntitlement = @() this.metaBlk?.entitlement
  canConsume = @() this.isInventoryItem && this.getEntitlement() != null
  showAsContentItem = @() this.itemDef?.tags.showAsContentItem ?? false
  function getConfig() {
    let config = getEntitlementConfig(this.getEntitlement())
    if (config != null)
      config.isItem <- true
    return config
  }

  getName = @(colored = true) this.showAsContentItem() ? getEntitlementName(this.getConfig())
    : base.getName(colored)

  getDescription = @() this.showAsContentItem() ? getEntitlementDescription(this.getConfig(), this.getEntitlement())
    : base.getDescription()

  getBigIcon = @() this.getIcon()

  function getIcon(addItemName = true) {
    return this.showAsContentItem()
      ? LayersIcon.getIconData("reward_entitlement")
      : base.getIcon(addItemName)
  }
}

registerItemClass(Entitlement)
