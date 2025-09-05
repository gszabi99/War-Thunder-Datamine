#default:forbid-root-table

from "%rGui/globals/ui_library.nut" import *
from "ecs" import clear_vm_entity_systems, start_es_loading, end_es_loading
from "frp" import set_nested_observable_debug, set_subscriber_validation, warn_on_deprecated_methods
from "dagor.system" import DBGLEVEL

warn_on_deprecated_methods( false )

clear_vm_entity_systems()
start_es_loading()

gui_scene.setConfigProps({ clickRumbleEnabled = false })

require("%rGui/hudChatCtrlsState.nut") 
require("%rGui/ctrlsState.nut")
require("%rGui/antiAirComplexMenu/antiAirComplexMenuState.nut")
require("%rGui/planeSettings.nut")

require("%rGui/consoleCmd.nut")
require("%sqstd/regScriptProfiler.nut")("darg", dlog) 

let widgets = require("%rGui/widgets.nut")
let { inspectorRoot } = require("%darg/helpers/inspector.nut")
let { modalWindowsComponent } = require("%rGui/components/modalWindowsMngr.nut")

end_es_loading()

return {
  size = flex()
  children = [
    widgets
    modalWindowsComponent
    inspectorRoot
  ]
}
