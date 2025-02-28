from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import itemType

let ItemCouponBase = require("%scripts/items/itemsClasses/itemCouponBase.nut")
let { maxAllowedWarbondsBalance } = require("%scripts/warbonds/warbondsState.nut")
let { registerItemClass } = require("%scripts/items/itemsTypeClasses.nut")

let Warbonds = class (ItemCouponBase) {
  static iType = itemType.WARBONDS
  static name = "Warbonds"
  static typeIcon = "#ui/gameuiskin#item_type_warbonds.svg"

  getWarbond           = @() ::g_warbonds.findWarbond(this.metaBlk?.warbonds)
  getWarbondsAmount    = @() this.metaBlk?.count ?? 0

  function canConsume() {
    if (!this.isInventoryItem || this.getWarbondsAmount() <= 0)
      return false

    let warbond = this.getWarbond()
    if (warbond == null)
      return false


    return warbond.getBalance() < maxAllowedWarbondsBalance.get()
  }

  function getPrizeDescription(count, _colored = true) {
    if (!this.shouldAutoConsume)
      return null
    let wb = this.getWarbond()
    if (wb == 0)
      return null
    return count > 1 ? $"{wb} x{count}" : $"{wb}"
  }
}

registerItemClass(Warbonds)
