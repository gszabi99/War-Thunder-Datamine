
#default:forbid-root-table
from "%rGui/components/modalWindowsMngr.nut" import modalWindowsComponent
from "%rGui/components/tooltip.nut" import tooltipComp
from "%darg/helpers/inspector.nut" import inspectorRoot
from "%rGui/globals/ui_library.nut" import *
from "ecs" import clear_vm_entity_systems, start_es_loading, end_es_loading
from "frp" import warn_on_deprecated_methods, set_slow_subscriber_threshold_usec
from "dagor.system" import DBGLEVEL
warn_on_deprecated_methods(DBGLEVEL > 0)
set_slow_subscriber_threshold_usec(1000000) 

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

end_es_loading()

return {
  size = FLEX
  children = [
    widgets
    modalWindowsComponent
    tooltipComp
    inspectorRoot
  ]
}
