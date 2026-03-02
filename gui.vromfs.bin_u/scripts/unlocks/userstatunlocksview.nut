from "%scripts/dagui_library.nut" import *

let { getStageByIndex } = require("%scripts/unlocks/userstatUnlocksState.nut")
let { findItemById } = require("%scripts/items/itemsManagerModule.nut")


function getUnlockReward(userstatUnlock) {
  let rewardMarkUp = { rewardText = "", itemMarkUp = "" }
  let { lastRewardedStage = 0 } = userstatUnlock
  let stage = getStageByIndex(userstatUnlock, lastRewardedStage)
  if (stage == null)
    return rewardMarkUp

  let itemId = stage?.rewards.keys()[0]
  if (itemId != null) {
    let item = findItemById(to_integer_safe(itemId, itemId, false))
    rewardMarkUp.itemMarkUp = item?.getNameMarkup(stage.rewards[itemId]) ?? ""
  }

  rewardMarkUp.rewardText = "\n".join((stage?.updStats ?? [])
    .map(@(stat) loc($"updStats/{stat.name}", { amount = to_integer_safe(stat.value, 0) }, ""))
    .filter(@(rewardText) rewardText != ""))

  return rewardMarkUp
}


function getUnlockRewardMarkUp(userstatUnlock) {
  let rewardMarkUp = getUnlockReward(userstatUnlock)
  if (rewardMarkUp.rewardText == "" && rewardMarkUp.itemMarkUp == "")
    return {}

  let rewardLoc = (userstatUnlock?.isCompleted ?? false) ? loc("rewardReceived") : loc("reward")
  rewardMarkUp.rewardText <- $"{rewardLoc}{loc("ui/colon")}{rewardMarkUp.rewardText}"
  return rewardMarkUp
}


return {
  getUnlockReward
  getUnlockRewardMarkUp
}