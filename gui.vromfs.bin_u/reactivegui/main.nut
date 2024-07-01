#default:forbid-root-table

from "%rGui/globals/ui_library.nut" import *
from "ecs" import clear_vm_entity_systems, start_es_loading, end_es_loading

clear_vm_entity_systems()
start_es_loading()

gui_scene.setConfigProps({ clickRumbleEnabled = false })

require("%rGui/hudChatCtrlsState.nut") //need this for controls mask updated
require("%rGui/ctrlsState.nut")

require("consoleCmd.nut")
require("%sqstd/regScriptProfiler.nut")("darg", dlog) // warning disable: -forbidden-function

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
