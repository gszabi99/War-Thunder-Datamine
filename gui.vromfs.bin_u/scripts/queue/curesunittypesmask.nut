from "%scripts/gameModes/gameModeManagerState.nut" import getCurrentGameModeId, getGameModeById, getUnitTypesByGameMode
from "%scripts/dagui_library.nut" import *

function getCurEsUnitTypesList(needRequiredOnly = false) {
  let gameModeId = getCurrentGameModeId()
  let gameMode = getGameModeById(gameModeId)
  return getUnitTypesByGameMode(gameMode, true, needRequiredOnly)
}

function getCurEsUnitTypesMask() {
  local esUnitTypes = getCurEsUnitTypesList(true)
  if (!esUnitTypes.len())
    esUnitTypes = getCurEsUnitTypesList(false)

  local mask = 0
  foreach (esUnitType in esUnitTypes)
    mask = mask | (1 << esUnitType)

  return mask
}

return freeze({
  getCurEsUnitTypesMask
  getCurEsUnitTypesList
})