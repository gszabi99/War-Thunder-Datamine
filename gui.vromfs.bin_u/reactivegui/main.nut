#default:forbid-root-table

from "%rGui/globals/ui_library.nut" import *

gui_scene.setConfigProps({ clickRumbleEnabled = false })

require("%rGui/hudChatCtrlsState.nut") //need this for controls mask updated
require("%rGui/ctrlsState.nut")

require("consoleCmd.nut")
require("%sqstd/regScriptProfiler.nut")("darg", dlog) // warning disable: -forbidden-function

let widgets = require("%rGui/widgets.nut")
let { inspectorRoot } = require("%darg/helpers/inspector.nut")

return {
  size = flex()
  children = [
    widgets
    inspectorRoot
  ]
}
