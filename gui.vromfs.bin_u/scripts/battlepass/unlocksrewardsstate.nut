//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { activeUnlocks, unlockProgress, emptyProgress, receiveRewards, getStageByIndex
} = require("%scripts/unlocks/userstatUnlocksState.nut")

let mkUnlockId = @(flag) Computed(@() activeUnlocks.value.findindex(@(unlock) unlock?.meta[flag] ?? false))
let basicUnlockId = mkUnlockId("season_challenges_common")
let premiumUnlockId = mkUnlockId("season_challenges_premium")

let basicUnlock = Computed(@() activeUnlocks.value?[basicUnlockId.value])
let premiumUnlock = Computed(@() activeUnlocks.value?[premiumUnlockId.value])

let curSeasonBattlePassUnlockId = Computed(@() premiumUnlock.value?.requirement)
let hasBattlePass = Computed(@() curSeasonBattlePassUnlockId.value != null
  && (activeUnlocks.value?[curSeasonBattlePassUnlockId.value].isCompleted ?? false))

let basicProgress = keepref(Computed(@() unlockProgress.value?[basicUnlockId.value] ?? emptyProgress))
let premiumProgress = keepref(Computed(function() {
  if (!hasBattlePass.value)
    return emptyProgress
  return unlockProgress.value?[premiumUnlockId.value] ?? emptyProgress
}))

let function receiveEmtyRewards(unlock, progressData) {
  if (!(unlock?.hasReward ?? false))
    return

  let curStageData = getStageByIndex(unlock, (progressData?.stage ?? 0) - 1)
  if (curStageData != null && (curStageData?.rewards.len() ?? 0) == 0)
    receiveRewards(unlock?.name, { showProgressBox = false }, false)
}

basicProgress.subscribe(@(progressData) receiveEmtyRewards(basicUnlock.value, progressData))
premiumProgress.subscribe(@(progressData) receiveEmtyRewards(premiumUnlock.value, progressData))

return {
  basicUnlockId
  premiumUnlockId
  basicUnlock
  premiumUnlock
  hasBattlePass
}