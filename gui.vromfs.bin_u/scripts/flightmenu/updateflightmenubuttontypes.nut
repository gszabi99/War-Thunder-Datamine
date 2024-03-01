from "%scripts/dagui_library.nut" import *

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
