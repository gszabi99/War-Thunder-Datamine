//checked for plus_string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let function getCurEsUnitTypesList(needRequiredOnly = false) {
  let gameModeId = ::game_mode_manager.getCurrentGameModeId()
  let gameMode = ::game_mode_manager.getGameModeById(gameModeId)
  return ::game_mode_manager._getUnitTypesByGameMode(gameMode, true, needRequiredOnly)
}

let function getCurEsUnitTypesMask() {
  local esUnitTypes = getCurEsUnitTypesList(true)
  if (!esUnitTypes.len())
    esUnitTypes = getCurEsUnitTypesList(false)

  local mask = 0
  foreach (esUnitType in esUnitTypes)
    mask = mask | (1 << esUnitType)

  return mask
}

return {
  getCurEsUnitTypesMask
  getCurEsUnitTypesList
}