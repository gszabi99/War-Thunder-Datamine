from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { CrewTakeUnitProcess } = require("%scripts/crew/crewTakeUnitProcess.nut")

function guiStartSelectingCrew(config) {
  if (CrewTakeUnitProcess.safeInterrupt())
    handlersManager.destroyPrevHandlerAndLoadNew(gui_handlers.SelectCrew, config)
}

return guiStartSelectingCrew
