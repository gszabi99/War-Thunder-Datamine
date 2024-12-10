from "%rGui/globals/ui_library.nut" import *

let { wwGetSpeedupFactor, wwGetOperationTimeMillisec } = require("worldwar")
let { resetTimeout } = require("dagor.workcycle")
let { getArtilleryParams } = require("%rGui/wwMap/wwConfigurableValues.nut")
let { armiesData } = require("%rGui/wwMap/wwArmyStates.nut")
let { artilleryReadyState } = require("%appGlobals/worldWar/wwArtilleryStatus.nut")

let hasArtilleryAbility = @(armyData) armyData?.specs.canArtilleryFire ?? false

function getCooldownAfterMoveMillisec(params) {
  return (params.cooldownAfterMoveSec * 1000 / wwGetSpeedupFactor()).tointeger()
}

function updateReadyStatus(armyData, value) {
  if (artilleryReadyState.get()?[armyData.name] == value)
    return
  artilleryReadyState.mutate(@(v) v[armyData.name] <- value)
}

function updateArtilleryReadyStatus(armyData) {
  let artillery = getArtilleryParams(armyData)
  if (artillery == null)
    return

  if (armyData.stoppedAtMillisec <= 0) {
    updateReadyStatus(armyData, false)
    return
  }

  let coolDownMillisec = getCooldownAfterMoveMillisec(artillery)
  let leftToFireEnableTime = max(armyData.stoppedAtMillisec + coolDownMillisec - wwGetOperationTimeMillisec(), 0)
  if (leftToFireEnableTime > 0) {
    updateReadyStatus(armyData, false)
    resetTimeout(leftToFireEnableTime / 1000, @() updateReadyStatus(armyData, true))
    return
  }
}

armiesData.subscribe(function(_p) {
  armiesData.get().each(function(army) {
  if (hasArtilleryAbility(army))
    updateArtilleryReadyStatus(army)
  })
})

return {
  artilleryReadyState
  getArtilleryParams
  isSAM = @(armyData) armyData?.iconOverride == "sam_site"
}