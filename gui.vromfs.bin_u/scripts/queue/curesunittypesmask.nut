from "%scripts/dagui_library.nut" import *

let { getCurrentGameModeId, getGameModeById, getUnitTypesByGameMode
} = require("%scripts/gameModes/gameModeManagerState.nut")

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

return {
  getCurEsUnitTypesMask
  getCurEsUnitTypesList
}