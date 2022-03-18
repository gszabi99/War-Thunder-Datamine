let { activeUnlocks, unlockProgress, emptyProgress
} = require("%scripts/unlocks/userstatUnlocksState.nut")

let mkUnlockId = @(flag) ::Computed(@() activeUnlocks.value.findindex(@(unlock) unlock?.meta[flag] ?? false))
let basicUnlockId = mkUnlockId("season_challenges_common")
let premiumUnlockId = mkUnlockId("season_challenges_premium")

let basicUnlock = ::Computed(@() activeUnlocks.value?[basicUnlockId.value])
let premiumUnlock = ::Computed(@() activeUnlocks.value?[premiumUnlockId.value])
let basicProgress = ::Computed(@() unlockProgress.value?[basicUnlockId.value] ?? emptyProgress)
let premiumProgress = ::Computed(@() unlockProgress.value?[premiumUnlockId.value] ?? emptyProgress)

return {
  basicUnlockId
  premiumUnlockId
  basicUnlock
  premiumUnlock
  basicProgress
  premiumProgress
}