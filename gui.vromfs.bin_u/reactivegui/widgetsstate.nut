from "%rGui/globals/ui_library.nut" import *

let {interop} = require("%rGui/globals/interop.nut")
let state = persist("widgetsState", @() {
  widgets = Watched([])
})


interop.updateWidgets <- function (widget_list) {
  state.widgets.update(widget_list ? widget_list : [])
}


return state