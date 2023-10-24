from "%scripts/dagui_library.nut" import *
let { get_wpcost_blk } = require("blkGetters")
let TrophyMultiAward = require("%scripts/items/trophyMultiAward.nut")

let function getGiftSparesCount(unit) {
  let purchaseTrophyGift = get_wpcost_blk()?[unit.name].purchaseTrophyGift
  if(purchaseTrophyGift == null)
    return 0
  let trophy = ::ItemsManager.findItemById(purchaseTrophyGift)
  if(trophy == null)
    return 0
  local content = trophy.getContent()
  local spare_count = 0
  foreach(item in content) {
    if(::PrizesView.isPrizeMultiAward(item)) {
      let multiAward = TrophyMultiAward(item)
      let awardsType = multiAward.getAwardsType()
      if(awardsType == "spare")
        spare_count += multiAward.getCount()
    }
  }
  return spare_count
}

let function getGiftSparesCost(unit) {
  let unitName = typeof(unit) == "string" ? unit : unit.name
  return get_wpcost_blk()?[unitName].spare.costGold ?? 0
}

return {
  getGiftSparesCount
  getGiftSparesCost
}