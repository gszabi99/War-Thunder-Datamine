from "%scripts/dagui_library.nut" import *
let { get_wpcost_blk } = require("blkGetters")
let {TrophyMultiAward, isPrizeMultiAward }= require("%scripts/items/trophyMultiAward.nut")
let { findItemById } = require("%scripts/items/itemsManager.nut")

function getGiftSparesCount(unit) {
  let unitBlk = get_wpcost_blk()?[unit.name]
  let purchaseTrophyGift = unitBlk?.purchaseTrophyGift
    ?? unitBlk?.clanGoldPurchaseTrophyGift

  if(purchaseTrophyGift == null)
    return 0
  let trophy = findItemById(purchaseTrophyGift)
  if(trophy == null)
    return 0
  local content = trophy.getContent()
  local spare_count = 0
  foreach(item in content) {
    if(isPrizeMultiAward(item)) {
      let multiAward = TrophyMultiAward(item)
      let awardsType = multiAward.getAwardsType()
      if(awardsType == "spare")
        spare_count += multiAward.getCount()
    }
  }
  return spare_count
}

function getGiftSparesCost(unit) {
  let unitName = typeof(unit) == "string" ? unit : unit.name
  return get_wpcost_blk()?[unitName].spare.costGold ?? 0
}

return {
  getGiftSparesCount
  getGiftSparesCost
}