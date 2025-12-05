let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlersManager, loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")

local last_called_gui_testflight = null

let set_last_called_gui_testflight = @(v) last_called_gui_testflight=v

function guiStartTestflight(params = {}) {
  loadHandler(gui_handlers.TestFlight, params)
  set_last_called_gui_testflight(handlersManager.getLastBaseHandlerStartParams())
}

let missionBuilderVehicleConfigForBlk = {}

return {
  guiStartTestflight
  set_last_called_gui_testflight
  get_last_called_gui_testflight = @() last_called_gui_testflight != null
    ? freeze(last_called_gui_testflight)
    : last_called_gui_testflight
  missionBuilderVehicleConfigForBlk
}
