from "%scripts/userstat/userstatItemsRewards.nut" import receiveRewards, rewardsInProgress
from "%scripts/unlocks/userstatUnlocksState.nut" import getStageByIndex
from "%scripts/battlePass/unlocksRewardsState.nut" import basicUnlock, basicProgress, premiumUnlock, premiumProgress, basicUnlockId, premiumUnlockId
from "%scripts/dagui_library.nut" import *

function getNotReceiveEmptyRewardStageIdx(unlock, progress, rewardsInProgressValue) {
  let { hasReward = false, name = "" } = unlock
  if (!hasReward || name in rewardsInProgressValue)
    return null

  let { stage = 0 } = progress
  let curStageData = getStageByIndex(unlock, stage - 1)

  return curStageData != null && (curStageData?.rewards.len() ?? 0) == 0 ? stage : null
}


let basicEmptyRewardStageIdxForReceive = keepref(Computed(@()
  getNotReceiveEmptyRewardStageIdx(
    basicUnlock.get(), basicProgress.get(), rewardsInProgress.get()
  )))

let premiumEmptyRewardStageForReceive = keepref(Computed(@()
  getNotReceiveEmptyRewardStageIdx(
    premiumUnlock.get(), premiumProgress.get(), rewardsInProgress.get()
  )))


function receiveEmptyRewards(unlockId, stage) {
  if (unlockId == null)
    return

  log($"BattlePass: receive empty rewards for {unlockId} and {stage} stage")
  receiveRewards(unlockId, { taskOptions = { showProgressBox = false }, needShowRewardWnd = false })
}

basicEmptyRewardStageIdxForReceive.subscribe(@(stage)
  stage != null ? receiveEmptyRewards(basicUnlockId.get(), stage) : null)

premiumEmptyRewardStageForReceive.subscribe(@(stage)
  stage != null ? receiveEmptyRewards(premiumUnlockId.get(), stage) : null)
