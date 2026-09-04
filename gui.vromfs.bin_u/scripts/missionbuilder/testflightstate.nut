let { get_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")
let { handlersManager, loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")

local last_called_gui_testflight = null

let set_last_called_gui_testflight = @(v) last_called_gui_testflight=v

function guiStartTestflight(params = {}) {
  loadHandler(get_gui_handler("TestFlight"), params)
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
