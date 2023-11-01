from "%scripts/dagui_library.nut" import *
let { getCurGameModeMinMRankForNightBattles } = require("%scripts/events/eventInfo.nut")

function canGoToNightBattleOnUnit(unit, modeName = null) {
  if (unit == null)
    return false

  let curEvent = ::game_mode_manager.getCurrentGameMode()?.getEvent()
  if (curEvent == null)
    return false
  let minMRank = getCurGameModeMinMRankForNightBattles(curEvent)
  if (minMRank == null || (minMRank > unit.getEconomicRank(::events.getEDiffByEvent(curEvent))))
    return false

  if (modeName != null)
    return unit.getNVDSights(modeName).len() > 0
  return unit.modifications.findvalue(@(v) unit.getNVDSights(v.name).len() > 0) != null
}

return {
  canGoToNightBattleOnUnit
}
