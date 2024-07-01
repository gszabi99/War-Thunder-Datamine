from "%scripts/dagui_library.nut" import *

let { hudTankMovementStatesVisible } =  require("%scripts/hud/hudConfigByGame.nut")

hudTankMovementStatesVisible({
  gear = true
  rpm = true
  speed = true
  cruise_control = true
})
