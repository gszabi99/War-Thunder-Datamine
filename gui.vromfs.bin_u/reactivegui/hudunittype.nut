local hudState = require("hudState.nut")

return {
  isAir        = @() hudState.unitType.value == "aircraft"
  isTank       = @() hudState.unitType.value == "tank"
  isShip       = @() hudState.unitType.value == "ship"
  isSubmarine  = @() hudState.unitType.value == "shipEx"
  isHelicopter = @() hudState.unitType.value == "helicopter"
  //


}
