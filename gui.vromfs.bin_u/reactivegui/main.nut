#default:no-func-decl-sugar
#default:no-class-decl-sugar

require("%rGui/globals/darg_library.nut")
require("%rGui/globals/ui_library.nut")
require("consoleCmd.nut")

let widgets = require("%rGui/widgets.nut")
let { inspectorRoot } = require("%darg/components/inspector.nut")

return {
  size = flex()
  children = [
    widgets
    inspectorRoot
  ]
}
