from "%scripts/dagui_library.nut" import *
let { isInFlight } = require("gameplayBinding")

function backToMainScene() {
  if (isInFlight())
    return { eventbusName = "gui_start_flight_menu" }
  return { eventbusName = "gui_start_mainmenu" }
}

return backToMainScene

