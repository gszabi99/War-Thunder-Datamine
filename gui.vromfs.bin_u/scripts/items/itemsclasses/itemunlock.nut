from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import itemType

let { isUnlockOpened } = require("%scripts/unlocks/unlocksModule.nut")
let ItemCouponBase = require("%scripts/items/itemsClasses/itemCouponBase.nut")
let { getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")
let { buildConditionsConfig } = require("%scripts/unlocks/unlocksViewModule.nut")
let { registerItemClass } = require("%scripts/items/itemsTypeClasses.nut")

let Unlock = class (ItemCouponBase) {
  static iType = itemType.UNLOCK
  static name = "Unlock"
  static typeIcon = "#ui/gameuiskin#item_type_unlock.svg"

  getUnlockId          = @() this.metaBlk?.unlock ?? this.metaBlk?.unlockAddProgress
  canConsume           = @() this.isInventoryItem && this.canReceivePrize()

  function canReceivePrize() {
    let unlockId = this.getUnlockId()
    return unlockId != null && !isUnlockOpened(unlockId)
  }

  function getSmallIconName() {
    let unlock = this.getUnlock()
    if (unlock == null)
      return this.typeIcon

    let config = buildConditionsConfig(unlock)
    if ((config?.reward.gold ?? 0) > 0)
      return "#ui/gameuiskin#item_type_eagles.svg"
    if ((config?.reward.wp ?? 0) > 0)
      return "#ui/gameuiskin#item_type_warpoints.svg"
    if ((config?.reward.frp ?? 0) > 0)
      return "#ui/gameuiskin#item_type_RP.svg"
    if ((config?.rewardWarbonds.wbAmount ?? 0) > 0)
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

registerItemClass(Unlock)
