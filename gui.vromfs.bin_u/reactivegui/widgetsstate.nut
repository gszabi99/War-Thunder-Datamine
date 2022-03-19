local state = persist("widgetsState", @() {
  widgets = Watched([])
})


::interop.updateWidgets <- function (widget_list) {
  state.widgets.update(widget_list ? widget_list : [])
}


return state