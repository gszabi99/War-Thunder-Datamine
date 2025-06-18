#default:forbid-root-table

from "%rGui/globals/ui_library.nut" import *
from "ecs" import clear_vm_entity_systems, start_es_loading, end_es_loading

clear_vm_entity_systems()
start_es_loading()

gui_scene.setConfigProps({ clickRumbleEnabled = false })

require("%rGui/hudChatCtrlsState.nut") 
require("%rGui/ctrlsState.nut")
require("%rGui/antiAirComplexMenu/antiAirComplexMenuState.nut")
require("%rGui/planeSettings.nut")

require("consoleCmd.nut")
require("%sqstd/regScriptProfiler.nut")("darg", dlog) 

let widgets = require("%rGui/widgets.nut")
let { inspectorRoot } = require("%darg/helpers/inspector.nut")

end_es_loading()

return {
  size = flex()
  children = [
    widgets
    inspectorRoot
  ]
}
