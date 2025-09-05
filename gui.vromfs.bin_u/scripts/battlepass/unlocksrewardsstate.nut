from "%scripts/dagui_library.nut" import *

let { activeUnlocks, unlockProgress, emptyProgress, receiveRewards, getStageByIndex, rewardsInProgress
} = require("%scripts/unlocks/userstatUnlocksState.nut")

let mkUnlockId = @(flag) Computed(@() activeUnlocks.value.findindex(@(unlock) unlock?.meta[flag] ?? false))
let basicUnlockId = mkUnlockId("season_challenges_common")
let premiumUnlockId = mkUnlockId("season_challenges_premium")

let basicUnlock = Computed(@() activeUnlocks.value?[basicUnlockId.get()])
let premiumUnlock = Computed(@() activeUnlocks.value?[premiumUnlockId.get()])

let curSeasonBattlePassUnlockId = Computed(@() premiumUnlock.get()?.requirement)
let hasBattlePass = Computed(@() curSeasonBattlePassUnlockId.get() != null
  && (activeUnlocks.value?[curSeasonBattlePassUnlockId.get()].isCompleted ?? false))

function getNotReceiveEmptyRewardStageIdx(unlock, progress, rewardsInProgressValue) {
  let { hasReward = false, name = "" } = unlock
  if (!hasReward || name in rewardsInProgressValue)
    return null


  let { stage = 0 } = progress
  let curStageData = getStageByIndex(unlock, stage - 1)
  if (curStageData != null && (curStageData?.rewards.len() ?? 0) == 0)
    return stage
  return null
}

let basicProgress = Computed(@() unlockProgress.value?[basicUnlockId.get()] ?? emptyProgress)
let basicEmptyRewardStageIdxForReceive = keepref(Computed(
  @() getNotReceiveEmptyRewardStageIdx(basicUnlock.get(), basicProgress.get(), rewardsInProgress.get())))

let premiumProgress = Computed(function() {
  if (!hasBattlePass.get())
    return emptyProgress
  return unlockProgress.value?[premiumUnlockId.get()] ?? emptyProgress
})
let premiumEmptyRewardStageForReceive = keepref(Computed(
  @() getNotReceiveEmptyRewardStageIdx(premiumUnlock.get(), premiumProgress.get(), rewardsInProgress.get())))

function receiveEmptyRewards(unlockId, stage) {
  if (unlockId == null)
    return
  log($"BattlePass: receive empty rewards for {unlockId} and {stage} stage")
  receiveRewards(unlockId, { taskOptions = { showProgressBox = false }, needShowRewardWnd = false })
}

basicEmptyRewardStageIdxForReceive.subscribe(@(stage) stage != null ? receiveEmptyRewards(basicUnlockId.get(), stage) : null)
premiumEmptyRewardStageForReceive.subscribe(@(stage) stage != null ? receiveEmptyRewards(premiumUnlockId.get(), stage) : null)

return {
  basicUnlockId
  premiumUnlockId
  basicUnlock
  premiumUnlock
  hasBattlePass
}