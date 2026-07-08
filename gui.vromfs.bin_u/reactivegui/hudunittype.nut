from "%rGui/globals/ui_library.nut" import *

let hudState = require("%rGui/hudState.nut")

let airUnitTypes = ["aircraft", "helicopter", "humanDrone", "humanDroneHeli"]

return {
  isAir            = @() hudState.unitType.get() == "aircraft"
  isTank           = @() hudState.unitType.get() == "tank"
  isShip           = @() hudState.unitType.get() == "ship"
  isSubmarine      = @() hudState.unitType.get() == "shipEx"
  isHelicopter     = @() hudState.unitType.get() == "helicopter"
  isHuman          = @() hudState.unitType.get() == "human"
  


  isHumanAirDrone  = @() hudState.unitType.get() == "humanDrone"
  isHumanHeliDrone = @() hudState.unitType.get() == "humanDroneHeli"
  isAirUnitType    = @(unitType) airUnitTypes.contains(unitType)
}
