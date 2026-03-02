from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { CrewTakeUnitProcess } = require("%scripts/crew/crewTakeUnitProcess.nut")
let { destroyModalInfo } = require("%scripts/modalInfo/modalInfo.nut")

function guiStartSelectingCrew(config) {
  if (CrewTakeUnitProcess.safeInterrupt()) {
    destroyModalInfo()
    handlersManager.destroyPrevHandlerAndLoadNew(gui_handlers.SelectCrew, config)
  }
}

return guiStartSelectingCrew
