from "%scripts/clientState/clientStates.nut" import isInBattleState
from "guiTacticalMap" import setForcedHudType, resetForcedHudType, setTacticalMapHudType
from "%scripts/dagui_library.nut" import mkHardPersist

let tacticalMapHudTypeState = mkHardPersist("respawn.tacticalMapHudTypeState")("tacticalMapHudTypeState", {})

function getCachedMapHudType(unitName) {
  return tacticalMapHudTypeState?[unitName]
}

function setCachedMapHudType(unitName, hudType) {
  tacticalMapHudTypeState[unitName] <- hudType
}

function applyMapHudType(hudType, isMapForced) {
  if (isMapForced)
    setForcedHudType(hudType)
  else {
    resetForcedHudType()
    setTacticalMapHudType(hudType)
  }
}

isInBattleState.subscribe(function(isInBattle) {
  if (isInBattle) {
    tacticalMapHudTypeState.clear()
    resetForcedHudType()
  }
})

return freeze({
  getCachedMapHudType
  setCachedMapHudType
  applyMapHudType
})
