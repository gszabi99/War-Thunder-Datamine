from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

let ItemCouponBase = require("%scripts/items/itemsClasses/itemCouponBase.nut")

::items_classes.ProfileIcon <- class extends ItemCouponBase {
  static iType = itemType.PROFILE_ICON

  getSmallIconName     = @() $"#ui/images/avatars/{getUnlockId()}.png"
  getContentIconData   = @() null
  canConsume           = @() isInventoryItem && canReceivePrize()

  getUnlockId          = @() metaBlk?.unlock

  function canReceivePrize() {
    let unlockId = getUnlockId()
    return unlockId != null && !::is_unlocked_scripted(-1, unlockId)
  }
}
