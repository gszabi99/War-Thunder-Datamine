//checked for plus_string
from "%scripts/dagui_library.nut" import *

let function backToMainScene() {
  if (::is_in_flight())
    return { globalFunctionName = "gui_start_flight_menu" }
  return { globalFunctionName = "gui_start_mainmenu" }
}

return backToMainScene

