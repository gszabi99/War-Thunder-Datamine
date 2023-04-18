//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { hudTankMovementStatesVisible } =  require("%scripts/hud/hudConfigByGame.nut")

hudTankMovementStatesVisible({
  gear = true
  rpm = true
  speed = true
  cruise_control = true
})
