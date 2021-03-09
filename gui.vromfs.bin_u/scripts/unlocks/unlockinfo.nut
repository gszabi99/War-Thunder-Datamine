local function getMedalRibbonImg(unlockId) {
  return $"!@ui/medals/{unlockId}_ribbon"
}

local function hasMedalRibbonImg(unlockId) {
  local unlock = ::g_unlocks.getUnlockById(unlockId)
  return unlock?.hasRibbonImg ?? (unlock?.type == "medal")
}

return {
  getMedalRibbonImg
  hasMedalRibbonImg
}