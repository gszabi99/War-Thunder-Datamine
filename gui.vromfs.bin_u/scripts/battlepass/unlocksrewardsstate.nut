local { activeUnlocks, unlockProgress, emptyProgress
} = require("scripts/unlocks/userstatUnlocksState.nut")

local mkUnlockId = @(flag) ::Computed(@() activeUnlocks.value.findindex(@(unlock) unlock?.meta[flag] ?? false))
local basicUnlockId = mkUnlockId("season_challenges_common")
local premiumUnlockId = mkUnlockId("season_challenges_premium")

local basicUnlock = ::Computed(@() activeUnlocks.value?[basicUnlockId.value])
local premiumUnlock = ::Computed(@() activeUnlocks.value?[premiumUnlockId.value])
local basicProgress = ::Computed(@() unlockProgress.value?[basicUnlockId.value] ?? emptyProgress)
local premiumProgress = ::Computed(@() unlockProgress.value?[premiumUnlockId.value] ?? emptyProgress)

return {
  basicUnlockId
  premiumUnlockId
  basicUnlock
  premiumUnlock
  basicProgress
  premiumProgress
}