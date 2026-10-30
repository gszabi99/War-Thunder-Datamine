from "%scripts/sqDagui/framework/gui_handlers.nut" import get_gui_handler
from "%scripts/modalInfo/modalInfo.nut" import destroyModalInfo
from "%scripts/dagui_library.nut" import *

let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { CrewTakeUnitProcess } = require("%scripts/crew/crewTakeUnitProcess.nut")

function guiStartSelectingCrew(config) {
  if (CrewTakeUnitProcess.safeInterrupt()) {
    destroyModalInfo()
    handlersManager.destroyPrevHandlerAndLoadNew(get_gui_handler("SelectCrew"), config)
  }
}

return guiStartSelectingCrew
