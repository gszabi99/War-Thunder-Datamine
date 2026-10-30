
#default:forbid-root-table
from "%rGui/components/modalWindowsMngr.nut" import modalWindowsComponent
from "%rGui/components/tooltip.nut" import tooltipComp
from "%darg/helpers/inspector.nut" import inspectorRoot
from "%rGui/globals/ui_library.nut" import *
from "ecs" import clear_vm_entity_systems, start_es_loading, end_es_loading
from "frp" import set_slow_subscriber_threshold_usec
from "%rGui/weapons/bulletsPenetrationGraphPanel.nut" import bulletsPenetrationGraphPanel
set_slow_subscriber_threshold_usec(1000000) 

clear_vm_entity_systems()
start_es_loading()


gui_scene.setConfigProps({ clickRumbleEnabled = false, gamepadCursorMovesMouse = true })

require("%rGui/hudChatCtrlsState.nut") 
require("%rGui/ctrlsState.nut")
require("%rGui/antiAirComplexMenu/antiAirComplexMenuState.nut")
require("%rGui/planeSettings.nut")

require("%rGui/consoleCmd.nut")
require("%sqstd/regScriptProfiler.nut")("darg", dlog) 

let widgets = require("%rGui/widgets.nut")
let testBackground = require("%rGui/debugTools/testBackground.nut")
let axisSetupWnd = require("%rGui/controls/axisSetupWnd.nut")
let assignShortcutWnd = require("%rGui/controls/assignShortcutWnd.nut")

end_es_loading()

return {
  size = FLEX
  children = [
    testBackground
    widgets
    axisSetupWnd
    assignShortcutWnd
    bulletsPenetrationGraphPanel
    modalWindowsComponent
    tooltipComp
    inspectorRoot
  ]
}
