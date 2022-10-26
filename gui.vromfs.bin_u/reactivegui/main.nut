#default:no-func-decl-sugar
#default:no-class-decl-sugar
#default:no-root-fallback
#default:explicit-this
#default:forbid-root-table

from "%rGui/globals/ui_library.nut" import *

gui_scene.setConfigProps({clickRumbleEnabled = false})

require("%rGui/hudChatCtrlsState.nut") //need this for controls mask updated
require("%rGui/ctrlsState.nut")

require("consoleCmd.nut")

let widgets = require("%rGui/widgets.nut")
let { inspectorRoot } = require("%darg/helpers/inspector.nut")

return {
  size = flex()
  children = [
    widgets
    inspectorRoot
  ]
}
