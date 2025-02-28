from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import *

let { getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")
let { cutPostfix } = require("%sqstd/string.nut")
let { getUnlockRewardsText, buildConditionsConfig } = require("%scripts/unlocks/unlocksViewModule.nut")
let { isPrizeMultiAward} = require("%scripts/items/trophyMultiAward.nut")

let unlockAddProgressView = {
  battlpass_progress = {
    image = "#ui/gameuiskin#item_type_bp.svg"
    function getText(prize, v_typeName) {
      let progressArray = prize.unlockAddProgress.split("_")
      let value = progressArray.top()
      let typeName = cutPostfix(prize.unlockAddProgress, $"_{value}")
      return v_typeName ? loc(typeName)
        : loc("progress/amount", { amount = value.tointeger() * (prize?.count ?? 1) })
    }
    showCount = false
  }
  battlepass_add_warbonds = {
    image = "#ui/gameuiskin#item_warbonds.avif"
    function getText(prize, _v_typeName) {
      let unlock = getUnlockById(prize.unlockAddProgress)
      if (unlock == null)
        return ""

      let config = buildConditionsConfig(unlock)
      return config.maxVal <= (prize?.count ?? 1) ? getUnlockRewardsText(config)
        : ""
    }
    getDescription = @(_prize) loc("warbond/desc")
  }
}

let isUnlockAddProgressPrize = @(prize) prize?.unlockAddProgress != null
  && unlockAddProgressView.findvalue(@(_, key) prize.unlockAddProgress.indexof(key) != null)

enum PRIZE_TYPE {
  UNKNOWN
  MULTI_AWARD
  ITEM
  TROPHY
  UNIT
  RENTED_UNIT
  MODIFICATION
  SPARE
  SPECIALIZATION
  PREMIUM_ACCOUNT
  ENTITLEMENT
  UNLOCK
  UNLOCK_TYPE
  GOLD
  WARPOINTS
  EXP
  WARBONDS
  RESOURCE
  UNLOCK_PROGRESS
}

function getPrizeType(prize) {
  if (isPrizeMultiAward(prize))
    return PRIZE_TYPE.MULTI_AWARD
  if (prize?.item)
    return PRIZE_TYPE.ITEM
  if (prize?.trophy)
    return PRIZE_TYPE.TROPHY
  if (prize?.unit)
    return prize?.mod ? PRIZE_TYPE.MODIFICATION : PRIZE_TYPE.UNIT
  if (prize?.rentedUnit)
    return PRIZE_TYPE.RENTED_UNIT
  if (prize?.spare)
    return PRIZE_TYPE.SPARE
  if (prize?.specialization)
    return PRIZE_TYPE.SPECIALIZATION
  if (prize?.premium_in_hours)
    return PRIZE_TYPE.PREMIUM_ACCOUNT
  if (prize?.entitlement)
    return PRIZE_TYPE.ENTITLEMENT
  if (prize?.unlock)
    return PRIZE_TYPE.UNLOCK
  if (prize?.unlocktype)
    return PRIZE_TYPE.UNLOCK_TYPE
  if (prize?.gold)
    return PRIZE_TYPE.GOLD
  if (prize?.warpoints)
    return PRIZE_TYPE.WARPOINTS
  if (prize?.exp)
    return PRIZE_TYPE.EXP
  if (prize?.warbonds)
    return PRIZE_TYPE.WARBONDS
  if (prize?.resource)
    return PRIZE_TYPE.RESOURCE
  if (isUnlockAddProgressPrize(prize))
    return PRIZE_TYPE.UNLOCK_PROGRESS
  return PRIZE_TYPE.UNKNOWN
}

let hasKnowPrize = @(prize) getPrizeType(prize) != PRIZE_TYPE.UNKNOWN

return {
  hasKnowPrize
  unlockAddProgressView
  PRIZE_TYPE
  getPrizeType
}