//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let flightMenuButtonTypes = require("%scripts/flightMenu/flightMenuButtonTypes.nut")

flightMenuButtonTypes.types = [
  flightMenuButtonTypes.RESUME
  flightMenuButtonTypes.OPTIONS
  flightMenuButtonTypes.CONTROLS
  flightMenuButtonTypes.CONTROLS_HELP
  flightMenuButtonTypes.RESTART
  flightMenuButtonTypes.BAILOUT
  flightMenuButtonTypes.QUIT_MISSION
]
.sort(@(a, b) a.idx <=> b.idx)
