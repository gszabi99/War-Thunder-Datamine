from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import itemType

let { isUnlockOpened } = require("%scripts/unlocks/unlocksModule.nut")
let ItemCouponBase = require("%scripts/items/itemsClasses/itemCouponBase.nut")

let ProfileIcon = class (ItemCouponBase) {
  static iType = itemType.PROFILE_ICON
  static name = "ProfileIcon"
  getSmallIconName     = @() $"#ui/images/avatars/{this.getUnlockId()}.avif"
  getContentIconData   = @() null
  canConsume           = @() this.isInventoryItem && this.canReceivePrize()

  getUnlockId          = @() this.metaBlk?.unlock

  function canReceivePrize() {
    let unlockId = this.getUnlockId()
    return unlockId != null && !isUnlockOpened(unlockId)
  }
}
return {ProfileIcon}