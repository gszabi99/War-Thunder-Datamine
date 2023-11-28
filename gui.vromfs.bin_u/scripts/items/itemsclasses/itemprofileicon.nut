from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import itemType

let { isUnlockOpened } = require("%scripts/unlocks/unlocksModule.nut")
let ItemCouponBase = require("%scripts/items/itemsClasses/itemCouponBase.nut")

::items_classes.ProfileIcon <- class extends ItemCouponBase {
  static iType = itemType.PROFILE_ICON

  getSmallIconName     = @() $"#ui/images/avatars/{this.getUnlockId()}"
  getContentIconData   = @() null
  canConsume           = @() this.isInventoryItem && this.canReceivePrize()

  getUnlockId          = @() this.metaBlk?.unlock

  function canReceivePrize() {
    let unlockId = this.getUnlockId()
    return unlockId != null && !isUnlockOpened(unlockId)
  }
}
