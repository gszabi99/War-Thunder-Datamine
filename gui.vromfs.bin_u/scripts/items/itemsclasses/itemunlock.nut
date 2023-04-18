//checked for plus_string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let ItemCouponBase = require("%scripts/items/itemsClasses/itemCouponBase.nut")
let { getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")

::items_classes.Unlock <- class extends ItemCouponBase {
  static iType = itemType.UNLOCK
  static typeIcon = "#ui/gameuiskin#item_type_unlock.svg"

  getUnlockId          = @() this.metaBlk?.unlock ?? this.metaBlk?.unlockAddProgress
  canConsume           = @() this.isInventoryItem && this.canReceivePrize()

  function canReceivePrize() {
    let unlockId = this.getUnlockId()
    return unlockId != null && !::is_unlocked_scripted(-1, unlockId)
  }

  function getSmallIconName() {
    let unlock = this.getUnlock()
    if (unlock == null)
      return this.typeIcon

    let config = ::build_conditions_config(unlock)
    if ((config?.reward.gold ?? 0) > 0)
      return "#ui/gameuiskin#item_type_eagles.svg"
    if ((config?.reward.wp ?? 0) > 0)
      return "#ui/gameuiskin#item_type_warpoints.svg"
    if ((config?.reward.frp ?? 0) > 0)
      return "#ui/gameuiskin#item_type_RP.svg"
    if ((config?.rewardWarbonds?.wbAmount ?? 0) > 0)
      return "#ui/gameuiskin#item_type_warbonds.svg"

    return this.typeIcon
  }

  function getUnlock() {
    let unlockId = this.getUnlockId()
    if (unlockId == null)
      return null

    return getUnlockById(unlockId)
  }

  getWarbondsAmount = @() this.getUnlock()?.amount_warbonds ?? 0
}