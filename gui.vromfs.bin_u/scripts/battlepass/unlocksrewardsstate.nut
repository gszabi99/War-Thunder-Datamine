from "%scripts/dagui_library.nut" import *

let { activeUnlocks, unlockProgress, emptyProgress
} = require("%scripts/unlocks/userstatUnlocksState.nut")

let mkUnlockId = @(flag) Computed(@() activeUnlocks.get().findindex(@(unlock) unlock?.meta[flag] ?? false))
let basicUnlockId = mkUnlockId("season_challenges_common")
let premiumUnlockId = mkUnlockId("season_challenges_premium")

let basicUnlock = Computed(@() activeUnlocks.get()?[basicUnlockId.get()])
let premiumUnlock = Computed(@() activeUnlocks.get()?[premiumUnlockId.get()])

let curSeasonBattlePassUnlockId = Computed(@() premiumUnlock.get()?.requirement)
let hasBattlePass = Computed(@() curSeasonBattlePassUnlockId.get() != null
  && (activeUnlocks.get()?[curSeasonBattlePassUnlockId.get()].isCompleted ?? false))

let basicProgress = Computed(@() unlockProgress.get()?[basicUnlockId.get()] ?? emptyProgress)

let premiumProgress = Computed(@()
  !hasBattlePass.get() ? emptyProgress
    : (unlockProgress.get()?[premiumUnlockId.get()] ?? emptyProgress))

return {
  basicUnlockId
  premiumUnlockId
  basicUnlock
  basicProgress
  premiumProgress
  premiumUnlock
  hasBattlePass
}