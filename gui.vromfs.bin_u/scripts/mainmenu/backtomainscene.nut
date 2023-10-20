//checked for plus_string
from "%scripts/dagui_library.nut" import *
let { isInFlight } = require("gameplayBinding")

let function backToMainScene() {
  if (isInFlight())
    return { globalFunctionName = "gui_start_flight_menu" }
  return { globalFunctionName = "gui_start_mainmenu" }
}

return backToMainScene

