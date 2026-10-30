from "%scripts/unlocks/userstatUnlocksState.nut" import activeUnlocks, unlockProgress
from "%scripts/userstat/userstat.nut" import userstatDescList, toPlainData
from "%scripts/dagui_library.nut" import *

let { emptyProgress } = require("%scripts/unlocks/userstatUnlocksState.nut")

let mkUnlockId = @(flag) Computed(@() activeUnlocks.get().findindex(@(unlock) unlock?.meta[flag] ?? false))
let basicUnlockId = mkUnlockId("season_challenges_common")
let premiumUnlockId = mkUnlockId("season_challenges_premium")

let basicUnlock = Computed(@() activeUnlocks.get()?[basicUnlockId.get()])
let premiumUnlock = Computed(@() activeUnlocks.get()?[premiumUnlockId.get()])


let mkUnlockMeta = @(unlockId) Computed(@() toPlainData(userstatDescList.get()?.unlocks?[unlockId.get()]?.meta))
let basicUnlockMeta = mkUnlockMeta(basicUnlockId)
let premiumUnlockMeta = mkUnlockMeta(premiumUnlockId)

let curSeasonBattlePassUnlockId = Computed(@() premiumUnlock.get()?.requirement)
let hasBattlePass = Computed(@() curSeasonBattlePassUnlockId.get() != null
  && (activeUnlocks.get()?[curSeasonBattlePassUnlockId.get()].isCompleted ?? false))

let basicProgress = Computed(@() unlockProgress.get()?[basicUnlockId.get()] ?? emptyProgress)

let premiumProgress = Computed(@()
  !hasBattlePass.get() ? emptyProgress
    : (unlockProgress.get()?[premiumUnlockId.get()] ?? emptyProgress))

return freeze({
  basicUnlockId
  premiumUnlockId
  basicUnlock
  basicProgress
  premiumProgress
  premiumUnlock
  basicUnlockMeta
  premiumUnlockMeta
  hasBattlePass
})