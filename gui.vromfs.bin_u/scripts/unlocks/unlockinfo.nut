let function getMedalRibbonImg(unlockId) {
  return $"!@ui/medals/{unlockId}_ribbon.ddsx"
}

let function hasMedalRibbonImg(unlockId) {
  let unlock = ::g_unlocks.getUnlockById(unlockId)
  return unlock?.hasRibbonImg ?? (unlock?.type == "medal")
}

return {
  getMedalRibbonImg
  hasMedalRibbonImg
}