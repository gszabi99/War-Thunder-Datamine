from "gameplayBinding" import isInFlight
from "%scripts/dagui_library.nut" import *

function backToMainScene() {
  if (isInFlight())
    return { eventbusName = "gui_start_flight_menu" }
  return { eventbusName = "gui_start_mainmenu" }
}

return backToMainScene
