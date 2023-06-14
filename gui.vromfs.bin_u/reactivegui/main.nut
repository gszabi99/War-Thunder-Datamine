#default:forbid-root-table

from "%rGui/globals/ui_library.nut" import *

gui_scene.setConfigProps({ clickRumbleEnabled = false })

require("%rGui/hudChatCtrlsState.nut") //need this for controls mask updated
require("%rGui/ctrlsState.nut")
require("%globalScripts/debugTools/dbgTimer.nut").registerConsoleCommand("darg")

require("consoleCmd.nut")

let registerScriptProfiler = require("%sqstd/regScriptProfiler.nut")
registerScriptProfiler("hud")

let widgets = require("%rGui/widgets.nut")
let { inspectorRoot } = require("%darg/helpers/inspector.nut")

return {
  size = flex()
  children = [
    widgets
    inspectorRoot
  ]
}
