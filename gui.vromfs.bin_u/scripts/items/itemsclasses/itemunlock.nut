let ItemCouponBase = require("%scripts/items/itemsClasses/itemCouponBase.nut")

::items_classes.Unlock <- class extends ItemCouponBase {
  static iType = itemType.UNLOCK
  static typeIcon = "#ui/gameuiskin#item_type_unlock"

  getUnlockId          = @() metaBlk?.unlock ?? metaBlk?.unlockAddProgress
  canConsume           = @() isInventoryItem && canReceivePrize()

  function canReceivePrize() {
    let unlockId = getUnlockId()
    return unlockId != null && !::is_unlocked_scripted(-1, unlockId)
  }

  function getSmallIconName() {
    let unlock = getUnlock()
    if (unlock == null)
      return typeIcon

    let config = ::build_conditions_config(unlock)
    if ((config?.reward.gold ?? 0) > 0)
      return "#ui/gameuiskin#item_type_eagles"
    if ((config?.reward.wp ?? 0) > 0)
      return "#ui/gameuiskin#item_type_warpoints"
    if ((config?.reward.frp ?? 0) > 0)
      return "#ui/gameuiskin#item_type_RP"
    if ((config?.rewardWarbonds?.wbAmount ?? 0) > 0)
      return "#ui/gameuiskin#item_type_warbonds"

    return typeIcon
  }

  function getUnlock() {
    let unlockId = getUnlockId()
    if (unlockId == null)
      return null

    return ::g_unlocks.getUnlockById(unlockId)
  }

  getWarbondsAmount = @() getUnlock()?.amount_warbonds ?? 0
}