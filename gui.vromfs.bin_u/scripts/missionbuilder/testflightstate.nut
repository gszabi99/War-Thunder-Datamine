from "%scripts/sqDagui/framework/gui_handlers.nut" import get_gui_handler
from "%scripts/baseGuiHandlerManagerWT.nut" import loadHandler

let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")

let lastCalledGuiTestflight = persist("lastCalledGuiTestflight", @() { value = null })

let setLastCalledGuiTestflight = @(v) lastCalledGuiTestflight.value = v

function guiStartTestflight(params = {}) {
  loadHandler(get_gui_handler("TestFlight"), params)
  setLastCalledGuiTestflight(handlersManager.getLastBaseHandlerStartParams())
}

let missionBuilderVehicleConfigForBlk = {}

return {
  guiStartTestflight
  set_last_called_gui_testflight = setLastCalledGuiTestflight
  get_last_called_gui_testflight = @() lastCalledGuiTestflight.value != null
    ? freeze(lastCalledGuiTestflight.value)
    : null
  missionBuilderVehicleConfigForBlk
}
