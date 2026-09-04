from "guiTacticalMap" import setForcedHudType, resetForcedHudType, setTacticalMapHudType

let { isInBattleState } = require("%scripts/clientState/clientStates.nut")

let tacticalMapHudTypeState = persist("tacticalMapHudTypeState", @() {})

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

return {
  getCachedMapHudType
  setCachedMapHudType
  applyMapHudType
}
